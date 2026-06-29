"""Tests for /transcription endpoints: upload, list, detail, delete, ownership."""

import io
import uuid
from unittest.mock import MagicMock, patch

import pytest

from tests.conftest import auth_headers, make_wav_bytes, register_and_login


def _upload(client, token, wav_bytes=None):
    """Helper: upload a WAV file and return the response."""
    data = wav_bytes or make_wav_bytes()
    return client.post(
        "/transcription/upload",
        files={"file": ("meeting.wav", io.BytesIO(data), "audio/wav")},
        headers=auth_headers(token),
    )


# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------

def test_upload_returns_meeting_id(client, monkeypatch):
    # Patch the background task function so no real processing runs
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token = register_and_login(client)
    resp = _upload(client, token)
    assert resp.status_code == 200
    body = resp.json()
    assert "meeting_id" in body
    assert body["status"] == "uploaded"


def test_upload_requires_auth(client):
    resp = client.post(
        "/transcription/upload",
        files={"file": ("meeting.wav", io.BytesIO(make_wav_bytes()), "audio/wav")},
    )
    assert resp.status_code == 401


def test_upload_rejects_oversized_file(client):
    token = register_and_login(client)
    # Fake a Content-Length header larger than the 604 MB limit
    big = 700 * 1024 * 1024  # 700 MB
    resp = client.post(
        "/transcription/upload",
        files={"file": ("big.wav", io.BytesIO(b"x"), "audio/wav")},
        headers={**auth_headers(token), "content-length": str(big)},
    )
    assert resp.status_code == 413


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

def test_list_empty(client):
    token = register_and_login(client)
    resp = client.get("/transcription/list/all", headers=auth_headers(token))
    assert resp.status_code == 200
    assert resp.json()["meetings"] == []


def test_list_scoped_to_user(client, monkeypatch):
    """User A cannot see User B's meetings."""
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token_a = register_and_login(client, email="a@example.com")
    token_b = register_and_login(client, email="b@example.com")

    _upload(client, token_a)

    resp = client.get("/transcription/list/all", headers=auth_headers(token_b))
    assert resp.json()["meetings"] == []


def test_list_no_output_folder_leak(client, monkeypatch):
    """output_folder must not appear in the list response."""
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token = register_and_login(client)
    _upload(client, token)

    resp = client.get("/transcription/list/all", headers=auth_headers(token))
    for meeting in resp.json()["meetings"]:
        assert "output_folder" not in meeting


# ---------------------------------------------------------------------------
# Get transcript / detail
# ---------------------------------------------------------------------------

def test_get_transcript_not_found(client):
    token = register_and_login(client)
    resp = client.get(f"/transcription/{uuid.uuid4()}", headers=auth_headers(token))
    assert resp.status_code == 404


def test_get_detail_no_output_folder_leak(client, monkeypatch):
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token = register_and_login(client)
    upload_resp = _upload(client, token)
    meeting_id = upload_resp.json()["meeting_id"]

    resp = client.get(f"/transcription/{meeting_id}/detail", headers=auth_headers(token))
    assert resp.status_code == 200
    assert "output_folder" not in resp.json()


# ---------------------------------------------------------------------------
# Ownership enforcement
# ---------------------------------------------------------------------------

def test_other_user_cannot_read_meeting(client, monkeypatch):
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token_a = register_and_login(client, email="owner@example.com")
    token_b = register_and_login(client, email="intruder@example.com")

    meeting_id = _upload(client, token_a).json()["meeting_id"]

    resp = client.get(f"/transcription/{meeting_id}", headers=auth_headers(token_b))
    assert resp.status_code == 403


def test_other_user_cannot_delete_meeting(client, monkeypatch):
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    token_a = register_and_login(client, email="owner2@example.com")
    token_b = register_and_login(client, email="intruder2@example.com")

    meeting_id = _upload(client, token_a).json()["meeting_id"]

    resp = client.delete(f"/transcription/{meeting_id}", headers=auth_headers(token_b))
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

def test_delete_meeting(client, monkeypatch):
    monkeypatch.setattr("api.transcription._process_transcription", lambda *a, **kw: None)
    monkeypatch.setattr("api.transcription.init_metadata", lambda *a, **kw: None)
    monkeypatch.setattr("services.meeting_storage.delete_meeting_folder", lambda mid: None)
    token = register_and_login(client)
    meeting_id = _upload(client, token).json()["meeting_id"]

    resp = client.delete(f"/transcription/{meeting_id}", headers=auth_headers(token))
    assert resp.status_code == 200

    # Should be gone now
    resp2 = client.get(f"/transcription/{meeting_id}", headers=auth_headers(token))
    assert resp2.status_code == 404
