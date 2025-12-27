#!/bin/bash
# secrets.sh - Shared secret management functions for Headscale VPS
# Provides systemd-creds encryption with graceful degradation

# Load constants (if available, skip if already loaded to avoid readonly errors)
if [ -z "$SYSTEMD_MIN_VERSION" ] && [ -f /etc/headscale/constants.conf ]; then
  source /etc/headscale/constants.conf
fi

# Local constants
readonly CREDSTORE_DIR="/etc/credstore.encrypted"

# Check if systemd supports credential encryption
# Returns: 0 if supported, 1 if not
check_systemd_creds_support() {
  # Check if systemd-creds command exists
  if ! command -v systemd-creds >/dev/null 2>&1; then
    return 1
  fi

  # Check systemd version (need 250+)
  local systemd_version
  systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')

  if [ -z "$systemd_version" ]; then
    return 1
  fi

  if [ "$systemd_version" -lt "$SYSTEMD_MIN_VERSION" ]; then
    return 1
  fi

  return 0
}

# Encrypt a secret file using systemd-creds (if supported)
# Args:
#   $1 - Path to plaintext secret file
#   $2 - Credential name (used in systemd service files)
# Returns: 0 on success or graceful fallback, 1 on error
encrypt_secret_if_supported() {
  local plain_file="$1"
  local cred_name="$2"
  local encrypted_file="$CREDSTORE_DIR/${cred_name}.cred"

  # Validate inputs
  if [ -z "$plain_file" ] || [ -z "$cred_name" ]; then
    echo "Error: encrypt_secret_if_supported() requires 2 arguments" >&2
    return 1
  fi

  if [ ! -f "$plain_file" ]; then
    echo "Error: Secret file not found: $plain_file" >&2
    return 1
  fi

  # Check if systemd-creds is supported
  if ! check_systemd_creds_support; then
    # Graceful degradation - use plaintext with 600 permissions
    chmod 600 "$plain_file"
    return 0
  fi

  # Create credstore directory if it doesn't exist
  mkdir -p "$CREDSTORE_DIR"
  chmod 700 "$CREDSTORE_DIR"

  # Encrypt the secret
  local encrypt_output encrypt_error
  encrypt_output=$(systemd-creds encrypt --name="$cred_name" "$plain_file" "$encrypted_file" 2>&1)
  encrypt_error=$?

  if [ $encrypt_error -eq 0 ]; then
    chmod 600 "$encrypted_file"

    # Use print_success if available (from headscale-common.sh)
    if command -v print_success >/dev/null 2>&1; then
      print_success "Encrypted $cred_name using systemd-creds"
    else
      echo "[OK] Encrypted $cred_name using systemd-creds"
    fi

    return 0
  else
    # Encryption failed - fall back to plaintext
    if command -v print_warning >/dev/null 2>&1; then
      print_warning "Failed to encrypt $cred_name, using plaintext"
    else
      echo "[WARNING] Failed to encrypt $cred_name, using plaintext"
    fi

    if [ -n "$encrypt_output" ]; then
      echo "  Error details: $encrypt_output" >&2
    fi

    chmod 600 "$plain_file"
    return 0
  fi
}

# Get systemd version (for debugging/info purposes)
get_systemd_version() {
  systemctl --version | head -n1 | awk '{print $2}'
}