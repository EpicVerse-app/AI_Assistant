"""Save each meeting's artifacts under outputs/meetings/{meeting_id}/ or S3."""

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from services.storage import artifacts as artifact_storage

MEETINGS_ROOT = artifact_storage.MEETINGS_ROOT


def meeting_dir(meeting_id: str) -> Path:
    path = MEETINGS_ROOT / meeting_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def delete_meeting_folder(meeting_id: str) -> None:
    artifact_storage.delete_meeting_prefix(meeting_id)


def save_transcript(meeting_id: str, text: str, language: str | None = None) -> str:
    ref = artifact_storage.write_text(meeting_id, "transcript.txt", text)
    _update_metadata(meeting_id, language=language, transcript_path=ref)
    return ref


def save_translation(meeting_id: str, text: str) -> str:
    ref = artifact_storage.write_text(meeting_id, "translation.txt", text)
    _update_metadata(meeting_id, translation_path=ref)
    return ref


def save_diarized_transcript(meeting_id: str, text: str) -> str:
    ref = artifact_storage.write_text(meeting_id, "diarized_transcript.txt", text)
    _update_metadata(meeting_id, diarized_transcript_path=ref)
    return ref


def save_mom(meeting_id: str, mom_data: dict[str, Any], markdown: str) -> tuple[str, str]:
    json_ref = artifact_storage.write_text(
        meeting_id,
        "mom.json",
        json.dumps(mom_data, indent=2, ensure_ascii=False),
    )
    md_ref = artifact_storage.write_text(meeting_id, "mom.md", markdown)
    _update_metadata(meeting_id, mom_json_path=json_ref, mom_md_path=md_ref)
    return json_ref, md_ref


def load_mom_json(meeting_id: str) -> dict[str, Any] | None:
    meta = load_metadata(meeting_id)
    ref = meta.get("mom_json_path")
    return artifact_storage.read_json(meeting_id, "mom.json", ref)


def load_mom_markdown(meeting_id: str) -> str | None:
    meta = load_metadata(meeting_id)
    ref = meta.get("mom_md_path")
    text = artifact_storage.read_text(meeting_id, "mom.md", ref)
    return text.strip() if text else None


def load_metadata(meeting_id: str) -> dict[str, Any]:
    data = artifact_storage.read_json(meeting_id, "metadata.json")
    return data if data else {"meeting_id": meeting_id}


def init_metadata(meeting_id: str, *, audio_path: str | None = None) -> None:
    if artifact_storage.exists(meeting_id, "metadata.json"):
        return
    data = {
        "meeting_id": meeting_id,
        "created_at": datetime.utcnow().isoformat(),
        "audio_path": audio_path,
        "language": None,
        "transcript_path": None,
        "translation_path": None,
        "mom_json_path": None,
        "mom_md_path": None,
    }
    artifact_storage.write_text(
        meeting_id,
        "metadata.json",
        json.dumps(data, indent=2),
    )


def _update_metadata(meeting_id: str, **fields: Any) -> None:
    data = load_metadata(meeting_id)
    data.update(fields)
    data["updated_at"] = datetime.utcnow().isoformat()
    artifact_storage.write_text(
        meeting_id,
        "metadata.json",
        json.dumps(data, indent=2, ensure_ascii=False),
    )


def save_error_message(meeting_id: str, message: str) -> None:
    _update_metadata(meeting_id, error_message=message)


def load_error_message(meeting_id: str) -> str | None:
    message = load_metadata(meeting_id).get("error_message")
    if message is None:
        return None
    text = str(message).strip()
    return text or None


def read_transcript(meeting_id: str, reference: str | None = None) -> str | None:
    return artifact_storage.read_text(meeting_id, "transcript.txt", reference)


def read_translation(meeting_id: str, reference: str | None = None) -> str | None:
    return artifact_storage.read_text(meeting_id, "translation.txt", reference)


def _render_section_body(body: str) -> str:
    text = str(body).strip() or "Not mentioned"
    if text == "Not mentioned":
        return text
    if "\n" in text or text.startswith("- "):
        return text
    return f"- {text}"


def mom_to_markdown(mom: dict[str, Any]) -> str:
    bullet_sections = {
        "Summary",
        "Decisions",
        "Action Items",
        "Deadlines",
        "Important Notes",
    }
    sections = [
        ("Meeting Date", mom.get("meeting_date", "Not mentioned")),
        ("Meeting Topic", mom.get("meeting_topic", "Not mentioned")),
        ("Attendees", mom.get("attendees", "Not mentioned")),
        ("Summary", mom.get("summary", "Not mentioned")),
        ("Decisions", mom.get("decisions", "Not mentioned")),
        ("Action Items", mom.get("action_items", "Not mentioned")),
        ("Deadlines", mom.get("deadlines", "Not mentioned")),
        ("Important Notes", mom.get("important_notes", "Not mentioned")),
    ]
    lines: list[str] = ["# Meeting Minutes", ""]
    for title, body in sections:
        lines.append(f"## {title}")
        content = _render_section_body(body) if title in bullet_sections else str(body).strip()
        lines.append(content or "Not mentioned")
        lines.append("")
    return "\n".join(lines).strip()
