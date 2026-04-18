#!/usr/bin/env bash
#
# Remove mmsso + cookie-reader + config.
# Does NOT remove mmctl itself, and does NOT touch Mattermost server data.
#
set -euo pipefail

echo "About to remove:"
[[ -f "${HOME}/bin/mmsso" ]]         && echo "  - ~/bin/mmsso"
[[ -f "${HOME}/bin/cookie-reader" ]] && echo "  - ~/bin/cookie-reader"
[[ -d "${HOME}/.config/mmsso" ]]     && echo "  - ~/.config/mmsso/ (config + token)"

found=false
[[ -f "${HOME}/bin/mmsso" ]]         && found=true
[[ -f "${HOME}/bin/cookie-reader" ]] && found=true
[[ -d "${HOME}/.config/mmsso" ]]     && found=true

if [[ "$found" != "true" ]]; then
  echo "Nothing to remove."
  exit 0
fi

read -rp "Proceed? [y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

rm -f "${HOME}/bin/mmsso" "${HOME}/bin/cookie-reader"
rm -rf "${HOME}/.config/mmsso"
echo "Done."
echo ""
echo "Note: if installed via Homebrew, run 'brew uninstall mmsso' instead."
