# Testing Guide

This guide covers testing the Headscale VPS deployment using Multipass VMs and automated PowerShell workflows.

## Overview

The testing infrastructure uses:
- **Multipass** - Ubuntu VM orchestration on Windows
- **PowerShell Automation** - `Deploy-Headscale.ps1` script for complete deployment workflow
- **ngrok** - Secure tunneling for OAuth/OIDC callback testing (temporary, testing-only)

**Important:** ngrok is NOT included in production deployments. It's only installed during testing via the PowerShell script.

## Prerequisites

### Required Software

1. **Multipass** - Install from https://multipass.run/install
   ```powershell
   # Verify installation
   multipass version
   ```

2. **PowerShell 7+** - Windows PowerShell 5.1 or PowerShell 7
   ```powershell
   $PSVersionTable.PSVersion
   ```

3. **Azure AD Tenant** - For OIDC testing
   - Test tenant recommended (not production)
   - App registration with test redirect URIs

### Network Configuration

The PowerShell script uses `--network "Ethernet 3"` by default for performance. Adjust this for your system:

```powershell
# List available network adapters
Get-NetAdapter | Select-Object Name, Status, LinkSpeed

# Use in script
.\Deploy-Headscale.ps1 -Network "Your Network Name"
```

## Quick Start

### Basic Testing Workflow

```powershell
# 1. Navigate to project directory
cd D:\Orchestrations\Headscale-VPS

# 2. Run deployment script
.\Deploy-Headscale.ps1

# The script will:
# - Prompt for configuration (domain, tenant ID, client ID, etc.)
# - Launch Multipass VM
# - Run cloud-init setup (~5-10 minutes)
# - Automatically install ngrok inside VM
# - Display next steps
```

### Start Testing

After deployment completes:

```powershell
# 1. Start ngrok tunnel (in separate terminal)
multipass exec headscale-test -- start-ngrok-tunnel

# 2. Verify Headplane is running
multipass exec headscale-test -- systemctl status headplane

# 3. Test web UI access
# Open: https://[REDACTED-NGROK-DOMAIN]/admin

# 4. Test Tailscale client connection
tailscale up --login-server https://[REDACTED-NGROK-DOMAIN]
```

## Deploy-Headscale.ps1 Reference

### Synopsis

Deploy and test Headscale VPS using Multipass with complete configuration coverage.

### Description

Automates the deployment of Headscale + Headplane to a Multipass VM with:
- Complete configuration coverage (no manual steps required)
- ngrok integration for OAuth callbacks
- Automated setup of all services
- Health check verification

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-VMName` | string | `headscale-test` | Name for the Multipass VM |
| `-Memory` | string | `2G` | Memory allocation for VM |
| `-Disk` | string | `20G` | Disk allocation for VM |
| `-CPUs` | int | `2` | CPU allocation for VM |
| `-ConfigFile` | string | `""` | Path to existing config JSON (optional) |
| `-Network` | string | `"Ethernet 3"` | Network adapter to use |

### Examples

**Basic deployment:**
```powershell
.\Deploy-Headscale.ps1
```

**Custom resources:**
```powershell
.\Deploy-Headscale.ps1 -VMName "headscale-prod" -Memory "4G" -CPUs 4
```

**Reuse configuration:**
```powershell
# First deployment saves config to headscale-config-{VMName}.json
.\Deploy-Headscale.ps1 -ConfigFile ".\headscale-config-headscale-test.json"
```

## ngrok Configuration

### Hardcoded Configuration

The PowerShell script includes pre-configured ngrok settings:
- **Authtoken**: `[REDACTED-NGROK-TOKEN]`
- **Domain**: `[REDACTED-NGROK-DOMAIN]`

### How ngrok Works in Testing

1. **Installation**: PowerShell script automatically installs ngrok inside VM after cloud-init
2. **Helper Script**: Creates `/usr/local/bin/start-ngrok-tunnel` with authtoken pre-configured
3. **Tunnel Start**: Run `multipass exec {VM} -- start-ngrok-tunnel` to create tunnel
4. **OAuth Callbacks**: Azure AD redirect URIs use ngrok domain for testing

### ngrok Tunnel Commands

```powershell
# Start tunnel (blocks terminal - use separate window)
multipass exec headscale-test -- start-ngrok-tunnel

# Access via ngrok domain
https://[REDACTED-NGROK-DOMAIN]/admin

# Stop tunnel
# Press Ctrl+C in the terminal running start-ngrok-tunnel
```

## Testing Scenarios

### Scenario 1: Basic Deployment Test

**Goal**: Verify cloud-init completes successfully and services start.

```powershell
# 1. Deploy VM
.\Deploy-Headscale.ps1

