#!/bin/bash
set -e

# Track setup progress for cleanup on failure
SETUP_STAGE="init"

cleanup_on_failure() {
  echo ""
  echo "========================================="
  echo "  Setup failed at stage: $SETUP_STAGE"
  echo "========================================="
  echo ""
  echo "Attempting to clean up partial installation..."
  
  case "$SETUP_STAGE" in
    firewall)
      ufw --force disable 2>/dev/null || true
      ;;
    caddy)
      apt-get remove -y caddy 2>/dev/null || true
      rm -f /etc/apt/sources.list.d/caddy-stable.list
      rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
      ;;
    headscale)
      dpkg --remove headscale 2>/dev/null || true
      ;;
  esac
  
  echo ""
  echo "Cleanup complete. Please check the error above and retry."
  echo "You may need to run 'apt-get update' before retrying."
  exit 1
}

trap cleanup_on_failure ERR

echo "=========================================="
echo "  Headscale + Headplane Setup"
echo "  Production-Ready Configuration"
echo "=========================================="

# Load version configuration if available
if [ -f /etc/headscale/versions.conf ]; then
  source /etc/headscale/versions.conf
fi

SETUP_STAGE="user"
# Create headscale user and group
echo "[1/8] Creating headscale user..."
if ! id -u headscale > /dev/null 2>&1; then
  useradd --system --home /var/lib/headscale --shell /usr/sbin/nologin headscale
fi

SETUP_STAGE="directories"
# Create directories
echo "[2/8] Creating directories..."
mkdir -p /var/lib/headscale
mkdir -p /var/lib/headplane
mkdir -p /etc/headscale/templates
mkdir -p /etc/headplane
mkdir -p /var/log/headscale
mkdir -p /var/log/caddy
mkdir -p /opt/headplane
mkdir -p /etc/environment.d

# Set ownership (headscale dirs only - caddy not installed yet)
chown -R headscale:headscale /var/lib/headscale
chown -R headscale:headscale /var/lib/headplane
chown -R headscale:headscale /etc/headplane
chown -R headscale:headscale /var/log/headscale

SETUP_STAGE="caddy"
# Install Caddy
echo "[3/8] Installing Caddy..."

# Download and verify Caddy GPG key fingerprint
CADDY_GPG_FINGERPRINT="65760C51EDEA2017CEA2CA15155B6D79CA56EA34"
TEMP_KEYRING="/tmp/caddy-keyring.gpg"

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  gpg --dearmor -o "$TEMP_KEYRING"

ACTUAL_FINGERPRINT=$(gpg --no-default-keyring --keyring "$TEMP_KEYRING" --list-keys --with-colons 2>/dev/null | \
  grep '^fpr' | head -1 | cut -d':' -f10)

if [ "$ACTUAL_FINGERPRINT" != "$CADDY_GPG_FINGERPRINT" ]; then
  echo "ERROR: Caddy GPG key fingerprint mismatch!"
  echo "  Expected: $CADDY_GPG_FINGERPRINT"
  echo "  Actual:   $ACTUAL_FINGERPRINT"
  rm -f "$TEMP_KEYRING"
  exit 1
fi

echo "    GPG fingerprint verified: OK"
mv "$TEMP_KEYRING" /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Set caddy log ownership (now that caddy user exists)
chown -R caddy:caddy /var/log/caddy

SETUP_STAGE="headscale"
# Install Headscale
echo "[4/8] Installing Headscale..."
if [ -n "$HEADSCALE_VERSION" ]; then
  HS_VERSION="$HEADSCALE_VERSION"
else
  HS_VERSION=$(curl -s https://api.github.com/repos/juanfont/headscale/releases/latest | jq -r '.tag_name' | sed 's/v//')
fi
echo "    Version: ${HS_VERSION}"

# Download with checksum verification
HS_DEB="headscale_${HS_VERSION}_linux_amd64.deb"
HS_URL="https://github.com/juanfont/headscale/releases/download/v${HS_VERSION}/${HS_DEB}"

wget -q "$HS_URL" -O /tmp/headscale.deb

# Fetch and verify checksum (optional - skip if checksums file doesn't exist)
CHECKSUMS_URL="https://github.com/juanfont/headscale/releases/download/v${HS_VERSION}/headscale_${HS_VERSION}_checksums.txt"
if wget -q "$CHECKSUMS_URL" -O /tmp/headscale_checksums.txt 2>/dev/null; then
  EXPECTED_CHECKSUM=$(grep "$HS_DEB" /tmp/headscale_checksums.txt 2>/dev/null | awk '{print $1}')
  if [ -n "$EXPECTED_CHECKSUM" ]; then
    echo "${EXPECTED_CHECKSUM}  /tmp/headscale.deb" | sha256sum -c - && {
      echo "    Checksum verified: OK"
    } || {
      echo "WARNING: Headscale checksum verification failed!"
      echo "Proceeding with installation anyway..."
    }
  else
    echo "    Checksum file found but $HS_DEB not listed - skipping verification"
  fi
  rm -f /tmp/headscale_checksums.txt
else
  echo "    Checksums file not available - skipping verification"
fi

# Install
dpkg -i /tmp/headscale.deb || apt-get install -f -y
rm /tmp/headscale.deb

# Symlink headscale binary if needed
if [ -f /usr/bin/headscale ] && [ ! -f /usr/local/bin/headscale ]; then
  ln -sf /usr/bin/headscale /usr/local/bin/headscale
fi

SETUP_STAGE="secrets"
# Generate secrets
echo "[5/8] Generating secrets..."

# Cookie secret for Headplane
openssl rand -base64 24 | tr -d '\n' > /var/lib/headplane/cookie_secret
chown headscale:headscale /var/lib/headplane/cookie_secret
chmod 600 /var/lib/headplane/cookie_secret

# Placeholder for OIDC client secret
touch /var/lib/headscale/oidc_client_secret
chown headscale:headscale /var/lib/headscale/oidc_client_secret
chmod 600 /var/lib/headscale/oidc_client_secret

SETUP_STAGE="firewall"
# Configure firewall
echo "[6/8] Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp    # HTTP (Caddy redirect)
ufw allow 443/tcp   # HTTPS (Caddy)
ufw allow 3478/udp  # STUN (DERP)
ufw --force enable

SETUP_STAGE="services"
# Enable services (but don't start yet - need configuration)
echo "[7/10] Enabling services..."
systemctl daemon-reload
systemctl enable headscale
systemctl enable caddy
systemctl enable fail2ban
systemctl enable headscale-healthcheck.timer

# Start fail2ban and health check timer (don't need configuration)
systemctl start fail2ban
systemctl start headscale-healthcheck.timer

SETUP_STAGE="hardening"
# Apply kernel hardening
echo "[8/10] Applying kernel hardening..."
sysctl --system

# Restart SSH with hardened config
echo "[9/10] Restarting SSH with hardened config..."
systemctl restart ssh

# Enable auditd
echo "[10/10] Enabling audit logging..."
systemctl enable auditd
systemctl start auditd

# Clear trap - setup successful
trap - ERR

# Final message
echo "Setup complete!"
echo ""
echo "=========================================="
echo "  Next Steps"
echo "=========================================="
echo ""
echo "  1. Run the configuration wizard:"
echo "     sudo headscale-config"
echo ""
echo "  2. Verify all services are running:"
echo "     systemctl status headscale headplane caddy"
echo ""
echo "  For Azure AD setup instructions, see:"
echo "     https://github.com/anonhostpi/Headscale-VPS/blob/main/AZURE_AD_SETUP.md"
echo ""