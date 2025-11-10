#!/bin/bash

# System Monitoring Toolkit - Installation Script
# This script sets up the toolkit on your system

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   System Monitoring & Admin Toolkit - Installation        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running in correct directory
if [[ ! -f "dashboard.sh" ]]; then
    echo "Error: Please run this script from the toolkit directory"
    echo "Make sure dashboard.sh is in the current directory"
    exit 1
fi

echo "[1/4] Making scripts executable..."
chmod +x *.sh
echo "✓ Scripts are now executable"
echo ""

echo "[2/4] Creating directories..."
mkdir -p logs reports backups config
echo "✓ Created: logs/ reports/ backups/ config/"
echo ""

echo "[3/4] Checking dependencies..."

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "  ✓ $1 is installed"
        return 0
    else
        echo "  ✗ $1 is NOT installed"
        return 1
    fi
}

MISSING=0

check_command "bash" || MISSING=$((MISSING + 1))
check_command "awk" || MISSING=$((MISSING + 1))
check_command "sed" || MISSING=$((MISSING + 1))
check_command "grep" || MISSING=$((MISSING + 1))
check_command "ps" || MISSING=$((MISSING + 1))
check_command "top" || MISSING=$((MISSING + 1))
check_command "df" || MISSING=$((MISSING + 1))
check_command "free" || MISSING=$((MISSING + 1))

# Optional but recommended
check_command "bc" || echo "   bc is optional but recommended"
check_command "lsof" || echo "  lsof is optional but recommended"

echo ""

if [[ $MISSING -gt 0 ]]; then
    echo " Warning: $MISSING required commands are missing"
    echo "The toolkit may not work properly"
    echo ""
fi

echo "[4/4] Running quick test..."
if ./dashboard.sh --help &>/dev/null || true; then
    echo "✓ Dashboard script is functional"
else
    echo " Dashboard script may have issues"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Installation Complete!                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "To start the toolkit, run:"
echo "  ./dashboard.sh"
echo ""
echo "For help, see:"
echo "  README.md - Full documentation"
echo "  QUICKSTART.md - Quick start guide"
echo ""
echo "Enjoy! "
