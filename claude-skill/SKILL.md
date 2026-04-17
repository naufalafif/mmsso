---
name: mmsso
description: Interact with any Mattermost server via the mmsso/mmctl CLI — read channels, reconstruct threads, look up users, list teams, post messages. Use when the user mentions Mattermost, asks to summarize a channel, check recent messages, inspect a thread, find a user, or post via CLI. Also covers SSO token auth and the refresh procedure when the session expires.
---

# mmsso — Mattermost CLI with SSO

Drive a Mattermost server from the shell. Works with any Mattermost instance the user is authenticated against.

## Pre-flight checks (always run first)

```bash
# Prefer the auto-refreshing wrapper if available
command -v mmsso

# Or fall back to raw mmctl
command -v mmctl

# Verify auth
mmsso auth current   # or: mmctl auth current
```

**Prefer `mmsso` over `mmctl`** — `~/bin/mmsso` is a wrapper that auto-refreshes the SSO session token from Chrome's cookie store before each invocation (via `pycookiecheat`). It only refreshes if the token file is missing or older than 1 hour, so there's no overhead on repeat calls.

If `mmsso` isn't available, fall back to `mmctl` directly. If `auth current` returns 401, jump to **Token refresh** below.

Use the output of `mmsso auth current` to discover the server URL — never hard-code it. For the active team, use `mmsso team list --json` and let the user or context pick one.

## Core operations

### Teams & channels
```bash
mmctl team list --json
mmctl channel list <team-name> --json
mmctl channel search <query> --json     # searches channel names, not messages
```

### Read messages from a channel
Accepts either `team:channel-name` OR a bare 26-char channel ID. **IDs are preferred** — they're stable across renames.

```bash
# Last N messages with post IDs (IDs are needed for thread reconstruction)
mmctl post list <channel-id> --json --show-ids -n 100

# By team:channel
mmctl post list <team>:<channel> --json --show-ids -n 50

# Since a timestamp (ISO 8601, UTC)
mmctl post list <channel-id> --json --show-ids --since 2026-04-10T00:00:00Z
```

### Reconstruct a thread
mmctl has no `thread` subcommand, but `--json` output includes `root_id` on every post:

- `root_id == ""` → top-level message
- `root_id == <post-id>` → reply to that post

Fetch a window (`-n 500`) and group client-side by `root_id`. Top-level posts where `reply_count > 0` are thread starters.

### Look up a user
```bash
mmctl user search <user-id-or-username> --json
```
Useful for resolving the cryptic 26-char `user_id` field on each post.

### Post a message — **ALWAYS ask first**
```bash
mmctl post create <team>:<channel> --message "text"
```

Posting is visible to others and effectively irreversible. Never post without explicit confirmation in the chat. Don't post into a channel you haven't verified is the intended target.

### Find a channel ID
1. Web UI: open channel → channel name header → **View Info** → Channel ID.
2. Or list all on a team: `mmctl channel list <team> --json` and grep by `name` or `display_name`.
3. Or from a URL: `https://<server>/<team>/channels/<channel-name>` — resolve the name to ID via option 2.

## Token refresh (session expired)

If using the `mmsso` wrapper, token refresh is automatic — it reads Chrome's cookie store on disk. Just run `mmsso refresh` or let it auto-refresh on the next command.

If the auto-refresh fails (no active Chrome session), tell the user:
1. Open the Mattermost server URL in Chrome
2. Let SSO log you in
3. Run `mmsso refresh`

For manual/raw mmctl setups without the `mmsso` wrapper:
1. Open Chrome DevTools: **Cmd+Opt+I** → **Application** → **Storage → Cookies → `https://<mattermost-server>`**
2. Find cookie **`MMAUTHTOKEN`** → double-click the **Value** → **Cmd+A, Cmd+C**
3. `pbpaste > ~/.config/mmsso/token && chmod 600 ~/.config/mmsso/token`

## If mmctl is missing

Tell the user and stop. Don't auto-install — setup needs the user to grab an SSO token from the browser, which they must do manually. Point them at the official source: `https://releases.mattermost.com/mmctl/${VERSION}/${PLATFORM}_${ARCH}.tar` (the old `github.com/mattermost/mmctl` repo is archived).

Note: version sub-command takes no dashes — `mmctl version` works, `mmctl --version` errors.

## Parsing tips

- Always pass `--json` for programmatic output. Default output is human-formatted and unstable.
- Timestamps are **Unix milliseconds** (`create_at`, `update_at`, etc.). Divide by 1000 for Unix seconds before formatting as a date.
- Use `--show-ids` on `post list` to include post IDs — required for thread reconstruction and cross-references.
- `mmctl` doesn't auto-paginate — for large channels, pass `-n 500` and filter client-side.
- Add `--suppress-warnings` if version-mismatch warnings interfere with JSON parsing.
- For multi-step reads, chain with `&&` in a single bash call to minimize config re-reads.

## Hard limitations

- ❌ **DMs / group messages** — no command lists or reads direct messages. Would need Personal Access Token + REST API.
- ❌ **Full-text message search** — not exposed by mmctl. Same: needs PAT + REST API `/api/v4/posts/search`.
- ❌ **Reactions, file downloads, pinned-post listing**.
- ✅ Channel posts (including reply threads via `root_id` grouping).
- ✅ User/team/channel/bot/webhook management.
- ✅ Posting (with user confirmation).

If the user specifically needs DMs or message search, say so upfront and note that a Personal Access Token (per-user enablement in System Console) unlocks them via the REST API — a narrower IT ask than "enable PATs for everyone."

## Behavioral notes for Claude

1. **Never post without explicit user confirmation.** Treat `mmctl post create` like a send-email action.
2. **Resolve user IDs to usernames** before presenting post authors to the user — the raw 26-char ID is unreadable.
3. **Convert timestamps** to human-readable dates when summarizing.
4. **Ask which team/channel** when the request is ambiguous and there's more than one option — don't guess.
5. **Surface the server URL** you're about to act against when the user has multiple `mmctl auth` credentials, so they can confirm the right instance.
