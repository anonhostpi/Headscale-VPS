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
