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
- **Secure Keychain access** — compiled Swift binary for cookie reading; macOS Keychain permission scopes to `cookie-reader` specifically, not your terminal app

## Install

### Homebrew (recommended)

```bash
brew tap naufalafif/tap
brew install mmsso
```

### From source

Requires Swift 5.9+ (Xcode Command Line Tools) and `mmctl`.

```bash
git clone https://github.com/naufalafif/mmsso.git
cd mmsso
make build
make install          # installs to ~/bin by default
# make install PREFIX=/usr/local  # or install system-wide
```

### First-time setup

```bash
mm setup
```

This interactively configures your server URL, compiles the cookie reader (if needed), and tests the connection.

## Prerequisites

- **macOS** (primary) or **Linux** (Python fallback for cookie reading)
- **Google Chrome** with an active Mattermost login (SSO)
- **mmctl** — `brew install mmctl` or [download from Mattermost](https://releases.mattermost.com/mmctl/)
- **Swift 5.9+** for building `cookie-reader` from source (macOS only; included with Xcode CLI Tools)

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

When you log into Mattermost via SSO in Chrome, Chrome stores your session token in a cookie called `MMAUTHTOKEN`. Chrome encrypts all cookies before saving them to disk, and the encryption key lives in the macOS Keychain under "Chrome Safe Storage".

`mmsso` reads that encrypted cookie and decrypts it so `mmctl` can use it:

```
┌─────────────────────────────────────────────────┐
│  You log into Mattermost via SSO in Chrome      │
│  → Chrome saves MMAUTHTOKEN cookie (encrypted)  │
│  → Encryption key stored in macOS Keychain       │
└─────────────────────┬───────────────────────────┘
                      │
        ┌─────────────▼──────────────┐
        │  You run: mm team list     │
        └─────────────┬──────────────┘
                      │
        ┌─────────────▼──────────────┐
        │  cookie-reader (Swift)     │
        │  1. Reads encryption key   │
        │     from macOS Keychain    │
        │  2. Opens Chrome's cookie  │
        │     database (SQLite)      │
        │  3. Decrypts the cookie    │
        └─────────────┬──────────────┘
                      │
        ┌─────────────▼──────────────┐
        │  Token written to          │
        │  ~/.config/mm/token        │
        │  → mmctl runs your command │
        └────────────────────────────┘
```

### Why it needs Keychain access

Chrome encrypts cookies with a key stored in the macOS Keychain. To decrypt your session token, `cookie-reader` needs to read that key. The first time you run it, macOS will show a prompt:

> "cookie-reader" wants to use your confidential information stored in "Chrome Safe Storage" in your keychain.

Click **Always Allow**. This grants access only to the `cookie-reader` binary — not your terminal, not other apps. The permission is scoped to this specific binary's code signature.

### No cron, no background process

Token refresh happens lazily — only when you run an `mm` command and the current token is older than 1 hour. There's no daemon, no cron job, no polling. As long as you have an active Mattermost session in Chrome (a tab open or recently visited), `mm` handles everything automatically.

On Linux, a Python fallback using [pycookiecheat](https://github.com/n8henrie/pycookiecheat) is available (auto-managed venv, no manual setup).

## When It Breaks

If you get auth errors, Chrome doesn't have a valid Mattermost session:

1. Open your Mattermost server in Chrome
2. Let SSO log you in
3. Run `mm refresh`

## Configuration

All config stored in `~/.config/mm/`:

| File | Purpose |
|------|---------|
| `config` | Server URL + auth name |
| `token` | Session token (auto-managed, chmod 600) |
| `.venv/` | Python venv for fallback (auto-managed) |

## Limitations

- **DMs** — `mmctl` has no command to read direct messages
- **Full-text search** — not exposed by `mmctl`

Both require a Personal Access Token + direct REST API access.

## Uninstall

```bash
make uninstall        # removes from ~/bin
rm -rf ~/.config/mm   # removes config + token
```

Or via Homebrew: `brew uninstall mmsso`

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
