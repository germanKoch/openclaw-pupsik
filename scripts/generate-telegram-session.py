#!/usr/bin/env python3
"""Generate a Telethon StringSession for TELEGRAM_SESSION_STRING.

Reads TELEGRAM_API_ID and TELEGRAM_API_HASH from .env,
runs interactive phone+code auth, and writes the session string back to .env.

Usage:
    uv run --with telethon scripts/generate-telegram-session.py
"""

import re
import sys
from pathlib import Path

from telethon.sync import TelegramClient
from telethon.sessions import StringSession

REPO_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = REPO_DIR / ".env"


def read_env_var(key: str) -> str:
    if not ENV_FILE.exists():
        print(f"Error: {ENV_FILE} not found. Copy .env.template to .env first.")
        sys.exit(1)
    for line in ENV_FILE.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or "=" not in stripped:
            continue
        k, _, v = stripped.partition("=")
        if k.strip() == key:
            return v.strip().strip("'\"")
    return ""


def update_env_var(key: str, value: str) -> None:
    text = ENV_FILE.read_text()
    pattern = rf"^{re.escape(key)}=.*$"
    if re.search(pattern, text, flags=re.MULTILINE):
        text = re.sub(pattern, f"{key}={value}", text, flags=re.MULTILINE)
    else:
        text = text.rstrip("\n") + f"\n{key}={value}\n"
    ENV_FILE.write_text(text)


def main():
    api_id = read_env_var("TELEGRAM_API_ID")
    api_hash = read_env_var("TELEGRAM_API_HASH")

    if not api_id or not api_hash:
        print("Error: TELEGRAM_API_ID and TELEGRAM_API_HASH must be set in .env")
        print("Get them at https://my.telegram.org/apps")
        sys.exit(1)

    print("Generating Telegram StringSession...")
    print(f"  API ID: {api_id}")
    print()

    client = TelegramClient(StringSession(), int(api_id), api_hash)
    client.start()

    session_string = client.session.save()
    client.disconnect()

    update_env_var("TELEGRAM_SESSION_STRING", session_string)
    print()
    print(f"Session saved to {ENV_FILE}")
    print("TELEGRAM_SESSION_STRING has been updated.")


if __name__ == "__main__":
    main()
