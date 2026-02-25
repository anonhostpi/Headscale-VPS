#!/bin/bash
set -e

echo "============================="
echo "  Installing yq"
echo "============================="

source /etc/relay-server/versions.conf

YQ_VERSION="${YQ_VERSION:-v4.44.6}"
YQ_SHA256="${YQ_SHA256:-}"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  YQ_ARCH="amd64" ;;
  aarch64) YQ_ARCH="arm64" ;;
  *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}"

echo "[1/3] Downloading yq ${YQ_VERSION}..."
wget -q "$YQ_URL" -O /tmp/yq

if [ -z "$YQ_SHA256" ] || [ "$YQ_SHA256" = "REPLACE_BEFORE_DEPLOY" ]; then
  echo "WARNING: No yq SHA256 checksum configured in versions.conf"
  echo "  Binary integrity cannot be verified. Set YQ_SHA256 before production deploy."
  if [ "$YQ_SHA256" = "REPLACE_BEFORE_DEPLOY" ]; then
    echo "ERROR: YQ_SHA256 has sentinel value -- update versions.conf with the real hash"
    rm -f /tmp/yq
    exit 1
  fi
else
  echo "${YQ_SHA256}  /tmp/yq" | sha256sum -c - || {
    echo "ERROR: yq checksum verification failed!"
    rm -f /tmp/yq; exit 1
  }
  echo "    Checksum verified: OK"
fi

echo "[2/3] Installing yq to /usr/local/bin/yq..."
install -m 0755 /tmp/yq /usr/local/bin/yq
rm -f /tmp/yq

echo "[3/3] Verifying installation..."
yq --version
echo ""
echo "yq installation complete."
