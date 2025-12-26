#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy and test Headscale VPS using Multipass

.DESCRIPTION
    Automates Headscale + Headplane deployment to Multipass VM with complete
    configuration coverage and ngrok integration for OAuth testing.
    Full documentation: https://github.com/anonhostpi/Headscale-VPS/blob/main/TESTING.md

.EXAMPLE
    .\Deploy-Headscale.ps1
    .\Deploy-Headscale.ps1 -Name "test" -Memory "4G" -CPUs 4
    .\Deploy-Headscale.ps1 -ConfigFile ".\my-config.json"
#>

[CmdletBinding()]
param(
    [string]$Name,
    [string]$Memory,
    [string]$Disk,
    [int]$CPUs,
    [string]$Network,

    [string]$Domain,

    [string]$NgrokToken,
    [string]$AzureTenantID,
    [string]$AzureClientID,
    [string]$AzureClientSecret,
    [string]$AzureAllowedEmail,

    [string]$ConfigFile
)

$ErrorActionPreference = "Stop"

#region Configuration

# Define infrastructure required arguments with validation metadata
$script:Required = [ordered]@{
    ConfigFile = @{
        Prompt = "Path to configuration file (leave blank to use defaults)"
        ValidationType = "None"
        IsSecret = $false

        DefaultValue = ".\config.json"
        SummaryLabel = "Config File"
    }

    # General infrastructure options
    Domain = @{
        Prompt = "Ngrok domain (e.g., your-domain.ngrok-free.dev)"
        ValidationType = "Domain"
        IsSecret = $false

        # DefaultValue = ""
        SummaryLabel = "Ngrok Domain"
    }

    # VM configuration options
    Name = @{
        Prompt = "Multipass VM name"
        ValidationType = "None"
        IsSecret = $false

        DefaultValue = "headscale-test"
        SummaryLabel = "VM Name"
    }
    Memory = @{
        Prompt = "VM Memory (e.g., '2G', '2048M')"
        ValidationType = "None"
        IsSecret = $false

        DefaultValue = "2G"
        SummaryLabel = "Memory"
    }
    Disk = @{
        Prompt = "VM Disk size (e.g., '20G', '20480M')"
        ValidationType = "None"
        IsSecret = $false

        DefaultValue = "20G"
        SummaryLabel = "Disk"
    }
    CPUs = @{
        Prompt = "Number of CPU cores"
        ValidationType = "None"
        IsSecret = $false

        DefaultValue = 2
        SummaryLabel = "CPUs"
    }
    Network = @{
        Prompt = "Network adapter name (e.g., 'Ethernet 3', 'Wi-Fi')"
        ValidationType = "None"
        IsSecret = $false

        # DefaultValue = "Wi-Fi"
        SummaryLabel = "Network"
    }

    # Authentication options
    NgrokToken = @{
        Prompt = "Ngrok auth token"
        ValidationType = "None"
        IsSecret = $true

        # DefaultValue = ""
        SummaryLabel = "Ngrok Auth Token"
    }
    AzureTenantID = @{
        Prompt = "Azure Tenant ID (as in the GUID)"
        ValidationType = "UUID"
        IsSecret = $false

        # DefaultValue = ""
        SummaryLabel = "Tenant ID"
    }
    AzureClientID = @{
        Prompt = "Azure Application (Client) ID"
        ValidationType = "UUID"
        IsSecret = $false

        # DefaultValue = ""
        SummaryLabel = "Client ID"
    }
    AzureClientSecret = @{
        Prompt = "Azure Client Secret Value"
        ValidationType = "None"
        IsSecret = $true

        # DefaultValue = ""
        SummaryLabel = "Client Secret"
    }
    AzureAllowedEmail = @{
        Prompt = "Allowed Email Address for Azure AD login"
        ValidationType = "Email"
        IsSecret = $false

        # DefaultValue = ""
        SummaryLabel = "Allowed Email"
    }
}

$script:Defaults = [ordered]@{}

foreach ($key in $script:Required.Keys) {
    $script:Defaults[$key] = $script:Required[$key].DefaultValue
}

