#!/usr/bin/env bash
#
# Remove mmctl binary, auth config, and session token.
# Does NOT remove any data on the Mattermost server.
#
set -euo pipefail

echo "About to remove:"
[[ -f "${HOME}/bin/mmsso" ]]              && echo "  - ~/bin/mmsso"
[[ -f "${HOME}/bin/refresh-token.py" ]] && echo "  - ~/bin/refresh-token.py"
[[ -f "${HOME}/bin/mmssoctl" ]]           && echo "  - ~/bin/mmssoctl"
[[ -d "${HOME}/.config/mm" ]]          && echo "  - ~/.config/mmsso/ (config + token + venv)"
[[ -d "${HOME}/.config/mmctl" ]]       && echo "  - ~/.config/mmssoctl/ (legacy config)"

found=false
for f in "${HOME}/bin/mmsso" "${HOME}/bin/refresh-token.py" "${HOME}/bin/mmssoctl"; do
  [[ -f "$f" ]] && found=true
done
[[ -d "${HOME}/.config/mm" || -d "${HOME}/.config/mmctl" ]] && found=true

if [[ "$found" != "true" ]]; then
  echo "Nothing to remove."
  exit 0
fi

read -rp "Proceed? [y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

rm -f "${HOME}/bin/mmsso" "${HOME}/bin/refresh-token.py" "${HOME}/bin/mmssoctl"
rm -rf "${HOME}/.config/mm" "${HOME}/.config/mmctl"
echo "Done."
