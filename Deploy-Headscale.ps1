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
    .\Deploy-Headscale.ps1 -VMName "test" -Memory "4G" -CPUs 4
    .\Deploy-Headscale.ps1 -ConfigFile ".\my-config.json"
#>

[CmdletBinding()]
param(
    [string]$VMName,
    [string]$Memory,
    [string]$Disk,
    [int]$CPUs,
    [string]$ConfigFile = "",
    [string]$Network,
    [string]$NgrokAuthToken,
    [string]$NgrokDomain
)

$ErrorActionPreference = "Stop"

# Default configuration file
$DefaultConfigFile = ".\headscale-config-default.json"

# Get merged configuration with proper priority:
# CLI options (highest) → JSON config (primary fallback) → Hardcoded defaults (secondary fallback)
function Get-Config {
    param(
        [hashtable]$CliOptions,
        [string]$ConfigFilePath
    )

    # Hardcoded defaults (secondary fallback)
    $hardcodedDefaults = @{
        VMName = "headscale-test"
        Memory = "2G"
        Disk = "20G"
        CPUs = 2
        Network = "Ethernet 3"
        NgrokAuthToken = "[REDACTED-NGROK-TOKEN]"
        NgrokDomain = "[REDACTED-NGROK-DOMAIN]"
    }

    # Start with hardcoded defaults
    $config = $hardcodedDefaults.Clone()

    # Try to load JSON config (primary fallback)
    if (Test-Path $ConfigFilePath) {
        Write-Host "Loading config from: $ConfigFilePath" -ForegroundColor Cyan
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

    # Apply CLI options (highest priority - overrides everything)
    foreach ($key in $CliOptions.Keys) {
        if ($null -ne $CliOptions[$key] -and $CliOptions[$key] -ne "" -and $CliOptions[$key] -ne 0) {
            $config[$key] = $CliOptions[$key]
        }
    }

    return $config
}

# Capture CLI-provided options from parameters
$cliOptions = @{
    VMName = $VMName
    Memory = $Memory
    Disk = $Disk
    CPUs = $CPUs
    Network = $Network
    NgrokAuthToken = $NgrokAuthToken
    NgrokDomain = $NgrokDomain
}

# Determine config file path
$configPath = if ($ConfigFile) { $ConfigFile } else { $DefaultConfigFile }

# Get merged configuration
$options = Get-Config -CliOptions $cliOptions -ConfigFilePath $configPath

# Extract values for use in script
$VMName = $options.VMName
$Memory = $options.Memory
$Disk = $options.Disk
$CPUs = $options.CPUs
$Network = $options.Network
$NgrokAuthToken = $options.NgrokAuthToken
$NgrokDomain = $options.NgrokDomain

Write-Host @"

========================================
  Headscale VPS Deployment (Testing)
========================================

See TESTING.md for full documentation.

"@ -ForegroundColor Cyan

#region Configuration Functions

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow

    # Check if multipass is installed
    try {
        $multipassVersion = multipass version
        Write-Host "✓ Multipass installed: $($multipassVersion[0])" -ForegroundColor Green
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
            $prompt = "$PromptText: "
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
                if ($value -notmatch '^[^@]+@[^@]+\.[^@]+$') {
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

function Get-Configuration {
    param([hashtable]$Options)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Configuration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Initialize config with values from options (may have been loaded from JSON)
    $config = @{
        HEADSCALE_DOMAIN = $Options.HEADSCALE_DOMAIN ?? ""
        AZURE_TENANT_ID = $Options.AZURE_TENANT_ID ?? ""
        AZURE_CLIENT_ID = $Options.AZURE_CLIENT_ID ?? ""
        AZURE_CLIENT_SECRET = $Options.AZURE_CLIENT_SECRET ?? ""
        ALLOWED_EMAIL = $Options.ALLOWED_EMAIL ?? ""
    }

    Write-Host "Ngrok will be used for OAuth callbacks:" -ForegroundColor Yellow
    Write-Host "  Domain: https://$NgrokDomain" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: You can use the ngrok domain OR a custom domain for Headscale." -ForegroundColor Yellow
    Write-Host "      If using custom domain, ensure DNS points to the VM IP." -ForegroundColor Yellow
    Write-Host ""

    # Prompt for configuration
    $config.HEADSCALE_DOMAIN = Get-ConfigValue `
        -PromptText "Headscale Domain (e.g., $NgrokDomain)" `
        -DefaultValue $NgrokDomain `
        -ValidationType Domain

    $config.AZURE_TENANT_ID = Get-ConfigValue `
        -PromptText "Azure Tenant ID (e.g., contoso.onmicrosoft.com or GUID)" `
        -DefaultValue $config.AZURE_TENANT_ID `
        -ValidationType UUID

    $config.AZURE_CLIENT_ID = Get-ConfigValue `
        -PromptText "Azure Application (Client) ID" `
        -DefaultValue $config.AZURE_CLIENT_ID `
        -ValidationType UUID

    $config.AZURE_CLIENT_SECRET = Get-ConfigValue `
        -PromptText "Azure Client Secret Value" `
        -DefaultValue $config.AZURE_CLIENT_SECRET `
        -IsSecret

    $config.ALLOWED_EMAIL = Get-ConfigValue `
        -PromptText "Allowed Email Address for login" `
        -DefaultValue $config.ALLOWED_EMAIL `
        -ValidationType Email

    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "  Domain:        $($config.HEADSCALE_DOMAIN)" -ForegroundColor White
    Write-Host "  Tenant ID:     $($config.AZURE_TENANT_ID)" -ForegroundColor White
    Write-Host "  Client ID:     $($config.AZURE_CLIENT_ID)" -ForegroundColor White
    Write-Host "  Client Secret: ****" -ForegroundColor White
    Write-Host "  Allowed Email: $($config.ALLOWED_EMAIL)" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "Is this configuration correct? [Y/n]"
    if ($confirm -eq 'n' -or $confirm -eq 'N') {
        Write-Host "Configuration cancelled. Please run the script again." -ForegroundColor Yellow
        exit 0
    }

    return $config
}

#endregion

#region Ngrok Info

function Show-NgrokInfo {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  ngrok Configuration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "ngrok will be installed inside the VM with:" -ForegroundColor Yellow
    Write-Host "  Authtoken: $NgrokAuthToken" -ForegroundColor White
    Write-Host "  Domain:    https://$NgrokDomain" -ForegroundColor White
    Write-Host ""
    Write-Host "After deployment, you'll start ngrok from inside the VM." -ForegroundColor Yellow
    Write-Host ""
}

#endregion

#region VM Deployment

function New-ConfiguredCloudInit {
    param($Config)

    Write-Host "Generating configured cloud-init.yml..." -ForegroundColor Yellow

    # Read base cloud-init.yml
    $cloudInitContent = Get-Content ".\cloud-init.yml" -Raw

    # Create a custom cloud-init with injected config
    # We'll add a runcmd at the end to automatically configure the system
    $configScript = @"

  # Auto-configuration script (injected by Deploy-Headscale.ps1)
  - path: /root/auto-configure.sh
    permissions: "0700"
    content: |
      #!/bin/bash
      # Wait for setup to complete
      echo "Waiting for initial setup to complete..."
      sleep 30

      # Configure headscale with provided values
      cat > /tmp/headscale-autoconfig.sh << 'AUTOCONFIG'
      export HEADSCALE_DOMAIN="$($Config.HEADSCALE_DOMAIN)"
      export AZURE_TENANT_ID="$($Config.AZURE_TENANT_ID)"
      export AZURE_CLIENT_ID="$($Config.AZURE_CLIENT_ID)"
      export AZURE_CLIENT_SECRET="$($Config.AZURE_CLIENT_SECRET)"
      export ALLOWED_EMAIL="$($Config.ALLOWED_EMAIL)"

      # Run headscale-config with environment variables
      sudo -E bash -c '
        source /etc/headscale/versions.conf

        # Write environment file
        mkdir -p /etc/environment.d
        cat > /etc/environment.d/headscale.conf << EOF
HEADSCALE_DOMAIN="\$HEADSCALE_DOMAIN"
AZURE_TENANT_ID="\$AZURE_TENANT_ID"
AZURE_CLIENT_ID="\$AZURE_CLIENT_ID"
AZURE_CLIENT_SECRET="\$AZURE_CLIENT_SECRET"
ALLOWED_EMAIL="\$ALLOWED_EMAIL"
EOF

        # Write OIDC secret
        echo -n "\$AZURE_CLIENT_SECRET" > /var/lib/headscale/oidc_client_secret
        chown headscale:headscale /var/lib/headscale/oidc_client_secret
        chmod 600 /var/lib/headscale/oidc_client_secret

        # Process templates
        envsubst < /etc/headscale/templates/headscale.yaml.tpl > /etc/headscale/config.yaml
        envsubst < /etc/headscale/templates/headplane.yaml.tpl > /etc/headplane/config.yaml
        envsubst < /etc/headscale/templates/Caddyfile.tpl > /etc/caddy/Caddyfile

        # Generate API key
        systemctl start headscale
        sleep 5
        API_KEY=\$(headscale apikeys create --expiration 90d 2>/dev/null | tail -1)
        echo -n "\$API_KEY" > /var/lib/headscale/api_key
        chown headscale:headscale /var/lib/headscale/api_key
        chmod 600 /var/lib/headscale/api_key
        date -d "+90 days" +%Y-%m-%d > /var/lib/headscale/api_key_expires

        # Restart services
        systemctl restart headscale
        systemctl restart caddy

        echo "Auto-configuration complete!"
      '
AUTOCONFIG

      bash /tmp/headscale-autoconfig.sh
      rm /tmp/headscale-autoconfig.sh

runcmd:
  - /opt/setup-headscale.sh
  - /root/auto-configure.sh
"@

    # Inject the auto-config into cloud-init
    $modifiedCloudInit = $cloudInitContent -replace '(runcmd:[\s\S]*)', "write_files:$configScript`nruncmd:`n  - /opt/setup-headscale.sh`n  - /root/auto-configure.sh"

    # Save modified cloud-init
    $tempCloudInit = Join-Path $env:TEMP "cloud-init-configured.yml"
    $modifiedCloudInit | Out-File -FilePath $tempCloudInit -Encoding UTF8 -NoNewline

    Write-Host "✓ Configured cloud-init generated: $tempCloudInit" -ForegroundColor Green
    return $tempCloudInit
}

function Start-MultipassVM {
    param(
        [string]$CloudInitPath
    )

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Launching Multipass VM" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "VM Configuration:" -ForegroundColor Yellow
    Write-Host "  Name:    $VMName" -ForegroundColor White
    Write-Host "  Memory:  $Memory" -ForegroundColor White
    Write-Host "  Disk:    $Disk" -ForegroundColor White
    Write-Host "  CPUs:    $CPUs" -ForegroundColor White
    Write-Host "  Network: $Network" -ForegroundColor White
    Write-Host ""

    # Check if VM already exists
    try {
        $existingVM = multipass list | Select-String $VMName
        if ($existingVM) {
            Write-Host "VM '$VMName' already exists!" -ForegroundColor Yellow
            $overwrite = Read-Host "Delete and recreate? [y/N]"
            if ($overwrite -eq 'y' -or $overwrite -eq 'Y') {
                Write-Host "Deleting existing VM..." -ForegroundColor Yellow
                multipass delete $VMName
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
        multipass launch --name $VMName `
            --cloud-init $CloudInitPath `
            --memory $Memory `
            --disk $Disk `
            --cpus $CPUs `
            --network $Network `
            22.04

        Write-Host "✓ VM launched successfully!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to launch VM: $_" -ForegroundColor Red
        exit 1
    }

    # Get VM IP
    Start-Sleep -Seconds 5
    $vmInfo = multipass info $VMName
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
    param([string]$VMName)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Monitoring Deployment" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cloud-init is now running setup. This will take 5-10 minutes." -ForegroundColor Yellow
    Write-Host "You can monitor progress with:" -ForegroundColor Yellow
    Write-Host "  multipass exec $VMName -- cloud-init status --wait" -ForegroundColor Cyan
    Write-Host "  multipass exec $VMName -- journalctl -u cloud-final -f" -ForegroundColor Cyan
    Write-Host ""

    $monitor = Read-Host "Monitor deployment progress? [Y/n]"
    if ($monitor -ne 'n' -and $monitor -ne 'N') {
        Write-Host "Waiting for cloud-init to complete..." -ForegroundColor Yellow
        multipass exec $VMName -- cloud-init status --wait
        Write-Host "✓ Cloud-init completed!" -ForegroundColor Green
    }
}

function Install-Ngrok {
    param([string]$VMName)

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
curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-\${NGROK_VERSION}-linux-amd64.tgz -o /tmp/ngrok.tgz
tar -xzf /tmp/ngrok.tgz -C /usr/local/bin
chmod +x /usr/local/bin/ngrok
rm /tmp/ngrok.tgz
echo '✓ ngrok installed: '\$(ngrok version)
"@

    try {
        # Install ngrok binary
        $installScript | multipass exec $VMName -- sudo bash

        # Create start-ngrok-tunnel helper script
        $tunnelScript = @"
#!/bin/bash
# Start ngrok tunnel for Headscale testing
AUTHTOKEN='$NgrokAuthToken'
DOMAIN='$NgrokDomain'

echo '=========================================='
echo '  Starting ngrok tunnel'
echo '=========================================='
echo ''

# Configure authtoken if not already done
if [ ! -f ~/.ngrok2/ngrok.yml ]; then
  echo 'Configuring ngrok authtoken...'
  ngrok config add-authtoken '\$AUTHTOKEN'
fi

echo 'Tunnel configuration:'
echo '  Domain: https://'\$DOMAIN
echo '  Target: https://localhost:443'
echo ''
echo 'Starting tunnel... (Press Ctrl+C to stop)'
echo ''

# Start tunnel with static domain
ngrok http --domain='\$DOMAIN' https://localhost:443
"@

        $tunnelScript | multipass exec $VMName -- sudo bash -c "cat > /usr/local/bin/start-ngrok-tunnel && chmod +x /usr/local/bin/start-ngrok-tunnel"

        Write-Host "✓ ngrok installed successfully!" -ForegroundColor Green
        Write-Host "✓ start-ngrok-tunnel helper created" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to install ngrok: $_" -ForegroundColor Red
        Write-Host "  You can install it manually with the commands above" -ForegroundColor Yellow
    }
}

#endregion

#region Post-Deployment

function Show-DeploymentSummary {
    param(
        [string]$VMName,
        [string]$VMIP,
        [hashtable]$Config
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "VM Information:" -ForegroundColor Cyan
    Write-Host "  Name: $VMName" -ForegroundColor White
    Write-Host "  IP:   $VMIP" -ForegroundColor White
    Write-Host ""

    Write-Host "Access URLs:" -ForegroundColor Cyan
    Write-Host "  Headplane UI:  https://$($Config.HEADSCALE_DOMAIN)/admin" -ForegroundColor White
    Write-Host "  Headscale API: https://$($Config.HEADSCALE_DOMAIN)/api" -ForegroundColor White
    Write-Host ""

    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Start ngrok tunnel (in a separate terminal):" -ForegroundColor Yellow
    Write-Host "   multipass exec $VMName -- start-ngrok-tunnel" -ForegroundColor White
    Write-Host "   This creates the tunnel: https://$NgrokDomain -> VM:443" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Verify Headplane is running:" -ForegroundColor Yellow
    Write-Host "   multipass exec $VMName -- systemctl status headplane" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Connect a Tailscale client:" -ForegroundColor Yellow
    Write-Host "   tailscale up --login-server https://$($Config.HEADSCALE_DOMAIN)" -ForegroundColor White
    Write-Host ""
    Write-Host "4. SSH into VM for direct access:" -ForegroundColor Yellow
    Write-Host "   multipass shell $VMName" -ForegroundColor White
    Write-Host ""
    Write-Host "5. View health status:" -ForegroundColor Yellow
    Write-Host "   multipass exec $VMName -- sudo headscale-healthcheck" -ForegroundColor White
    Write-Host ""

    Write-Host "Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  View logs:    multipass exec $VMName -- journalctl -u headscale -f" -ForegroundColor White
    Write-Host "  View setup:   multipass exec $VMName -- cat /var/log/cloud-init-output.log" -ForegroundColor White
    Write-Host "  Stop VM:      multipass stop $VMName" -ForegroundColor White
    Write-Host "  Delete VM:    multipass delete $VMName && multipass purge" -ForegroundColor White
    Write-Host ""
}

#endregion

#region Main

function Main {
    try {
        # Prerequisites
        Test-Prerequisites

        # Configuration (pass options for defaults)
        $config = Get-Configuration -Options $options

        # ngrok info
        Show-NgrokInfo

        # Generate configured cloud-init
        $cloudInitPath = New-ConfiguredCloudInit -Config $config

        # Launch VM
        $vmIP = Start-MultipassVM -CloudInitPath $cloudInitPath

        # Monitor deployment
        Watch-Deployment -VMName $VMName

        # Install ngrok after cloud-init completes
        Install-Ngrok -VMName $VMName

        # Show summary
        Show-DeploymentSummary -VMName $VMName -VMIP $vmIP -Config $config

        # Save complete config for future use (merge VM/ngrok options with Headscale config)
        $fullConfig = $options.Clone()

        # Add Headscale configuration values
        $fullConfig.HEADSCALE_DOMAIN = $config.HEADSCALE_DOMAIN
        $fullConfig.AZURE_TENANT_ID = $config.AZURE_TENANT_ID
        $fullConfig.AZURE_CLIENT_ID = $config.AZURE_CLIENT_ID
        $fullConfig.AZURE_CLIENT_SECRET = $config.AZURE_CLIENT_SECRET
        $fullConfig.ALLOWED_EMAIL = $config.ALLOWED_EMAIL

        $configPath = ".\headscale-config-$($options.VMName).json"
        $fullConfig | ConvertTo-Json | Out-File $configPath
        Write-Host "Configuration saved to: $configPath" -ForegroundColor Green
        Write-Host "  Use -ConfigFile ""$configPath"" to reuse these settings" -ForegroundColor Cyan

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
        exit 1
    }
}

# Run main function
Main

#endregion
