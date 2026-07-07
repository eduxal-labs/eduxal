#!/usr/bin/env bash
# =============================================================================
# EduXal — Linux Install Script
#
# Installs the EduXal application to /opt/eduxal, creates a symlink in
# /usr/local/bin for CLI access, and registers a .desktop entry so the app
# appears in application launchers.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh            # will prompt for sudo if not root
# =============================================================================

set -euo pipefail

INSTALL_DIR="/opt/eduxal"
BIN_LINK="/usr/local/bin/eduxal"
DESKTOP_TARGET="/usr/share/applications/com.example.eduxal.desktop"

# ---------------------------------------------------------------------------
# 1. Ensure we are running as root (re-exec with sudo if not)
# ---------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "This installer requires root privileges. Re-running with sudo..."
    exec sudo -- "$0" "$@"
fi

# ---------------------------------------------------------------------------
# 2. Resolve the directory where this script (and the tarball contents) live
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing EduXal from: $SCRIPT_DIR"
echo "Install directory:      $INSTALL_DIR"
echo ""

# ---------------------------------------------------------------------------
# 3. Create the install directory
# ---------------------------------------------------------------------------
echo ">> Creating install directory at $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# ---------------------------------------------------------------------------
# 4. Copy all files from the tarball directory to the install directory
# ---------------------------------------------------------------------------
echo ">> Copying application files ..."
cp -a "$SCRIPT_DIR"/. "$INSTALL_DIR/"

# ---------------------------------------------------------------------------
# 5. Create a symlink so `eduxal` is available on PATH
# ---------------------------------------------------------------------------
echo ">> Creating symlink $BIN_LINK -> $INSTALL_DIR/eduxal ..."
ln -sf "$INSTALL_DIR/eduxal" "$BIN_LINK"

# ---------------------------------------------------------------------------
# 6. Install the .desktop file with absolute paths
# ---------------------------------------------------------------------------
echo ">> Installing desktop entry to $DESKTOP_TARGET ..."

# Copy icon to hicolor icon theme so the system dock can display it natively
echo ">> Installing application icon ..."
if [[ -f "$SCRIPT_DIR/eduxal.png" ]]; then
    mkdir -p /usr/share/icons/hicolor/256x256/apps/
    cp "$SCRIPT_DIR/eduxal.png" /usr/share/icons/hicolor/256x256/apps/com.example.eduxal.png
fi

if [[ -f "$SCRIPT_DIR/com.example.eduxal.desktop" ]]; then
    cp "$SCRIPT_DIR/com.example.eduxal.desktop" "$DESKTOP_TARGET"
else
    echo "   Warning: com.example.eduxal.desktop not found in $SCRIPT_DIR, skipping desktop entry."
fi

# Update Exec and Icon lines
if [[ -f "$DESKTOP_TARGET" ]]; then
    sed -i "s|^Exec=.*|Exec=$INSTALL_DIR/eduxal|" "$DESKTOP_TARGET"
    sed -i "s|^Icon=.*|Icon=com.example.eduxal|" "$DESKTOP_TARGET"
fi

# ---------------------------------------------------------------------------
# 7. Refresh the icon cache (if the tool is available)
# ---------------------------------------------------------------------------
if command -v gtk-update-icon-cache &>/dev/null; then
    echo ">> Updating icon cache ..."
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Done!
# ---------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  EduXal installed successfully!"
echo ""
echo "  Launch from your application menu or run:"
echo "    eduxal"
echo "============================================="
