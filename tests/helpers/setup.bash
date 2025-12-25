#!/usr/bin/env bash
# Test helper functions and setup for BATS tests

# Extract bash functions from cloud-init.yml for testing
# This allows us to test the embedded functions without deploying the full cloud-init

setup() {
  # Create temp directory for test artifacts
  export TEST_TEMP_DIR="$(mktemp -d)"

  # Extract validation functions from cloud-init.yml
  # We'll source them in individual tests
}

teardown() {
  # Clean up temp directory
  if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Helper function to extract and source functions from cloud-init.yml
source_cloud_init_functions() {
  local function_name="$1"

  # Extract the specific function from cloud-init.yml
  # This is a placeholder - in real tests we'd parse the YAML
  # For now, we'll define the functions directly for testing

  # Define validation functions for testing
  validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
      return 1
    fi
    return 0
  }

  validate_email() {
    local email="$1"
    # Note: This regex is too permissive (accepts user@@example.com)
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
      return 1
    fi
    return 0
  }

  validate_uuid() {
    local uuid="$1"
    # Accept both GUID format and *.onmicrosoft.com tenant names
    if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] && \
       [[ ! "$uuid" =~ ^[a-zA-Z0-9-]+\.onmicrosoft\.com$ ]]; then
      return 1
    fi
    return 0
  }
}

# Mock functions for testing
mock_systemctl() {
  # Mock systemctl for testing without actual system services
  case "$1" in
    is-active)
      return 0  # Pretend service is active
      ;;
    restart)
      return 0  # Pretend restart succeeded
      ;;
    *)
      return 0
      ;;
  esac
}

mock_curl() {
  # Mock curl for testing without network calls
  echo '{"tag_name": "v1.0.0"}'
}

mock_headscale() {
  # Mock headscale CLI for testing
  case "$1" in
    apikeys)
      if [ "$2" = "create" ]; then
        echo "test-api-key-12345"
      fi
      ;;
    *)
      return 0
      ;;
  esac
}
