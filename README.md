# Headscale VPS

Production-ready deployment of [Headscale](https://github.com/juanfont/headscale) (self-hosted Tailscale control server) with [Headplane](https://github.com/tale/headplane) web UI on Ubuntu, using cloud-init for automated setup.

## Features

### Core Services
- **Headscale** - Native installation (no containers) with automatic updates
- **Headplane** - Web UI for Headscale management (built from source with Node.js)
- **Caddy** - Reverse proxy with automatic TLS certificate management
- **Azure AD OIDC** - Single sign-on authentication for both Headscale and Headplane

### Security & Hardening
- **SSH Hardening** - Password authentication disabled, root login disabled, max auth tries limited
- **Kernel Hardening** - Network protections, ASLR, kernel pointer restrictions via sysctl
- **Systemd Hardening** - Capability bounding, system call filtering, private devices
- **Fail2ban** - Protection against brute-force attacks with email notifications
  - SSH jail (4 attempts, 24h ban)
  - OIDC authentication jail (5 attempts, 12h ban)
  - Headscale auth key jail (5 attempts, 12h ban)
  - Recidive jail for repeat offenders (3 violations, 1-week ban)
- **Auditd** - Monitoring of configuration changes and secret access
- **UFW Firewall** - Only essential ports exposed (22, 80, 443, 3478/udp)

### Automation & Maintenance
- **Template-based Configuration** - Environment variables with envsubst for easy customization
- **Automatic API Key Rotation** - Weekly checks, auto-renewal when <14 days remaining
- **Controlled OS Updates** - Security-only unattended upgrades (no breaking changes)
- **Application Updates** - Automatic Headscale/Headplane updates via GitHub releases
- **Email Notifications** - Alerts for updates, fail2ban bans, and reboots (via M365 SMTP)
- **Health Monitoring** - Systemd timer runs comprehensive checks every 5 minutes
- **Checksum Verification** - All downloads (NVM, Headscale, Caddy) verified before installation
- **Error Handling** - Comprehensive error logging with context, no silent failures
- **Input Validation** - RFC 5322 compliant email validation, domain validation, UUID validation

## Quick Start

### Prerequisites

- Ubuntu 22.04 LTS server (VPS, bare metal, or VM)
- Public domain name pointing to your server
- Azure AD (Microsoft Entra ID) tenant for OIDC authentication

### Production Deployment

```bash
# Download cloud-init.yml
wget https://raw.githubusercontent.com/anonhostpi/Headscale-VPS/main/cloud-init.yml

# Deploy to a new Ubuntu 22.04 instance
# (Method varies by hosting provider - see examples below)
```

#### Deployment Examples

**Multipass (local testing):**
```bash
multipass launch --name headscale --cloud-init cloud-init.yml \
  --memory 2G --disk 20G --cpus 2 22.04
```

**Cloud providers:** Most VPS providers accept cloud-init configuration during instance creation. Upload `cloud-init.yml` or paste its contents during setup.

### Post-Installation Configuration

After cloud-init completes (~5-10 minutes), run these commands on your server:

```bash
# 1. Configure Azure AD OIDC (required)
#    First, set up Azure AD app registration (see AZURE_AD_SETUP.md)
#    Then run the configuration wizard:
sudo headscale-config

# 2. Verify services are running
systemctl status headscale
systemctl status headplane
systemctl status caddy

# 3. Configure email notifications (optional)
#    For fail2ban alerts and update notifications:
sudo msmtp-config
```

### Azure AD Setup

Complete setup guide: [AZURE_AD_SETUP.md](AZURE_AD_SETUP.md)

**Quick overview:**
1. Create Azure AD App Registration
2. Add redirect URIs:
   - `https://YOUR_DOMAIN/oidc/callback`
   - `https://YOUR_DOMAIN/admin/oidc/callback`
3. Create client secret (save immediately!)
4. Run `sudo headscale-config` with the credentials

See [AZURE_AD_SETUP.md](AZURE_AD_SETUP.md) for detailed step-by-step instructions and troubleshooting.

### Connect Tailscale Clients

```bash
# On any device with Tailscale installed
tailscale up --login-server https://YOUR_DOMAIN
```

Your browser will open for Azure AD authentication.

## Architecture

```
Internet
    │
    ├─ Port 443 (HTTPS) ─→ Caddy ─┬─ /admin/* ──→ Headplane (port 3000)
    │                              ├─ /oidc/* ───→ Headscale (port 8080)
    │                              ├─ /api/* ────→ Headscale (port 8080)
    │                              └─ /ts2021 ───→ Headscale (port 8080)
    │
    ├─ Port 22 (SSH) ──────────────→ OpenSSH (hardened)
    │
    └─ Port 3478/udp (STUN) ───────→ Headscale DERP
```

### Directory Structure

| Path | Purpose |
|------|---------|
| `/etc/headscale/` | Headscale configuration files |
| `/etc/headscale/templates/` | Configuration templates (processed by envsubst) |
| `/etc/headplane/` | Headplane configuration |
| `/var/lib/headscale/` | Headscale database and secrets |
| `/var/lib/headplane/` | Headplane data files |
| `/opt/headplane/` | Headplane source and build |
| `/var/log/headscale/` | Headscale and update logs |
| `/usr/local/bin/headscale-*` | Management scripts |
| `/usr/local/lib/headscale-*.sh` | Shared libraries |

## Management

### Configuration

```bash
# Reconfigure OIDC settings
sudo headscale-config

# Reconfigure email notifications
sudo msmtp-config

# Edit version pinning
sudo nano /etc/headscale/versions.conf
```

### Secrets Management

```bash
# Check encryption status of secrets
sudo headscale-migrate-secrets status

# Manually migrate existing plaintext secrets to encrypted
sudo headscale-migrate-secrets migrate

# Rollback to plaintext secrets (if needed)
sudo headscale-migrate-secrets rollback

# After migration, restart services to use encrypted credentials
sudo systemctl daemon-reload
sudo systemctl restart headscale headplane
```

**Note:** New deployments automatically encrypt secrets when you run `headscale-config` or `msmtp-config`. Manual migration is only needed for existing deployments.

### Monitoring

```bash
# Run health check manually
sudo headscale-healthcheck

# Check health check timer status
systemctl status headscale-healthcheck.timer

# View service status
systemctl status headscale
systemctl status headplane
systemctl status caddy

# View logs
journalctl -u headscale -f
journalctl -u headplane -f
journalctl -u caddy -f

# View update history
cat /var/log/headscale/updates.log
```

### Updates

**OS Updates:**
- Security updates apply automatically via unattended-upgrades
- System reboots automatically at 3:00 AM if kernel updates require it
- Email notifications sent for all updates (if msmtp configured)

**Application Updates:**
- Headscale and Headplane check for updates after OS updates
- Updates are automatic unless version pinning is configured in `/etc/headscale/versions.conf`

**Manual Updates:**
```bash
# Check for and apply updates
sudo /usr/local/bin/headscale-update

# Rotate API key manually
sudo headscale-rotate-apikey
```

### Maintenance

```bash
# View Fail2ban bans
sudo fail2ban-client status sshd
sudo fail2ban-client status caddy-oidc

# Unban an IP address
sudo fail2ban-client set sshd unbanip 1.2.3.4

# View audit logs for config changes
sudo ausearch -k headscale_config
sudo ausearch -k oidc_secret_access

# View disk usage
df -h /var/lib/headscale
```

## Security Considerations

### Secrets Management

**Encryption (systemd-creds):**
- Secrets are automatically encrypted using systemd-creds on systems with systemd 250+
- Encrypted credentials stored in `/etc/credstore.encrypted/`
- Systemd services automatically decrypt credentials at runtime
- Backward compatible: falls back to plaintext files if encryption unavailable

**Secret Locations:**
- OIDC client secret: Encrypted in `/etc/credstore.encrypted/oidc_client_secret.cred`
- API key: Encrypted in `/etc/credstore.encrypted/headscale_api_key.cred`
- SMTP password: Encrypted in `/etc/credstore.encrypted/smtp_password.cred`
- Plaintext backups: Available for rollback (`.plaintext-backup` suffix)

**Migration Commands:**
```bash
# Check encryption status
sudo headscale-migrate-secrets status

# Migrate plaintext secrets to encrypted (automatic on new deployments)
sudo headscale-migrate-secrets migrate

# Rollback to plaintext if needed
sudo headscale-migrate-secrets rollback
```

**How It Works:**
- When you run `headscale-config` or `msmtp-config`, secrets are automatically encrypted
- Systemd services load encrypted credentials via `LoadCredentialEncrypted=` directives
- Configuration files reference `/run/credentials/<service>/<secret_name>` paths
- Secrets are bound to the machine ID for security

### Network Security

- **UFW Firewall**: Only essential ports open
- **Fail2ban**: Automatic IP banning for failed authentication attempts
- **Rate Limiting**: Configured in Caddy for OIDC endpoints
- **TLS**: Automatic certificate management via Let's Encrypt

### Access Control

- **SSH**: Key-based authentication only, root login disabled
- **OIDC**: Azure AD controls who can authenticate
- **Headscale**: `allowed_users` list in configuration
- **Headplane**: OIDC authentication required for admin UI

## Troubleshooting

### Services Not Starting

```bash
# Check service status and recent logs
systemctl status headscale
journalctl -u headscale -n 50

# Verify configuration syntax
headscale configtest

# Check certificate status
sudo caddy validate --config /etc/caddy/Caddyfile
```

### OIDC Authentication Failures

```bash
# Check OIDC configuration
cat /etc/environment.d/headscale.conf

# Verify redirect URIs in Azure AD match your domain
# Check Caddy logs for 401 errors
journalctl -u caddy -f | grep 401

# Test OIDC endpoint
curl -v https://YOUR_DOMAIN/oidc/.well-known/openid-configuration
```

### Email Notifications Not Working

```bash
# Check msmtp configuration
cat /etc/msmtprc

# Test email sending
echo "Subject: Test\n\nTest email" | msmtp your@email.com

# View msmtp logs
cat /var/log/msmtp.log
```

### Certificate Issues

```bash
# Check certificate expiry
sudo headscale-healthcheck | grep -i cert

# View Caddy certificate storage
sudo ls -la /var/lib/caddy/.local/share/caddy/certificates/

# Force certificate renewal (if needed)
sudo systemctl restart caddy
```

## Development & Testing

For development and testing with Multipass VMs, see [TESTING.md](TESTING.md).

## Version Pinning

**Default Configuration:** All dependencies are pinned to specific versions for security and reproducibility.

Edit `/etc/headscale/versions.conf` to change versions:

```bash
# Node.js LTS version for Headplane (exact version required)
NODE_VERSION="22.11.0"

# Node.js SHA256 checksum (for linux-x64)
NODE_SHA256="bb8e58863d5e8ab5c9ff45e4b5c9f95c78c1d8a3c7e4d1af4c4e8c1b8f7e3b3e"

# Headplane version (git tag from GitHub)
HEADPLANE_VERSION="v0.6.0"

# Headscale version (release version without 'v' prefix)
HEADSCALE_VERSION="0.23.0"
```

### Upgrading Pinned Versions

**Node.js:**
1. Find new version at https://nodejs.org/
2. Get SHA256 from https://nodejs.org/dist/v{VERSION}/SHASUMS256.txt
3. Update `NODE_VERSION` and `NODE_SHA256` in versions.conf
4. Run: `sudo /opt/install-headplane.sh`

**Headplane:**
1. Check releases at https://github.com/tale/headplane/tags
2. Update `HEADPLANE_VERSION` in versions.conf
3. Run: `sudo /opt/install-headplane.sh`

**Headscale:**
1. Check releases at https://github.com/juanfont/headscale/releases
2. Update `HEADSCALE_VERSION` in versions.conf
3. Run: `sudo /usr/local/bin/headscale-update`

**Caddy:**
Caddy is pinned via APT preferences. To upgrade:
1. Remove or update `/etc/apt/preferences.d/headscale-pinning`
2. Run: `sudo apt-get update && sudo apt-get install caddy`
3. Test thoroughly
4. Re-add APT pinning if desired

### Security Benefits

- ✅ Prevents unexpected breaking changes
- ✅ Reproducible deployments
- ✅ SHA256 verification for Node.js downloads
- ✅ Checksum verification for Headscale downloads
- ✅ APT pinning prevents Caddy auto-upgrades

## Backup & Recovery

### Critical Files to Backup

```bash
# Configuration
/etc/environment.d/headscale.conf
/etc/headscale/config.yaml
/etc/headplane/config.yaml

# Secrets
/var/lib/headscale/oidc_client_secret
/var/lib/headscale/api_key
/etc/msmtp-password

# Database
/var/lib/headscale/db.sqlite

# DERP keys
/var/lib/headscale/derp_private.key
/var/lib/headscale/noise_private.key
```

### Backup Script Example

```bash
#!/bin/bash
BACKUP_DIR="/backup/headscale-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup database
sqlite3 /var/lib/headscale/db.sqlite ".backup '$BACKUP_DIR/db.sqlite'"

# Backup configs and secrets
tar -czf "$BACKUP_DIR/config.tar.gz" \
  /etc/environment.d/headscale.conf \
  /etc/headscale/config.yaml \
  /etc/headplane/config.yaml \
  /var/lib/headscale/oidc_client_secret \
  /var/lib/headscale/api_key \
  /var/lib/headscale/*_private.key \
  /etc/msmtp-password
```

## Contributing

This project follows a technical debt reduction plan with 6 phases:
- ✅ Phase 1: Critical Security Fixes
- ✅ Phase 2: Testing Infrastructure
- ⏳ Phase 3: Secrets Management (systemd-creds)
- ⏳ Phase 4: Dependency Pinning
- ✅ Phase 5: Code Organization (in progress)
- ⏳ Phase 6: Documentation & Validation

See `C:\Users\smart\.claude\plans\joyful-wondering-lemon.md` for the complete plan.

## License

This configuration is provided as-is for self-hosting Headscale. Headscale and Headplane are separate projects with their own licenses.

## References

- [Headscale Documentation](https://headscale.net/)
- [Headplane Documentation](https://github.com/tale/headplane)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Azure AD OIDC Documentation](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
