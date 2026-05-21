#!/usr/bin/env python3
"""
Attempt to regenerate Firebase/Google API keys using credentials/logic-sprint-firebase.json.

Requires IAM on the service account:
  roles/serviceusage.apiKeysAdmin  (or API Keys Admin)

If you get HTTP 403, rotate keys manually in Google Cloud Console, then run:
  ./scripts/refresh_firebase_client_config.sh
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2 import service_account

ROOT = Path(__file__).resolve().parents[1]
CRED = ROOT / "credentials/logic-sprint-firebase.json"
PROJECT = "logic-sprint"
LEAKED_PREFIXES = ("AIzaSyB8OIrOPVb9sGAAZ1ebPARV_l7n3jQ7saA", "AIzaSyCzuZSLSArYFYQRZ-mypEXwpQxf6WDqYOo")


def get_token() -> str:
    creds = service_account.Credentials.from_service_account_file(
        str(CRED),
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    creds.refresh(Request())
    return creds.token


def api_request(method: str, url: str, token: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def main() -> int:
    if not CRED.is_file():
        print(f"Missing {CRED}", file=sys.stderr)
        return 1

    token = get_token()
    list_url = f"https://apikeys.googleapis.com/v2/projects/{PROJECT}/locations/global/keys"

    try:
        listed = api_request("GET", list_url, token)
    except urllib.error.HTTPError as e:
        if e.code == 403:
            print(
                "403 Forbidden: this service account cannot manage API keys.\n\n"
                "Fix one of:\n"
                "  A) Google Cloud Console → IAM → grant this SA:\n"
                "     firebase-adminsdk-fbsvc@logic-sprint.iam.gserviceaccount.com\n"
                "     Role: API Keys Admin (roles/serviceusage.apiKeysAdmin)\n"
                "     Then re-run: python3 scripts/rotate_firebase_api_keys.py\n\n"
                "  B) Rotate manually: Console → APIs & Services → Credentials\n"
                "     Regenerate each leaked Android/iOS key, then run:\n"
                "     ./scripts/refresh_firebase_client_config.sh\n",
                file=sys.stderr,
            )
            return 1
        raise

    keys = listed.get("keys", [])
    if not keys:
        print("No API keys found.")
        return 0

    regenerated = 0
    for key in keys:
        name = key["name"]
        key_id = name.split("/")[-1]
        detail_url = f"https://apikeys.googleapis.com/v2/{name}/keyString"
        try:
            detail = api_request("GET", detail_url, token)
            key_string = detail.get("keyString", "")
        except urllib.error.HTTPError:
            key_string = ""

        if key_string not in LEAKED_PREFIXES:
            continue

        regen_url = f"https://apikeys.googleapis.com/v2/{name}:regenerate"
        api_request("POST", regen_url, token, {})
        print(f"Regenerated: {key.get('displayName', key_id)}")
        regenerated += 1

    if regenerated == 0:
        print(
            "No matching leaked keys found (maybe already rotated).\n"
            "Run ./scripts/refresh_firebase_client_config.sh to pull latest config."
        )
    else:
        print(f"\nRegenerated {regenerated} key(s). Refreshing local config ...")
        import subprocess

        subprocess.run(
            [str(ROOT / "scripts/refresh_firebase_client_config.sh")],
            check=True,
            cwd=ROOT,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
