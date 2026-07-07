#!/bin/bash
# =============================================================================
# EduXal — Linux Uninstall Script
# =============================================================================
# Reverses the installation performed by install.sh:
#   - Removes /opt/eduxal
#   - Removes the /usr/local/bin/eduxal symlink
#   - Removes the .desktop file from /usr/share/applications
#
# Usage:
#   ./uninstall.sh          (will prompt for sudo if not root)
#   sudo ./uninstall.sh
# =============================================================================

set -e

INSTALL_DIR="/opt/eduxal"
BIN_LINK="/usr/local/bin/eduxal"
DESKTOP_FILE="/usr/share/applications/com.example.eduxal.desktop"
ICON_FILE="/usr/share/icons/hicolor/256x256/apps/com.example.eduxal.png"


# ---------------------------------------------------------------------------
# Ensure we are running as root; re-exec with sudo if not.
# ---------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Root privileges required. Re-running with sudo..."
    exec sudo "$0" "$@"
fi

echo "Uninstalling EduXal..."

# ---------------------------------------------------------------------------
# 1. Remove the application directory
# ---------------------------------------------------------------------------
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "  ✓ Removed $INSTALL_DIR"
else
    echo "  • $INSTALL_DIR not found (skipped)"
fi

# ---------------------------------------------------------------------------
# 2. Remove the symlink in /usr/local/bin
# ---------------------------------------------------------------------------
if [ -L "$BIN_LINK" ] || [ -e "$BIN_LINK" ]; then
    rm -f "$BIN_LINK"
    echo "  ✓ Removed $BIN_LINK"
else
    echo "  • $BIN_LINK not found (skipped)"
fi

# ---------------------------------------------------------------------------
# 3. Remove the .desktop entry
# ---------------------------------------------------------------------------
if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
    echo "  ✓ Removed $DESKTOP_FILE"
else
    echo "  • $DESKTOP_FILE not found (skipped)"
fi

# Remove icon file from hicolor theme
if [ -f "$ICON_FILE" ]; then
    rm -f "$ICON_FILE"
    echo "  ✓ Removed icon $ICON_FILE"
else
    echo "  • $ICON_FILE not found (skipped)"
fi

# ---------------------------------------------------------------------------
# 4. Refresh the icon cache (best-effort)
# ---------------------------------------------------------------------------
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

echo ""
echo "EduXal has been successfully uninstalled."
