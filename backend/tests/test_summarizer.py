"""Tests for MoM generation: OpenAI success, OpenAI failure → heuristic fallback."""

import json
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from services.summarizer import (
    _fallback_mom,
    _extract_speaker_names,
    generate_mom_structured,
    generate_summary,
)

_SAMPLE_TRANSCRIPT = """Alice: Good morning everyone. Let's start the standup.
Bob: I finished the login page yesterday.
Alice: Great. Bob, can you work on the dashboard next? Deadline is Friday.
Bob: Sure, I'll start today.
Alice: We've decided to use Postgres for the database.
"""

_SAMPLE_MOM = {
    "meeting_date": "2026-06-29",
    "meeting_topic": "Weekly Standup",
    "attendees": "Alice, Bob",
    "summary": "- Login page completed\n- Dashboard work assigned",
    "decisions": "- Use Postgres for the database",
    "action_items": "- Dashboard — Assigned by: Alice → Assignee: Bob | Deadline: Friday",
    "deadlines": "- Friday: Dashboard completion",
    "important_notes": "Not mentioned",
}


# ---------------------------------------------------------------------------
# Speaker extraction
# ---------------------------------------------------------------------------

def test_extract_speaker_names():
    names = _extract_speaker_names(_SAMPLE_TRANSCRIPT)
    assert "Alice" in names
    assert "Bob" in names


def test_extract_speaker_names_skips_generic_labels():
    transcript = "Speaker 1: Hello\nSpeaker 2: Hi"
    assert _extract_speaker_names(transcript) == []


# ---------------------------------------------------------------------------
# generate_mom_structured — OpenAI success
# ---------------------------------------------------------------------------

def test_generate_mom_openai_success(monkeypatch):
    mock_response = MagicMock()
    mock_response.choices[0].message.content = json.dumps(_SAMPLE_MOM)

    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    with patch("services.summarizer._client") as mock_client:
        mock_client.chat.completions.create.return_value = mock_response
        result = generate_mom_structured(
            _SAMPLE_TRANSCRIPT,
            recorded_at=datetime(2026, 6, 29, 10, 0),
        )

    assert result["meeting_date"] == "2026-06-29"
    assert "Alice" in result["attendees"] or "Bob" in result["attendees"]


# ---------------------------------------------------------------------------
# generate_mom_structured — OpenAI failure → heuristic fallback
# ---------------------------------------------------------------------------

def test_generate_mom_falls_back_on_openai_error(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    with patch("services.summarizer._client") as mock_client:
        mock_client.chat.completions.create.side_effect = Exception("OpenAI down")
        result = generate_mom_structured(
            _SAMPLE_TRANSCRIPT,
            recorded_at=datetime(2026, 6, 29),
        )

    # Heuristic fallback should still return a complete dict
    for key in ("meeting_date", "meeting_topic", "attendees", "summary",
                "decisions", "action_items", "deadlines", "important_notes"):
        assert key in result


def test_generate_mom_falls_back_when_no_api_key(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "")
    result = generate_mom_structured(_SAMPLE_TRANSCRIPT)
    for key in ("meeting_date", "meeting_topic", "summary"):
        assert key in result


# ---------------------------------------------------------------------------
# Heuristic fallback directly
# ---------------------------------------------------------------------------

def test_fallback_mom_returns_all_keys():
    result = _fallback_mom(_SAMPLE_TRANSCRIPT, recorded_at=datetime(2026, 6, 29))
    for key in ("meeting_date", "meeting_topic", "attendees", "summary",
                "decisions", "action_items", "deadlines", "important_notes"):
        assert key in result


def test_fallback_mom_uses_recording_date():
    result = _fallback_mom(_SAMPLE_TRANSCRIPT, recorded_at=datetime(2026, 6, 29))
    assert result["meeting_date"] == "2026-06-29"


def test_fallback_mom_empty_transcript():
    result = _fallback_mom("", recorded_at=datetime(2026, 1, 1))
    assert result["summary"] == "Not mentioned"


# ---------------------------------------------------------------------------
# generate_summary
# ---------------------------------------------------------------------------

def test_generate_summary_openai_success(monkeypatch):
    mock_response = MagicMock()
    mock_response.choices[0].message.content = "The team discussed progress."

    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    with patch("services.summarizer._client") as mock_client:
        mock_client.chat.completions.create.return_value = mock_response
        result = generate_summary(_SAMPLE_TRANSCRIPT)

    assert "discussed" in result


def test_generate_summary_no_api_key_returns_message(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "")
    result = generate_summary(_SAMPLE_TRANSCRIPT)
    assert "unavailable" in result.lower() or "not configured" in result.lower()


def test_generate_summary_empty_transcript_raises():
    with pytest.raises(ValueError, match="empty"):
        generate_summary("   ")
