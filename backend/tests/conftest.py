"""Shared fixtures for the test suite.

Every test gets:
  - An in-memory SQLite DB (no file on disk, wiped per test).
  - A FastAPI TestClient with DB and storage dependencies overridden.
  - OpenAI and Sarvam patched so no real API calls are made.
  - Rate limiting disabled so register/login calls don't hit the 10/hour cap.
"""

import io
import os
import wave

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Set env before importing anything that reads it at module level.
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["JWT_SECRET"] = "test-secret-at-least-32-chars-long!"
os.environ["OPENAI_API_KEY"] = "sk-test-key"
os.environ["LOG_FORMAT"] = "text"
os.environ["LOG_LEVEL"] = "WARNING"
# Disable rate limiting in tests — avoids 429s when registering many users.
os.environ["AUTH_REGISTER_RATE"] = "1000/minute"
os.environ["AUTH_LOGIN_RATE"] = "1000/minute"

from sqlalchemy.pool import StaticPool

from database.db import Base, get_db   # noqa: E402
import database.models                 # noqa: F401, E402 — registers models with Base.metadata

# ---------------------------------------------------------------------------
# In-memory database (one engine for the whole test session)
# ---------------------------------------------------------------------------
# StaticPool forces every SQLAlchemy checkout to reuse the SAME underlying
# connection, which is required for SQLite :memory: — without it each new
# connection gets a brand-new empty database and sees no tables.

_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


def _override_get_db():
    db = _TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture()
def reset_db():
    """Drop and recreate all tables before (and after) each test that needs it."""
    Base.metadata.drop_all(bind=_engine)
    Base.metadata.create_all(bind=_engine)
    yield
    Base.metadata.drop_all(bind=_engine)


# ---------------------------------------------------------------------------
# App / TestClient
# ---------------------------------------------------------------------------

@pytest.fixture()
def client(reset_db, monkeypatch):
    """TestClient with DB overridden and external calls patched."""

    # Patch Alembic upgrade so init_db() is a no-op in tests
    monkeypatch.setattr("database.db.init_db", lambda: None, raising=False)

    # Patch storage so no files are written to disk
    _fake = _FakeAudioStorage()
    monkeypatch.setattr("services.storage.get_audio_storage", lambda: _fake)
    monkeypatch.setattr("api.transcription.get_audio_storage", lambda: _fake)

    from app import app
    app.dependency_overrides[get_db] = _override_get_db

    with TestClient(app, raise_server_exceptions=True) as c:
        yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_wav_bytes(duration_ms: int = 100) -> bytes:
    """Return a valid minimal WAV file (16 kHz, mono, 16-bit)."""
    sample_rate = 16_000
    num_frames = int(sample_rate * duration_ms / 1000)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * num_frames)
    return buf.getvalue()


def register_and_login(client, email="user@example.com", password="password123", name="Test User"):
    """Register a user and return their auth token."""
    resp = client.post("/auth/register", json={"email": email, "password": password, "full_name": name})
    assert resp.status_code == 201, resp.text
    return resp.json()["access_token"]


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Fake storage backend
# ---------------------------------------------------------------------------

class _FakeAudioStorage:
    """In-memory audio storage — no disk I/O."""

    def __init__(self):
        self._store: dict[str, bytes] = {}

    def save_wav(self, meeting_id: str, wav_bytes: bytes) -> str:
        ref = f"{meeting_id}.wav"
        self._store[ref] = wav_bytes
        return ref

    def exists(self, meeting_id: str, reference: str) -> bool:
        return reference in self._store

    def read_bytes(self, meeting_id: str, reference: str) -> bytes:
        return self._store.get(reference, b"")

    def stream(self, meeting_id: str, reference: str):
        return io.BytesIO(self._store.get(reference, b""))

    def head(self, meeting_id: str, reference: str) -> dict:
        data = self._store.get(reference, b"")
        return {"size_bytes": len(data)}

    def delete(self, meeting_id: str, reference: str) -> None:
        self._store.pop(reference, None)

    @staticmethod
    def display_filename(meeting_id: str) -> str:
        return f"{meeting_id}.wav"
