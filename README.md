# mmsso

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-supported-green)]()

A drop-in wrapper around [mmctl](https://docs.mattermost.com/administration-guide/manage/mmctl-command-line-tool.html) that **automatically refreshes SSO session tokens** from Chrome's cookie store. No passwords, no Personal Access Tokens, no manual DevTools copy-paste.

Works with **any self-hosted Mattermost server** that uses SSO/OAuth/SAML authentication.

## Overview

If your Mattermost server enforces SSO, `mmctl` can't log in directly — it only supports username/password or PATs. `mmsso` solves this by reading your active browser session from Chrome's encrypted cookie database on disk, so you never have to touch DevTools or clipboard again.

- **Auto-refresh** — token is refreshed transparently before each command if stale (>1 hour)
- **Zero manual steps** — as long as you have an active Mattermost session in Chrome
- **Drop-in replacement** — all `mmctl` commands work: `mm team list`, `mm post list`, etc.
- **Interactive setup** — `mm setup` guides you through first-time configuration

## Install

```bash
git clone https://github.com/naufalafif/mmsso.git
cd mmsso
./install.sh
```

This copies `mm` and `refresh-token.py` to `~/bin/`. If `mmctl` isn't installed, the script offers to install it via Homebrew.

Then run the interactive setup:

```bash
mm setup
```

### Prerequisites

- **macOS** or **Linux**
- **Google Chrome** with an active Mattermost login (SSO)
- **Python 3** (venv is auto-managed on first run)
- **mmctl** — `brew install mmctl` or [download from Mattermost](https://releases.mattermost.com/mmctl/)

## Usage

```bash
mm team list --json
mm channel list <team> --json
mm post list <channel-id> --json --show-ids -n 100
mm post list <team>:<channel> --json --since 2026-04-10T00:00:00Z
mm user search <user-id-or-username> --json
```

### Commands

| Command | Description |
|---------|-------------|
| `mm setup` | Interactive first-time setup |
| `mm status` | Show auth status, token age, server info |
| `mm refresh` | Force-refresh the token from Chrome |
| `mm help` | Show help |
| `mm <anything>` | Auto-refresh + passthrough to mmctl |

## How It Works

```
Chrome (SSO login) → encrypted cookie DB on disk
                           ↓
                     pycookiecheat (decrypts via Keychain)
                           ↓
                     ~/.config/mm/token
                           ↓
                     mmctl (authenticated)
```

1. You log into Mattermost in Chrome via SSO (as usual)
2. `mm` reads the `MMAUTHTOKEN` cookie from Chrome's encrypted cookie store using [pycookiecheat](https://github.com/n8henrie/pycookiecheat)
3. Writes the token to `~/.config/mm/token` (chmod 600)
4. Passes through to `mmctl` with the fresh token

First run may prompt for macOS Keychain access to "Chrome Safe Storage" — click **Always Allow**.

## When It Breaks

If you get auth errors, it means Chrome doesn't have a valid Mattermost session:

1. Open your Mattermost server in Chrome
2. Let SSO log you in
3. Run `mm refresh`

## Configuration

All config is stored in `~/.config/mm/`:

| File | Purpose |
|------|---------|
| `config` | Server URL + auth name |
| `token` | Session token (auto-managed, chmod 600) |
| `.venv/` | Python venv (auto-managed) |

## Limitations

- **DMs** — `mmctl` has no command to read direct messages
- **Full-text search** — not exposed by `mmctl`

Both require a Personal Access Token + direct REST API access.

## Uninstall

```bash
./uninstall.sh
```

Or manually:

```bash
rm ~/bin/mm ~/bin/refresh-token.py
rm -rf ~/.config/mm
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
