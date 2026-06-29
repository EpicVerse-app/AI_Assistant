"""Tests for the processing pipeline (process_meeting)."""

import uuid
from unittest.mock import MagicMock

import pytest

from database.models import Meeting, MeetingStatus
from services.pipeline import process_meeting
from tests.conftest import _TestingSessionLocal


def _make_meeting(db, status=MeetingStatus.uploaded) -> Meeting:
    # user_id is nullable — avoids needing a real user row in pipeline unit tests.
    m = Meeting(
        meeting_id=str(uuid.uuid4()),
        user_id=None,
        audio_filename="test.wav",
        status=status,
    )
    db.add(m)
    db.commit()
    db.refresh(m)
    return m


def _fake_storage():
    """Storage mock with a local_path context manager."""
    storage = MagicMock()
    ctx = MagicMock()
    ctx.__enter__ = MagicMock(return_value="/tmp/fake.wav")
    ctx.__exit__ = MagicMock(return_value=False)
    storage.local_path.return_value = ctx
    return storage


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

def test_pipeline_happy_path(reset_db, monkeypatch):
    from dataclasses import dataclass

    @dataclass
    class FakeResult:
        language: str = "en"
        language_probability: float = 1.0
        transcript: str = "Hello world. This is a test meeting."
        diarized_transcript: str | None = None

    monkeypatch.setattr("services.pipeline.transcribe_audio", lambda *a, **kw: FakeResult())
    monkeypatch.setattr("services.pipeline.translate_to_english", lambda text, **kw: text)
    monkeypatch.setattr(
        "services.pipeline.generate_mom_structured",
        lambda *a, **kw: {
            "meeting_date": "2026-01-01",
            "meeting_topic": "Test Meeting",
            "attendees": "Alice",
            "summary": "- A test",
            "decisions": "Not mentioned",
            "action_items": "Not mentioned",
            "deadlines": "Not mentioned",
            "important_notes": "Not mentioned",
        },
    )
    monkeypatch.setattr("services.pipeline.init_metadata", lambda *a, **kw: None)
    monkeypatch.setattr("services.pipeline.save_transcript", lambda *a, **kw: "transcript.txt")
    monkeypatch.setattr("services.pipeline.save_translation", lambda *a, **kw: "translation.txt")
    monkeypatch.setattr("services.pipeline.save_mom", lambda *a, **kw: ("mom.json", "mom.md"))
    monkeypatch.setattr("services.pipeline.save_diarized_transcript", lambda *a, **kw: "d.txt")
    monkeypatch.setattr("services.pipeline.save_error_message", lambda *a, **kw: None)
    monkeypatch.setattr("services.pipeline.mom_to_markdown", lambda *a, **kw: "# Meeting Minutes")
    # pipeline does `from services.storage import get_audio_storage` inside the function
    monkeypatch.setattr("services.storage.get_audio_storage", _fake_storage)

    db = _TestingSessionLocal()
    try:
        meeting = _make_meeting(db)
        process_meeting(meeting.meeting_id, "test.wav", db)
        db.refresh(meeting)
        assert meeting.status == MeetingStatus.done
        assert meeting.transcript_path == "transcript.txt"
        assert meeting.mom_path == "mom.md"
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Empty transcript → failed
# ---------------------------------------------------------------------------

def test_pipeline_empty_transcript_sets_failed(reset_db, monkeypatch):
    from dataclasses import dataclass

    @dataclass
    class EmptyResult:
        language: str = "en"
        language_probability: float = 1.0
        transcript: str = "   "
        diarized_transcript: str | None = None

    monkeypatch.setattr("services.pipeline.transcribe_audio", lambda *a, **kw: EmptyResult())
    monkeypatch.setattr("services.pipeline.init_metadata", lambda *a, **kw: None)
    monkeypatch.setattr("services.pipeline.save_error_message", lambda *a, **kw: None)
    monkeypatch.setattr("services.storage.get_audio_storage", _fake_storage)

    db = _TestingSessionLocal()
    try:
        meeting = _make_meeting(db)
        process_meeting(meeting.meeting_id, "test.wav", db)
        db.refresh(meeting)
        assert meeting.status == MeetingStatus.failed
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Exception during transcription → failed
# ---------------------------------------------------------------------------

def test_pipeline_exception_sets_failed(reset_db, monkeypatch):
    monkeypatch.setattr("services.pipeline.init_metadata", lambda *a, **kw: None)
    monkeypatch.setattr("services.pipeline.save_error_message", lambda *a, **kw: None)
    monkeypatch.setattr("services.storage.get_audio_storage", _fake_storage)

    monkeypatch.setattr(
        "services.pipeline.transcribe_audio",
        lambda *a, **kw: (_ for _ in ()).throw(RuntimeError("Sarvam exploded")),
    )

    db = _TestingSessionLocal()
    try:
        meeting = _make_meeting(db)
        process_meeting(meeting.meeting_id, "test.wav", db)
        db.refresh(meeting)
        assert meeting.status == MeetingStatus.failed
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Non-existent meeting_id is a no-op
# ---------------------------------------------------------------------------

def test_pipeline_unknown_meeting_id(reset_db):
    db = _TestingSessionLocal()
    try:
        process_meeting("non-existent-id", "test.wav", db)  # must not raise
    finally:
        db.close()
