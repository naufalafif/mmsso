#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Install mmsso (mmsso + cookie-reader) to ~/bin/
#
# Usage:
#   ./install.sh              # build from source + install
#   SKIP_MMCTL=1 ./install.sh # skip mmctl install prompt
#
# What it does:
#   1. Compiles cookie-reader from Swift source (macOS only)
#   2. Copies mmsso and cookie-reader to ~/bin/
#   3. Tells you to run: mm setup
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/bin}"

echo ""
echo "Installing mmsso → ${INSTALL_DIR}/"
echo ""

mkdir -p "$INSTALL_DIR"

# Build cookie-reader from Swift source (macOS)
if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v swiftc >/dev/null 2>&1; then
    echo "  ▸ Compiling cookie-reader ..."
    cd "$SCRIPT_DIR"
    make build 2>&1 | sed 's/^/    /'
    cp cookie-reader "${INSTALL_DIR}/cookie-reader"
    chmod +x "${INSTALL_DIR}/cookie-reader"
    echo "  ✓ ${INSTALL_DIR}/cookie-reader"
  else
    echo "  ! swiftc not found — skipping cookie-reader."
    echo "    Install Xcode Command Line Tools: xcode-select --install"
    echo "    Without it, mmsso falls back to Python/pycookiecheat."
  fi
else
  echo "  • cookie-reader requires macOS (Keychain). Python fallback will be used on Linux."
fi

# Install mmsso wrapper
cp "${SCRIPT_DIR}/mmsso" "${INSTALL_DIR}/mmsso"
chmod +x "${INSTALL_DIR}/mmsso"
echo "  ✓ ${INSTALL_DIR}/mmsso"

# Install Python fallback
cp "${SCRIPT_DIR}/refresh-token.py" "${INSTALL_DIR}/refresh-token.py"
chmod +x "${INSTALL_DIR}/refresh-token.py"
echo "  ✓ ${INSTALL_DIR}/refresh-token.py (Python fallback)"

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
    echo "  • Skipped. Install mmctl before running mmsso setup."
  fi
fi

# PATH check
if ! echo ":$PATH:" | grep -q ":${INSTALL_DIR}:"; then
  echo ""
  echo "  ⚠ ${INSTALL_DIR} is not in your PATH. Add to your shell rc:"
  echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

echo ""
echo "  Done! Now run:"
echo "    mmsso setup"
echo ""