function Get-ConfigValue {
    param(
        [string]$PromptText,
        [string]$DefaultValue = "",
        [switch]$IsSecret,
        [ValidateSet("Domain", "Email", "UUID", "None")]$ValidationType = "None"
    )

    do {
        if ($DefaultValue) {
            if ($IsSecret -and $DefaultValue) {
                $prompt = "$PromptText [****hidden****]: "
            } else {
                $prompt = "$PromptText [$DefaultValue]: "
            }
        } else {
            $prompt = "$PromptText`: "
        }

        if ($IsSecret) {
            $secureValue = Read-Host -Prompt $prompt -AsSecureString
            $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
            )
        } else {
            $value = Read-Host -Prompt $prompt
        }

        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $DefaultValue
        }

        # Validate
        $valid = $true
        switch ($ValidationType) {
            "Domain" {
                if ($value -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$') {
                    Write-Host "  Invalid domain format. Please try again." -ForegroundColor Red
                    $valid = $false
                }
            }
            "Email" {
                # RFC 5322 compliant (simplified) - must match Bash validation
                if ($value -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                    Write-Host "  Invalid email format. Please try again." -ForegroundColor Red
                    $valid = $false
                }
            }
            "UUID" {
                if ($value -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -and
                    $value -notmatch '^[a-zA-Z0-9-]+\.onmicrosoft\.com$') {
                    Write-Host "  Invalid UUID or tenant format. Please try again." -ForegroundColor Red
                    $valid = $false
                }
            }
        }

    } while (-not $valid)

    return $value
}

# Get merged configuration with proper priority:
# CLI Options (highest) → JSON config (primary fallback) → Hardcoded defaults (secondary fallback)
function Get-Config {
    param(
        [hashtable]$CliOptions,
        [string]$ConfigFilePath,
        [string]$BannerTitle = "",
        [scriptblock]$PrePromptMessage = $null,
        [bool]$ShowSummary = $false,
        [bool]$RequireConfirmation = $false
    )

    $ConfigFilePath = if ([string]::IsNullOrWhiteSpace($ConfigFilePath)) {
        $script:Defaults.ConfigFile
    } else {
        $ConfigFilePath
    }

    # Show banner if title provided
    if ($BannerTitle) {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  $BannerTitle" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
    }

    # Show pre-prompt message if provided
    if ($PrePromptMessage) {
        & $PrePromptMessage
    }

    # Start with hardcoded defaults
    $config = $script:Defaults.Clone()

    # Try to load JSON config (primary fallback)
    if (Test-Path $ConfigFilePath) {
        if (-not $BannerTitle) {
            Write-Host "Loading config from: $ConfigFilePath" -ForegroundColor Cyan
        }
        try {
            $jsonConfig = Get-Content $ConfigFilePath | ConvertFrom-Json

            # Merge JSON config over hardcoded defaults
            foreach ($property in $jsonConfig.PSObject.Properties) {
                $config[$property.Name] = $property.Value
            }
        } catch {
            Write-Host "⚠ Failed to parse config file, using hardcoded defaults" -ForegroundColor Yellow
        }
    }

    # Apply CLI Options (highest priority - overrides everything)
    foreach ($key in $CliOptions.Keys) {
        if ($null -ne $CliOptions[$key] -and $CliOptions[$key] -ne "" -and $CliOptions[$key] -ne 0) {
            $config[$key] = $CliOptions[$key]
        }
    }

    # Prompt for missing required arguments
    foreach ($argName in $script:Required.Keys) {
        # Check if argument is missing or empty
        if (-not $config.ContainsKey($argName) -or [string]::IsNullOrWhiteSpace($config[$argName])) {
            # Get metadata for this argument from required args
            $metadata = $script:Required[$argName]

            # Use metadata to configure prompt with defaults from config
            $defaultValue = if ($metadata.DefaultValue) {
                # Allow dynamic default via scriptblock
                if ($metadata.DefaultValue -is [scriptblock]) {
                    & $metadata.DefaultValue
                } else {
                    $metadata.DefaultValue
                }
            } else {
                ""
            }

            $value = Get-ConfigValue `
                -PromptText $metadata.Prompt `
                -DefaultValue $defaultValue `
                -IsSecret:($metadata.IsSecret) `
                -ValidationType $metadata.ValidationType

            $config[$argName] = $value
        }
    }

    # Show summary if requested
    if ($ShowSummary) {
        Write-Host ""
        Write-Host "Configuration Summary:" -ForegroundColor Cyan
        foreach ($argName in $script:Required.Keys) {
            $metadata = $script:Required[$argName]
            $displayValue = if ($metadata.IsSecret) { "****" } else { $config[$argName] }
            $label = if ($metadata.SummaryLabel) { $metadata.SummaryLabel } else { $argName }
            Write-Host "  ${label}: $displayValue" -ForegroundColor White
        }
        Write-Host ""
    }

    # Require confirmation if requested
    if ($RequireConfirmation) {
        $confirm = Read-Host "Is this configuration correct? [Y/n]"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            Write-Host "Configuration cancelled. Please run the script again." -ForegroundColor Yellow
            exit 0
        }
    }

    return $config
}

