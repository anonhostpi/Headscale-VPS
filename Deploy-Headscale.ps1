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
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]*$')]
    [string]$Name,

    [ValidatePattern('^\d+[MG]$')]
    [string]$Memory,

    [ValidatePattern('^\d+G$')]
    [string]$Disk,

    [ValidateRange(1, 32)]
    [int]$CPUs,

    [string]$Network,

    [ValidatePattern('^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$')]
    [string]$Domain,

    [ValidatePattern('^[a-zA-Z0-9_-]+$')]
    [string]$NgrokToken,

    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AzureTenantID,

    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AzureClientID,

    [string]$AzureClientSecret,

    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$AzureAllowedEmail,

    [ValidateScript({
        if ($_ -and -not (Test-Path $_)) {
            throw "Config file not found: $_"
        }
        $true
    })]
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

        DefaultValue = "$PSScriptRoot\config.json"
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
            throw "Configuration cancelled by user"
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
        throw "Multipass is not installed"
    }

    # Note: ngrok will be installed inside the VM, not required on host
    Write-Host "ℹ ngrok will be installed inside the VM after deployment" -ForegroundColor Cyan

    # Check if cloud-init.yml exists
    if (-not (Test-Path ".\cloud-init.yml")) {
        Write-Host "✗ cloud-init.yml not found in current directory" -ForegroundColor Red
        throw "cloud-init.yml not found"
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
                throw "Deployment cancelled by user"
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
        throw "Failed to launch VM"
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

function Configure-Ngrok {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Authenticating Ngrok" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Applying configuration to VM..." -ForegroundColor Yellow

    # Call the existing headscale-config script with environment variables
    try {
        multipass exec $script:Options.Name -- ngrok config add-authtoken $script:Options.NgrokToken
        Write-Host "✓ Authenticated successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to apply configuration: $_" -ForegroundColor Red
        throw
    }
}

function Start-Ngrok {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Starting Ngrok Tunnel" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Starting ngrok tunnel inside VM..." -ForegroundColor Yellow

    try {
        multipass exec $script:Options.Name -- ngrok http --domain=$script:Options.Domain https://localhost:443
        Write-Host "✓ ngrok tunnel started!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to start ngrok tunnel: $_" -ForegroundColor Red
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
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list \
  && sudo apt update \
  && sudo apt install ngrok
echo '✓ ngrok installed: '`$(ngrok version)
"@

    try {
        # Install ngrok binary
        $installScript | multipass exec $($script:Options.Name) -- sudo bash

        Write-Host "✓ ngrok installed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to install ngrok: $_" -ForegroundColor Red
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

function Show-HeadplaneStatus {
    Write-Host "Headplane Status:" -ForegroundColor Cyan
    multipass exec $script:Options.Name -- systemctl status headplane
    Write-Host ""
}

function Show-HeadscaleHealth {
    Write-Host "Headscale Health Check:" -ForegroundColor Cyan
    multipass exec $script:Options.Name -- sudo headscale-healthcheck
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
    Show-HeadplaneStatus
    Show-HeadscaleHealth

    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Connect a Tailscale client:" -ForegroundColor Yellow
    Write-Host "   tailscale up --login-server https://$($script:Options.Domain)" -ForegroundColor White
    Write-Host ""
    Write-Host "2. SSH into VM for direct access:" -ForegroundColor Yellow
    Write-Host "   multipass shell '$($script:Options.Name)'" -ForegroundColor White
    Write-Host ""

    Show-TroubleshootingInfo
}

#endregion

#region Main

function Main {
    $vmCreated = $false

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
            $vmCreated = $true

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

            # Authenticate ngrok
            Configure-Ngrok

            # Start ngrok tunnel
            Start-Ngrok
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
        Write-Host ""

        # Offer cleanup if VM was created
        if ($vmCreated) {
            Write-Host "Cleanup Options:" -ForegroundColor Yellow
            $cleanup = Read-Host "Delete failed VM '$($script:Options.Name)'? [y/N]"
            if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
                Write-Host "Cleaning up..." -ForegroundColor Yellow
                try {
                    multipass delete $script:Options.Name
                    multipass purge
                    Write-Host "✓ Cleanup complete" -ForegroundColor Green
                } catch {
                    Write-Host "✗ Cleanup failed: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "VM '$($script:Options.Name)' left intact for troubleshooting" -ForegroundColor Cyan
            }
            Write-Host ""
        }

        Show-TroubleshootingInfo
        exit 1
    }
}

# Run main function
Main

#endregion
