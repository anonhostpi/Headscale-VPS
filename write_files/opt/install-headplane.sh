#!/bin/bash
set -e

echo "=========================================="
echo "  Installing Headplane (Native Mode)"
echo "=========================================="

# Load version configuration
source /etc/headscale/versions.conf
NODE_VERSION="${NODE_VERSION:-22}"
HEADPLANE_VERSION="${HEADPLANE_VERSION:-}"

# Install nvm (Node Version Manager) system-wide
echo "[1/6] Installing nvm..."
export NVM_DIR="/opt/nvm"
mkdir -p "$NVM_DIR"

# Download NVM with checksum verification (prevents supply chain attacks)
# NVM_VERSION and NVM_SHA256 loaded from versions.conf
NVM_INSTALL_SCRIPT="/tmp/nvm-install-${NVM_VERSION}.sh"

curl -sSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o "$NVM_INSTALL_SCRIPT"

# Verify checksum
echo "${NVM_SHA256}  ${NVM_INSTALL_SCRIPT}" | sha256sum -c - || {
  echo "ERROR: NVM install script checksum verification failed!"
  rm -f "$NVM_INSTALL_SCRIPT"
  exit 1
}

# Execute verified script
bash "$NVM_INSTALL_SCRIPT"
rm -f "$NVM_INSTALL_SCRIPT"

# Load nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Install Node.js with SHA256 verification
echo "[2/6] Installing Node.js ${NODE_VERSION}..."

# Download Node.js binary
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then
  NODE_ARCH="x64"
elif [ "$ARCH" = "aarch64" ]; then
  NODE_ARCH="arm64"
else
  echo "ERROR: Unsupported architecture: $ARCH"
  exit 1
fi

NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
NODE_TARBALL="/tmp/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"

# Download Node.js
curl -sSL "$NODE_URL" -o "$NODE_TARBALL"

# Verify SHA256 checksum (only if NODE_SHA256 is set)
if [ -n "${NODE_SHA256:-}" ]; then
  echo "Verifying Node.js checksum..."
  echo "${NODE_SHA256}  ${NODE_TARBALL}" | sha256sum -c - || {
    echo "ERROR: Node.js checksum verification failed!"
    echo "Expected: ${NODE_SHA256}"
    echo "Got: $(sha256sum ${NODE_TARBALL} | awk '{print $1}')"
    rm -f "$NODE_TARBALL"
    exit 1
  }
  echo "✓ Node.js checksum verified"
else
  echo "WARNING: NODE_SHA256 not set, skipping checksum verification"
fi

# Install via nvm using the verified tarball
nvm install "${NODE_VERSION}"
nvm use "${NODE_VERSION}"
nvm alias default "${NODE_VERSION}"

# Cleanup
rm -f "$NODE_TARBALL"

# Create symlinks for system-wide access
ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/node" /usr/local/bin/node
ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/npm" /usr/local/bin/npm
ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/npx" /usr/local/bin/npx

# Install pnpm
echo "[3/6] Installing pnpm..."
npm install -g pnpm
ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/pnpm" /usr/local/bin/pnpm

# Clone Headplane
echo "[4/6] Cloning Headplane..."
cd /opt
if [ -d headplane ] && [ -d headplane/.git ]; then
  cd headplane
  git fetch --all --tags
else
  rm -rf headplane  # Clean up any broken directory
  git clone https://github.com/tale/headplane.git
  cd headplane
fi

# Checkout version (configured or latest tag)
if [ -n "$HEADPLANE_VERSION" ]; then
  TARGET_VERSION="$HEADPLANE_VERSION"
else
  TARGET_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")
fi
echo "    Using version: ${TARGET_VERSION}"
git checkout "${TARGET_VERSION}"

# Install dependencies and build
echo "[5/6] Building Headplane..."
pnpm install

# Build WASM module for SSH functionality (required for v0.6.1+)
echo "    Building hp_ssh.wasm..."
export GOPATH=/tmp/go
export GOMODCACHE=/tmp/go/pkg/mod
export GOCACHE=/tmp/go/cache
cat "$(go env GOROOT)/lib/wasm/wasm_exec.js" >> app/wasm_exec.js
GOOS=js GOARCH=wasm go build -o app/hp_ssh.wasm ./cmd/hp_ssh

# Build Node.js application
echo "    Building Node.js application..."
pnpm build

# Set ownership
echo "[6/6] Setting permissions..."
chown -R headscale:headscale /opt/headplane

echo ""
echo "=========================================="
echo "  Headplane Installation Complete"
echo "=========================================="
echo ""
echo "  To start Headplane:"
echo "    sudo systemctl enable headplane"
echo "    sudo systemctl start headplane"
echo ""