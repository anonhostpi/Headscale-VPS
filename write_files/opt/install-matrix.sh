#!/bin/bash
set -e

echo "=========================================="
echo "  Installing Matrix Homeserver (Conduit)"
echo "=========================================="

# Load version configuration
source /etc/relay-server/versions.conf

CONDUIT_VERSION="${CONDUIT_VERSION:-v0.5.0}"
CONDUIT_SHA256="${CONDUIT_SHA256:-}"

BINARY_URL="https://forgejo.ellis.link/continuwuation/continuwuity/releases/download/${CONDUIT_VERSION}/conduit-x86_64-unknown-linux-musl"

# Create conduit system user
echo "[1/5] Creating conduit user..."
if ! id -u conduit > /dev/null 2>&1; then
  useradd --system --home /var/lib/matrix-conduit --shell /usr/sbin/nologin conduit
fi

# Create data and log directories
echo "[2/5] Creating directories..."
mkdir -p /var/lib/matrix-conduit
mkdir -p /var/log/matrix-conduit
mkdir -p /etc/matrix-conduit
chown -R conduit:conduit /var/lib/matrix-conduit
chown -R conduit:conduit /var/log/matrix-conduit
chown -R conduit:conduit /etc/matrix-conduit

# Download Conduit binary with SHA256 verification
echo "[3/5] Downloading Conduit ${CONDUIT_VERSION}..."
wget -q "$BINARY_URL" -O /tmp/matrix-conduit

if [ -n "$CONDUIT_SHA256" ]; then
  echo "${CONDUIT_SHA256}  /tmp/matrix-conduit" | sha256sum -c - || {
    echo "ERROR: Conduit binary checksum verification failed!"
    rm -f /tmp/matrix-conduit
    exit 1
  }
  echo "    Checksum verified: OK"
fi
