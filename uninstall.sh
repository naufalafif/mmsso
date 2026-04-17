#!/usr/bin/env bash
#
# Remove mmctl binary, auth config, and session token.
# Does NOT remove any data on the Mattermost server.
#
set -euo pipefail

echo "About to remove:"
[[ -f "${HOME}/bin/mm" ]]              && echo "  - ~/bin/mm"
[[ -f "${HOME}/bin/refresh-token.py" ]] && echo "  - ~/bin/refresh-token.py"
[[ -f "${HOME}/bin/mmctl" ]]           && echo "  - ~/bin/mmctl"
[[ -d "${HOME}/.config/mm" ]]          && echo "  - ~/.config/mm/ (config + token + venv)"
[[ -d "${HOME}/.config/mmctl" ]]       && echo "  - ~/.config/mmctl/ (legacy config)"

found=false
for f in "${HOME}/bin/mm" "${HOME}/bin/refresh-token.py" "${HOME}/bin/mmctl"; do
  [[ -f "$f" ]] && found=true
done
[[ -d "${HOME}/.config/mm" || -d "${HOME}/.config/mmctl" ]] && found=true

if [[ "$found" != "true" ]]; then
  echo "Nothing to remove."
  exit 0
fi

read -rp "Proceed? [y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

rm -f "${HOME}/bin/mm" "${HOME}/bin/refresh-token.py" "${HOME}/bin/mmctl"
rm -rf "${HOME}/.config/mm" "${HOME}/.config/mmctl"
echo "Done."