# 2. Verify services
multipass exec headscale-test -- sudo systemctl status headscale
multipass exec headscale-test -- sudo systemctl status caddy
multipass exec headscale-test -- sudo systemctl status fail2ban

# 3. Run health check
multipass exec headscale-test -- sudo headscale-healthcheck

# Expected: All services running, health check passes
```

### Scenario 2: OIDC Authentication Test

**Goal**: Test Azure AD authentication flow.

```powershell
# 1. Deploy and configure
.\Deploy-Headscale.ps1
# (Provide Azure AD credentials when prompted)

# 2. Start ngrok
multipass exec headscale-test -- start-ngrok-tunnel

# 3. Test OIDC login
# Open browser: https://[REDACTED-NGROK-DOMAIN]/admin
# Should redirect to Azure AD login

# 4. Test Tailscale client
tailscale up --login-server https://[REDACTED-NGROK-DOMAIN]
# Should open browser for Azure AD auth
```

### Scenario 3: Update Mechanism Test

**Goal**: Verify automatic updates work correctly.

```powershell
# 1. Deploy VM
.\Deploy-Headscale.ps1

# 2. Check current versions
multipass exec headscale-test -- headscale version
multipass exec headscale-test -- cat /opt/headplane/package.json | grep version

# 3. Force update check
multipass exec headscale-test -- sudo /usr/local/bin/headscale-update

# 4. Verify update log
multipass exec headscale-test -- cat /var/log/headscale/updates.log
```

### Scenario 4: Security Hardening Test

**Goal**: Verify security features are active.

```powershell
# 1. Deploy VM
.\Deploy-Headscale.ps1

# 2. Test SSH hardening
multipass exec headscale-test -- sudo sshd -T | grep -i passwordauth
# Expected: passwordauthentication no

# 3. Test fail2ban
multipass exec headscale-test -- sudo fail2ban-client status
# Expected: sshd, caddy-oidc, headscale-authkey, recidive jails active

# 4. Test firewall
multipass exec headscale-test -- sudo ufw status
# Expected: Only ports 22, 80, 443, 3478/udp open

# 5. View audit logs
multipass exec headscale-test -- sudo ausearch -k headscale_config
```

### Scenario 5: API Key Rotation Test

**Goal**: Verify automatic API key rotation.

```powershell
# 1. Deploy VM
.\Deploy-Headscale.ps1

# 2. Check current API key expiry
multipass exec headscale-test -- cat /var/lib/headscale/api_key_expires

# 3. Rotate manually
multipass exec headscale-test -- sudo headscale-rotate-apikey

# 4. Verify new expiry date
multipass exec headscale-test -- cat /var/lib/headscale/api_key_expires

# 5. Verify Headplane still works
# Open: https://[REDACTED-NGROK-DOMAIN]/admin
```

## VM Management

### Multipass Commands

```powershell
# List VMs
multipass list

# Get VM info
multipass info headscale-test

# Shell access
multipass shell headscale-test

# Execute command
multipass exec headscale-test -- ls -la /etc/headscale

# View VM logs
multipass exec headscale-test -- journalctl -u cloud-final -f

# Stop VM
multipass stop headscale-test

# Start VM
multipass start headscale-test

# Delete VM
multipass delete headscale-test
multipass purge
```

### Snapshot & Recovery

```powershell
# Create snapshot (useful before risky changes)
multipass stop headscale-test
multipass snapshot headscale-test backup-$(Get-Date -Format 'yyyyMMdd-HHmm')

# List snapshots
multipass list --snapshots

# Restore snapshot
multipass restore headscale-test.backup-20250101-1200

# Delete snapshot
multipass delete headscale-test.backup-20250101-1200
```

## Configuration Testing

### Test Different Configurations

```powershell
# Test with different Azure AD tenants
.\Deploy-Headscale.ps1 -VMName "test-tenant-a"
# Provide Tenant A credentials

.\Deploy-Headscale.ps1 -VMName "test-tenant-b"
# Provide Tenant B credentials

# Test with different resource allocations
.\Deploy-Headscale.ps1 -VMName "test-2cpu" -CPUs 2 -Memory "2G"
.\Deploy-Headscale.ps1 -VMName "test-4cpu" -CPUs 4 -Memory "4G"
```

### Saved Configuration Reuse

The script saves configuration to `headscale-config-{VMName}.json`:

```json
{
  "HEADSCALE_DOMAIN": "[REDACTED-NGROK-DOMAIN]",
  "AZURE_TENANT_ID": "contoso.onmicrosoft.com",
  "AZURE_CLIENT_ID": "12345678-1234-1234-1234-123456789abc",
  "AZURE_CLIENT_SECRET": "secret-value",
  "ALLOWED_EMAIL": "user@contoso.onmicrosoft.com"
}
```

Reuse saved config:
```powershell
.\Deploy-Headscale.ps1 -ConfigFile ".\headscale-config-headscale-test.json"
```

## Troubleshooting

### Cloud-init Failed

```powershell
# View cloud-init status
multipass exec headscale-test -- cloud-init status

