#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Install mmsso (+ cookie-reader on macOS) to ~/bin/
#
# Usage:
#   ./install.sh              # build from source + install
#   SKIP_MMCTL=1 ./install.sh # skip mmctl install prompt
#
# What it does:
#   macOS:
#     1. Compiles cookie-reader from Swift source
#     2. Installs mmsso + cookie-reader to ~/bin/
#   Linux:
#     1. Installs mmsso to ~/bin/ (static-token mode — use a PAT)
#   Then points you at: mmsso setup
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/bin}"
PLATFORM="$(uname -s)"

echo ""
echo "Installing mmsso → ${INSTALL_DIR}/"
echo ""

mkdir -p "$INSTALL_DIR"

case "$PLATFORM" in
  Darwin)
    if ! command -v swiftc >/dev/null 2>&1; then
      echo "  ! swiftc not found — install Xcode Command Line Tools:" >&2
      echo "    xcode-select --install" >&2
      exit 1
    fi
    echo "  ▸ Compiling cookie-reader (Swift, macOS) ..."
    cd "$SCRIPT_DIR"
    make build 2>&1 | sed 's/^/    /'
    cp cookie-reader "${INSTALL_DIR}/cookie-reader"
    chmod +x "${INSTALL_DIR}/cookie-reader"
    echo "  ✓ ${INSTALL_DIR}/cookie-reader"
    ;;
  Linux)
    echo "  • Linux detected — skipping cookie-reader (use a PAT in 'mmsso setup')"
    ;;
  *)
    echo "  ! Unsupported OS: $PLATFORM" >&2
    exit 1
    ;;
esac

# Install mmsso wrapper (both platforms)
cp "${SCRIPT_DIR}/mmsso" "${INSTALL_DIR}/mmsso"
chmod +x "${INSTALL_DIR}/mmsso"
echo "  ✓ ${INSTALL_DIR}/mmsso"

# Install mmctl (unless skipped or already present)
if [[ "${SKIP_MMCTL:-}" == "1" ]]; then
  echo "  • Skipping mmctl install (SKIP_MMCTL=1)"
elif command -v mmctl >/dev/null 2>&1 || [[ -x "${INSTALL_DIR}/mmctl" ]]; then
  echo "  • mmctl already installed — skipping"
else
  echo ""
  echo "  mmctl is not installed. Options:"
  if [[ "$PLATFORM" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    echo "    • brew install mmctl"
    echo ""
    read -rp "  Install mmctl via brew? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      brew install mmctl
    else
      echo "  • Skipped. Install mmctl before running mmsso setup."
    fi
  else
    ARCH_SUFFIX="$([ "$(uname -m)" = "aarch64" ] && echo arm64 || echo amd64)"
    URL="https://releases.mattermost.com/mmctl/v11.6.0/linux_${ARCH_SUFFIX}.tar"
    echo "    • Download: ${URL}"
    echo ""
    read -rp "  Download mmctl now? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      curl -fsSL "$URL" -o /tmp/mmctl.tar
      tar -xf /tmp/mmctl.tar -C /tmp
      mv /tmp/mmctl "${INSTALL_DIR}/mmctl"
      chmod +x "${INSTALL_DIR}/mmctl"
      rm -f /tmp/mmctl.tar
      echo "  ✓ ${INSTALL_DIR}/mmctl"
    else
      echo "  • Skipped. Install mmctl before running mmsso setup."
    fi
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
