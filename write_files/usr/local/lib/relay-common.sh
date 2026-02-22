#!/bin/bash
# common.sh - Shared utilities for Headscale VPS scripts
# Provides color definitions, logging functions, and banners

# Color definitions (used across multiple scripts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!!]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${NC}[INFO]${NC} $1"; }

# Banner printing
print_banner() {
  local title="$1"
  echo ""
  echo "=========================================="
  echo "  $title"
  echo "=========================================="
  echo ""
}