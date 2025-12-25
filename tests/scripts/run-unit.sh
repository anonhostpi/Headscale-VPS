#!/bin/bash
# Test runner for unit tests
# Requires BATS to be installed: https://github.com/bats-core/bats-core

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests"

echo "=========================================="
echo "  Running Unit Tests"
echo "=========================================="
echo ""

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo "ERROR: BATS is not installed"
    echo ""
    echo "Install BATS:"
    echo "  git clone https://github.com/bats-core/bats-core.git"
    echo "  cd bats-core"
    echo "  sudo ./install.sh /usr/local"
    echo ""
    exit 1
fi

echo "BATS version: $(bats --version)"
echo "Project root: $PROJECT_ROOT"
echo "Tests directory: $TESTS_DIR"
echo ""

# Run unit tests
echo "Running validation tests..."
bats "$TESTS_DIR/unit/test_validation.bats"

echo ""
echo "=========================================="
echo "  ✓ All unit tests passed!"
echo "=========================================="
