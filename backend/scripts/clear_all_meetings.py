#!/usr/bin/env python3
"""Delete all meetings from the deployed API (or local server)."""

import json
import os
import sys
import urllib.error
import urllib.request

BASE_URL = os.environ.get("API_BASE_URL", "https://ai-assistant-api-9xhb.onrender.com")


def _request(method: str, path: str) -> tuple[int, dict | list | None]:
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        method=method,
        headers={"Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8")
        try:
            payload = json.loads(body) if body else None
        except json.JSONDecodeError:
            payload = {"detail": body}
        return exc.code, payload


def main() -> int:
    status, payload = _request("DELETE", "/transcription/list/all")
    if status == 200 and isinstance(payload, dict):
        print(f"Deleted {payload.get('deleted', 0)} meeting(s) via bulk endpoint.")
        return 0

    print(f"Bulk delete unavailable ({status}); deleting one-by-one…")
    status, payload = _request("GET", "/transcription/list/all")
    if status != 200 or not isinstance(payload, dict):
        print(f"Failed to list meetings: {status} {payload}", file=sys.stderr)
        return 1

    meetings = payload.get("meetings") or []
    deleted = 0
    for meeting in meetings:
        meeting_id = meeting.get("meeting_id")
        if not meeting_id:
            continue
        code, _ = _request("DELETE", f"/transcription/{meeting_id}")
        if code == 200:
            deleted += 1

    print(f"Deleted {deleted} meeting(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
