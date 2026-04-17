#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Install the mm CLI wrapper to ~/bin/mm
#
# Usage:
#   ./install.sh              # install mm + mmctl
#   SKIP_MMCTL=1 ./install.sh # install mm only (mmctl already installed)
#
# What it does:
#   1. Copies mm and refresh-token.py to ~/bin/
#   2. (Optional) Downloads mmctl from official Mattermost releases
#   3. Tells you to run: mm setup
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/bin}"

echo ""
echo "Installing mm → ${INSTALL_DIR}/"
echo ""

mkdir -p "$INSTALL_DIR"

# Install mm wrapper
cp "${SCRIPT_DIR}/mm" "${INSTALL_DIR}/mm"
chmod +x "${INSTALL_DIR}/mm"
echo "  ✓ ${INSTALL_DIR}/mm"

# Install refresh script alongside
cp "${SCRIPT_DIR}/refresh-token.py" "${INSTALL_DIR}/refresh-token.py"
chmod +x "${INSTALL_DIR}/refresh-token.py"
echo "  ✓ ${INSTALL_DIR}/refresh-token.py"

# Install mmctl (unless skipped or already present)
if [[ "${SKIP_MMCTL:-}" == "1" ]]; then
  echo "  • Skipping mmctl install (SKIP_MMCTL=1)"
elif command -v mmctl >/dev/null 2>&1 || [[ -x "${INSTALL_DIR}/mmctl" ]]; then
  echo "  • mmctl already installed — skipping"
else
  echo ""
  echo "  mmctl is not installed. Options:"
  echo "    • brew install mmctl"
  echo "    • Or download from: https://releases.mattermost.com/mmctl/\${VERSION}/\${PLATFORM}_\${ARCH}.tar"
  echo ""
  read -rp "  Install mmctl via brew? [y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    brew install mmctl
  else
    echo "  • Skipped. Install mmctl before running mm setup."
  fi
fi

# PATH check
if ! echo ":$PATH:" | grep -q ":${INSTALL_DIR}:"; then
  echo ""
  echo "  ⚠ ${INSTALL_DIR} is not in your PATH. Add to ~/.zshrc:"
  echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

echo ""
echo "  Done! Now run:"
echo "    mm setup"
echo ""
