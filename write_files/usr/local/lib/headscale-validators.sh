#!/bin/bash
# validators.sh - Input validation functions for Headscale VPS

# Validate domain name format
validate_domain() {
  local domain="$1"
  [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]
}

# Validate email address format
# RFC 5322 compliant (simplified) - validates local@domain.tld format
validate_email() {
  local email="$1"
  # Pattern breakdown:
  # ^[a-zA-Z0-9._%+-]+  - Local part: alphanumeric, dots, underscores, percent, plus, hyphen
  # @                   - Single @ symbol
  # [a-zA-Z0-9.-]+      - Domain: alphanumeric, dots, hyphens
  # \.                  - Dot before TLD
  # [a-zA-Z]{2,}$       - TLD: at least 2 letters
  [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Validate UUID or Azure tenant ID
validate_uuid() {
  local uuid="$1"
  [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || \
  [[ "$uuid" =~ ^[a-zA-Z0-9-]+\.onmicrosoft\.com$ ]]
}