# Capture CLI-provided Options from parameters
# Get infrastructure configuration (script-scoped for use in functions)
$script:Options = Get-Config -CliOptions (@{
    Name = $Name
    Memory = $Memory
    Disk = $Disk
    CPUs = $CPUs
    Network = $Network

    Domain = $Domain
    
    NgrokToken = $NgrokToken
    AzureTenantID = $AzureTenantID
    AzureClientID = $AzureClientID
    AzureClientSecret = $AzureClientSecret
    AzureAllowedEmail = $AzureAllowedEmail
}) -ConfigFilePath $ConfigFile -ShowSummary $true -RequireConfirmation $true

function Save-Config {
    param(
        [string] $ConfigFilePath
    )

    $ConfigFilePath = if ([string]::IsNullOrWhiteSpace($ConfigFilePath)) {
        If([string]::IsNullOrWhiteSpace($script:Options.ConfigFile) -or $script:Options.ConfigFile -eq $script:Defaults.ConfigFile) {
            ".\config-$($script:Options.Name).json"
        } else {
            $script:Options.ConfigFile
        }
    } else {
        $ConfigFilePath
    }

    $script:Options | ConvertTo-Json | Out-File $ConfigFilePath

    Write-Host "Configuration saved to: $ConfigFilePath" -ForegroundColor Green
    Write-Host "  Use -ConfigFile ""$ConfigFilePath"" to reuse these settings" -ForegroundColor Cyan
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow

    # Check if multipass is installed
    try {
        $multipassVersion = multipass version
        Write-Host "✓ Multipass installed: '$($multipassVersion[0])'" -ForegroundColor Green
    } catch {
        Write-Host "✗ Multipass is not installed" -ForegroundColor Red
        Write-Host "  Install from: https://multipass.run/install" -ForegroundColor Yellow
        exit 1
    }

    # Note: ngrok will be installed inside the VM, not required on host
    Write-Host "ℹ ngrok will be installed inside the VM after deployment" -ForegroundColor Cyan

    # Check if cloud-init.yml exists
    if (-not (Test-Path ".\cloud-init.yml")) {
        Write-Host "✗ cloud-init.yml not found in current directory" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ cloud-init.yml found" -ForegroundColor Green

    Write-Host ""
}

#endregion

#region VM Deployment

function Start-MultipassVM {

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Launching Multipass VM" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "VM Configuration:" -ForegroundColor Yellow
    Write-Host "  Name:    '$($script:Options.Name)'" -ForegroundColor White
    Write-Host "  Memory:  '$($script:Options.Memory)'" -ForegroundColor White
    Write-Host "  Disk:    '$($script:Options.Disk)'" -ForegroundColor White
    Write-Host "  CPUs:    '$($script:Options.CPUs)'" -ForegroundColor White
    Write-Host "  Network: '$($script:Options.Network)'" -ForegroundColor White
    Write-Host ""

    # Check if VM already exists
    try {
        $existingVM = multipass list | Select-String $script:Options.Name
        if ($existingVM) {
            Write-Host "VM '$($script:Options.Name)' already exists!" -ForegroundColor Yellow
            $overwrite = Read-Host "Delete and recreate? [y/N]"
            if ($overwrite -eq 'y' -or $overwrite -eq 'Y') {
                Write-Host "Deleting existing VM..." -ForegroundColor Yellow
                multipass delete $script:Options.Name
                multipass purge
            } else {
                Write-Host "Deployment cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    } catch {
        # VM doesn't exist, continue
    }

    Write-Host "Launching VM (this may take several minutes)..." -ForegroundColor Yellow

    try {
        multipass launch --name $script:Options.Name `
            --cloud-init .\cloud-init.yml `
            --memory $script:Options.Memory `
            --disk $script:Options.Disk `
            --cpus $script:Options.CPUs `
            --network $script:Options.Network `
            22.04

        Write-Host "✓ VM launched successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to launch VM: $_" -ForegroundColor Red
        exit 1
    }

    # Get VM IP
    Start-Sleep -Seconds 5
    $vmInfo = multipass info $script:Options.Name
    $ipMatch = $vmInfo | Select-String "IPv4:\s+(\d+\.\d+\.\d+\.\d+)"
    if ($ipMatch) {
        $vmIP = $ipMatch.Matches.Groups[1].Value
        Write-Host "✓ VM IP: $vmIP" -ForegroundColor Green
        return $vmIP
    } else {
        Write-Host "⚠ Could not determine VM IP" -ForegroundColor Yellow
        return $null
    }
}

function Watch-Deployment {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Monitoring Deployment" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cloud-init is now running setup. This will take 5-10 minutes." -ForegroundColor Yellow
    Write-Host "You can monitor progress with:" -ForegroundColor Yellow
    Write-Host "  multipass exec '$($script:Options.Name)' -- cloud-init status --wait" -ForegroundColor Cyan
    Write-Host "  multipass exec '$($script:Options.Name)' -- journalctl -u cloud-final -f" -ForegroundColor Cyan
    Write-Host ""

    $monitor = Read-Host "Monitor deployment progress? [Y/n]"
    if ($monitor -ne 'n' -and $monitor -ne 'N') {
        Write-Host "Waiting for cloud-init to complete..." -ForegroundColor Yellow
        multipass exec $script:Options.Name -- cloud-init status --wait
        Write-Host "✓ Cloud-init completed!" -ForegroundColor Green
    }
}

#endregion

#region Deployment Setup

function Configure-Headscale {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Configuring Headscale" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Applying configuration to VM..." -ForegroundColor Yellow

    # Call the existing headscale-config script with environment variables
    try {
        multipass exec $script:Options.Name -- sudo bash -c @"
export HEADSCALE_DOMAIN='$($script:Options.Domain)'
export AZURE_TENANT_ID='$($script:Options.AzureTenantID)'
export AZURE_CLIENT_ID='$($script:Options.AzureClientID)'
export AZURE_CLIENT_SECRET='$($script:Options.AzureClientSecret)'
export ALLOWED_EMAIL='$($script:Options.AzureAllowedEmail)'
/usr/local/bin/headscale-config
"@
        Write-Host "✓ Configuration applied successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to apply configuration: $_" -ForegroundColor Red
        throw
    }
}

function Install-Ngrok {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Installing ngrok (Testing Only)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Installing ngrok inside VM..." -ForegroundColor Yellow

    # Download and install ngrok
    $installScript = @"
#!/bin/bash
set -e
echo 'Downloading ngrok...'
NGROK_VERSION='v3-stable'
curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-\`${NGROK_VERSION}-linux-amd64.tgz -o /tmp/ngrok.tgz
tar -xzf /tmp/ngrok.tgz -C /usr/local/bin
chmod +x /usr/local/bin/ngrok
rm /tmp/ngrok.tgz
echo '✓ ngrok installed: '`$(ngrok version)
"@

    try {
        # Install ngrok binary
        $installScript | multipass exec $($script:Options.Name) -- sudo bash

        # Create start-ngrok-tunnel helper script
        $tunnelScript = @"
#!/bin/bash
# Start ngrok tunnel for Headscale testing
AUTHTOKEN='$($script:Options.NgrokToken)'
DOMAIN='$($script:Options.Domain)'

echo '=========================================='
echo '  Starting ngrok tunnel'
echo '=========================================='
echo ''

# Configure authtoken if not already done
if [ ! -f ~/.ngrok2/ngrok.yml ]; then
  echo 'Configuring ngrok authtoken...'
  ngrok config add-authtoken '`$AUTHTOKEN'
fi

echo 'Tunnel configuration:'
echo '  Domain: https://'`$DOMAIN
echo '  Target: https://localhost:443'
echo ''
echo 'Starting tunnel... (Press Ctrl+C to stop)'
echo ''

# Start tunnel with static domain
ngrok http --domain='`$DOMAIN' https://localhost:443
"@

        $tunnelScript | multipass exec $script:Options.Name -- sudo bash -c "cat > /usr/local/bin/start-ngrok-tunnel && chmod +x /usr/local/bin/start-ngrok-tunnel"

        Write-Host "✓ ngrok installed successfully!" -ForegroundColor Green
        Write-Host "✓ start-ngrok-tunnel helper created" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to install ngrok: $_" -ForegroundColor Red
        Write-Host "  You can install it manually with the commands above" -ForegroundColor Yellow
    }
}

#endregion

#region Post-Deployment

function Show-VMInfo {
    param(
        [string]$VMIP
    )

    Write-Host "VM Information:" -ForegroundColor Cyan
    Write-Host "  Name: '$($script:Options.Name)'" -ForegroundColor White
    Write-Host "  IP:   $VMIP" -ForegroundColor White
    Write-Host ""
}

function Show-URLs {
    Write-Host "Access URLs:" -ForegroundColor Cyan
    Write-Host "  Headplane UI:  https://$($script:Options.Domain)/admin" -ForegroundColor White
    Write-Host "  Headscale API: https://$($script:Options.Domain)/api" -ForegroundColor White
    Write-Host ""
}

function Show-TroubleshootingInfo {
    Write-Host "Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  View logs:    multipass exec '$($script:Options.Name)' -- journalctl -u headscale -f" -ForegroundColor White
    Write-Host "  View setup:   multipass exec '$($script:Options.Name)' -- cat /var/log/cloud-init-output.log" -ForegroundColor White
    Write-Host "  Stop VM:      multipass stop '$($script:Options.Name)'" -ForegroundColor White
    Write-Host "  Delete VM:    multipass delete '$($script:Options.Name)' && multipass purge" -ForegroundColor White
    Write-Host ""
}

function Show-DeploymentSummary {
    param(
        [string]$VMIP
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Show-VMInfo -VMIP $VMIP
    Show-URLs

    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Start ngrok tunnel (in a separate terminal):" -ForegroundColor Yellow
    Write-Host "   multipass exec '$($script:Options.Name)' -- start-ngrok-tunnel" -ForegroundColor White
    Write-Host "   This creates the tunnel: https://$($script:Options.Domain) -> VM:443" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Verify Headplane is running:" -ForegroundColor Yellow
    Write-Host "   multipass exec '$($script:Options.Name)' -- systemctl status headplane" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Connect a Tailscale client:" -ForegroundColor Yellow
    Write-Host "   tailscale up --login-server https://$($script:Options.Domain)" -ForegroundColor White
    Write-Host ""
    Write-Host "4. SSH into VM for direct access:" -ForegroundColor Yellow
    Write-Host "   multipass shell '$($script:Options.Name)'" -ForegroundColor White
    Write-Host ""
    Write-Host "5. View health status:" -ForegroundColor Yellow
    Write-Host "   multipass exec '$($script:Options.Name)' -- sudo headscale-healthcheck" -ForegroundColor White
    Write-Host ""

    Show-TroubleshootingInfo
}

#endregion

#region Main

function Main {
    try {
        # Show banner
        Write-Host @"

========================================
  Headscale VPS Deployment (Testing)
========================================

See TESTING.md for full documentation.

"@ -ForegroundColor Cyan
        # Prerequisites
        Test-Prerequisites

        # Spin up VM and get IP
        $ip = & {
            # Launch VM with base cloud-init
            $ip = Start-MultipassVM

            # Monitor deployment (waits for cloud-init)
            Watch-Deployment

            return $ip
        }

        # Deployment setup
        & {
            # Configure Headscale after cloud-init completes
            Configure-Headscale

            # Install ngrok after configuration
            Install-Ngrok
        }

        # Post-Deployment
        & {
            # Show summary
            Show-DeploymentSummary -VMIP $ip

            # Save config for future reuse
            Save-Config
        }
    } catch {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  Deployment Failed" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Yellow

        Show-TroubleshootingInfo
        exit 1
    }
}

# Run main function
Main

#endregion
