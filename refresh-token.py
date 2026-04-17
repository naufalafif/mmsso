#!/usr/bin/env python3
"""
Read the MMAUTHTOKEN cookie from Chrome's encrypted cookie store and write it
to ~/.config/mmsso/token. Used internally by the `mm` wrapper.

Requires: pycookiecheat (pip install pycookiecheat)
"""

import argparse
import os
import sys

TOKEN_FILE = os.path.expanduser("~/.config/mmsso/token")


def refresh(url: str):
    try:
        from pycookiecheat import chrome_cookies
    except ImportError:
        print("ERROR: pycookiecheat is not installed.", file=sys.stderr)
        print("       Run: pip install pycookiecheat", file=sys.stderr)
        sys.exit(1)

    try:
        cookies = chrome_cookies(url)
    except Exception as e:
        print(f"ERROR: Could not read Chrome cookies: {e}", file=sys.stderr)
        sys.exit(1)

    token = cookies.get("MMAUTHTOKEN")

    if not token:
        print("ERROR: MMAUTHTOKEN not found in Chrome cookies.", file=sys.stderr)
        sys.exit(1)

    token_dir = os.path.dirname(TOKEN_FILE)
    os.makedirs(token_dir, exist_ok=True)
    os.chmod(token_dir, 0o700)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(token)

    print(f"Token refreshed ({len(token)} chars) → {TOKEN_FILE}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="Mattermost server URL")
    args = parser.parse_args()
    refresh(args.url)


if __name__ == "__main__":
    main()
