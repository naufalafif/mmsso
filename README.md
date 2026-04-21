# mmsso

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black)](https://www.apple.com/macos/)

Use `mmctl` with SSO — no Personal Access Token needed.

`mmctl` doesn't support SSO login. If your Mattermost server enforces SSO, you're stuck. `mmsso` fixes that by reusing your existing Chrome session, so you can use `mmctl` without asking IT for a PAT.

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
mmsso setup
```

This interactively configures your server URL, compiles the cookie reader (if needed), and tests the connection.

## Prerequisites

- **macOS**
- **Google Chrome** with an active Mattermost login (SSO)
- **mmctl** — `brew install mmctl` or [download from Mattermost](https://releases.mattermost.com/mmctl/)
- **Swift 5.9+** for building `cookie-reader` from source (included with Xcode Command Line Tools)

## Usage

```bash
mmsso team list --json
mmsso channel list <team> --json
mmsso post list <channel-id> --json --show-ids -n 100
mmsso post list <team>:<channel> --json --since 2026-04-10T00:00:00Z
mmsso user search <user-id-or-username> --json
```

### Commands

| Command | Description |
|---------|-------------|
| `mmsso setup` | Interactive first-time setup |
| `mmsso status` | Show auth status, token age, server info |
| `mmsso refresh` | Force-refresh the token from Chrome |
| `mmsso search <terms>` | Full-text search across channels you have access to |
| `mmsso dms` | List your direct message channels |
| `mmsso dm <username>` | Read messages from a DM channel |
| `mmsso help` | Show help |
| `mmsso <anything>` | Auto-refresh + passthrough to mmctl |

`search`, `dms`, and `dm` hit the Mattermost REST API directly — mmctl doesn't expose those endpoints, but the session token authenticates them fine.

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
        │  You run: mmsso team list     │
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
        │  ~/.config/mmsso/token        │
        │  → mmctl runs your command │
        └────────────────────────────┘
```

### Why it needs Keychain access

Chrome encrypts cookies with a key stored in the macOS Keychain. To decrypt your session token, `cookie-reader` needs to read that key. The first time you run it, macOS will show a prompt:

> "cookie-reader" wants to use your confidential information stored in "Chrome Safe Storage" in your keychain.

Click **Always Allow**. This grants access only to the `cookie-reader` binary — not your terminal, not other apps. The permission is scoped to this specific binary's code signature.

### No cron, no background process

Token refresh happens lazily — only when you run an `mmsso` command and the current token is older than 1 hour. There's no daemon, no cron job, no polling. As long as you have an active Mattermost session in Chrome (a tab open or recently visited), `mmsso` handles everything automatically.

## When It Breaks

If you get auth errors, Chrome doesn't have a valid Mattermost session:

1. Open your Mattermost server in Chrome
2. Let SSO log you in
3. Run `mmsso refresh`

## Configuration

All config stored in `~/.config/mmsso/`:

| File | Purpose |
|------|---------|
| `config` | Server URL + auth name |
| `token` | Session token (auto-managed, chmod 600) |

## Limitations

- **Reactions, file downloads, pinned-post listings** — not exposed by `mmctl` or the extended commands. Possible to add later by hitting more REST API endpoints.

## Use with Claude Code

The repo includes a [Claude Code](https://claude.com/claude-code) skill that teaches Claude how to drive `mmsso` effectively — summarizing channels, reconstructing threads, resolving user IDs, etc.

Install the skill:

```bash
mkdir -p ~/.claude/skills/mmsso
cp claude-skill/SKILL.md ~/.claude/skills/mmsso/SKILL.md
```

Then in Claude Code, just mention Mattermost naturally:

> *"Summarize the last 24h in #engineering-bulletin"*
> *"Who sent post ID xxx?"*
> *"Show me threads from yesterday in the incidents channel"*

Claude auto-invokes the skill, runs the right `mmsso` commands, and resolves IDs to usernames before reporting.

## Uninstall

```bash
make uninstall        # removes from ~/bin
rm -rf ~/.config/mmsso   # removes config + token
```

Or via Homebrew: `brew uninstall mmsso`

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[MIT](LICENSE)