# View cloud-init logs
multipass exec headscale-test -- cat /var/log/cloud-init-output.log

# View setup script logs
multipass exec headscale-test -- journalctl -u cloud-final -n 100
```

### ngrok Installation Failed

```powershell
# Verify ngrok binary
multipass exec headscale-test -- which ngrok

# Check ngrok version
multipass exec headscale-test -- ngrok version

# Reinstall manually
multipass exec headscale-test -- 'curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /tmp/ngrok.tgz && sudo tar -xzf /tmp/ngrok.tgz -C /usr/local/bin'
```

### Services Not Starting

```powershell
# Check all service statuses
multipass exec headscale-test -- sudo systemctl status headscale caddy fail2ban

# View specific service logs
multipass exec headscale-test -- journalctl -u headscale -f
multipass exec headscale-test -- journalctl -u caddy -f

# Restart services
multipass exec headscale-test -- sudo systemctl restart headscale
multipass exec headscale-test -- sudo systemctl restart caddy
```

### Configuration Errors

```powershell
# View current configuration
multipass exec headscale-test -- cat /etc/environment.d/headscale.conf

# Reconfigure manually
multipass exec headscale-test -- sudo headscale-config

# Verify template processing
multipass exec headscale-test -- cat /etc/headscale/config.yaml
```

### Network Connectivity Issues

```powershell
# Check VM IP
multipass info headscale-test | Select-String IPv4

# Test DNS resolution
multipass exec headscale-test -- nslookup google.com

# Test outbound HTTPS
multipass exec headscale-test -- curl -v https://google.com

# Check firewall rules
multipass exec headscale-test -- sudo ufw status verbose
```

## Performance Testing

### Load Testing

```powershell
# Connect multiple Tailscale clients
# (Use separate devices or VMs)
for ($i=1; $i -le 10; $i++) {
    tailscale up --login-server https://[REDACTED-NGROK-DOMAIN]
}

# Monitor resource usage
multipass exec headscale-test -- htop
```

### Benchmark API Performance

```powershell
# Benchmark Headscale API
multipass exec headscale-test -- 'ab -n 1000 -c 10 http://localhost:8080/health'

# Check response times
multipass exec headscale-test -- 'curl -w "@-" -o /dev/null -s http://localhost:8080/health <<< "time_total: %{time_total}s\n"'
```

## Cleanup

### Delete Test VM

```powershell
# Stop and delete VM
multipass stop headscale-test
multipass delete headscale-test
multipass purge

# Remove saved configuration
Remove-Item .\headscale-config-headscale-test.json
```

### Reset Azure AD App Registration

After testing, clean up Azure AD:
1. Go to Azure Portal → App Registrations
2. Remove test redirect URIs (ngrok domain)
3. Rotate client secret if exposed
4. Remove test users from allowed list

## Continuous Integration

### Automated Testing Script Example

```powershell
# test-deployment.ps1
param([string]$ConfigFile = "test-config.json")

try {
    # Deploy
    .\Deploy-Headscale.ps1 -ConfigFile $ConfigFile -VMName "ci-test"

    # Wait for services
    Start-Sleep -Seconds 30

    # Run health check
    $health = multipass exec ci-test -- sudo headscale-healthcheck
    if ($LASTEXITCODE -ne 0) {
        throw "Health check failed"
    }

    # Verify services
    $services = @("headscale", "caddy", "fail2ban")
    foreach ($svc in $services) {
        $status = multipass exec ci-test -- systemctl is-active $svc
        if ($status -ne "active") {
            throw "$svc is not active"
        }
    }

    Write-Host "All tests passed!" -ForegroundColor Green
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    multipass delete ci-test --purge
}
```

## Best Practices

1. **Use Separate VMs**: Don't reuse VMs between tests - delete and recreate for clean state
2. **Save Configurations**: Keep test configs in version control (exclude secrets)
3. **Test in Isolation**: Use dedicated Azure AD test tenant
4. **Monitor Resources**: Watch VM resource usage during tests
5. **Document Failures**: Capture logs and configurations when tests fail
6. **Automate Repetitive Tests**: Script common testing workflows
7. **Test Rollbacks**: Practice restoring from snapshots
8. **Verify Security**: Always test security features after changes

## References

- [Multipass Documentation](https://multipass.run/docs)
- [ngrok Documentation](https://ngrok.com/docs)
- [cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Main README](README.md) - Production deployment guide
