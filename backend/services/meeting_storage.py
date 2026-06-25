"""Save each meeting's artifacts under outputs/meetings/{meeting_id}/."""

import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

MEETINGS_ROOT = Path(__file__).resolve().parent.parent / "outputs" / "meetings"


def meeting_dir(meeting_id: str) -> Path:
    path = MEETINGS_ROOT / meeting_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def delete_meeting_folder(meeting_id: str) -> None:
    """Remove transcript, MoM, and metadata files for a meeting."""
    folder = MEETINGS_ROOT / meeting_id
    if folder.exists():
        shutil.rmtree(folder)


def save_transcript(meeting_id: str, text: str, language: str | None = None) -> Path:
    folder = meeting_dir(meeting_id)
    file_path = folder / "transcript.txt"
    file_path.write_text(text, encoding="utf-8")
    _update_metadata(meeting_id, language=language, transcript_path=str(file_path))
    return file_path


def save_translation(meeting_id: str, text: str) -> Path:
    folder = meeting_dir(meeting_id)
    file_path = folder / "translation.txt"
    file_path.write_text(text, encoding="utf-8")
    _update_metadata(meeting_id, translation_path=str(file_path))
    return file_path


def save_diarized_transcript(meeting_id: str, text: str) -> Path:
    folder = meeting_dir(meeting_id)
    file_path = folder / "diarized_transcript.txt"
    file_path.write_text(text, encoding="utf-8")
    _update_metadata(meeting_id, diarized_transcript_path=str(file_path))
    return file_path


def save_mom(meeting_id: str, mom_data: dict[str, Any], markdown: str) -> tuple[Path, Path]:
    folder = meeting_dir(meeting_id)
    json_path = folder / "mom.json"
    md_path = folder / "mom.md"

    json_path.write_text(json.dumps(mom_data, indent=2, ensure_ascii=False), encoding="utf-8")
    md_path.write_text(markdown, encoding="utf-8")

    _update_metadata(meeting_id, mom_json_path=str(json_path), mom_md_path=str(md_path))
    return json_path, md_path


def load_mom_json(meeting_id: str) -> dict[str, Any] | None:
    path = meeting_dir(meeting_id) / "mom.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def load_mom_markdown(meeting_id: str) -> str | None:
    path = meeting_dir(meeting_id) / "mom.md"
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8").strip()


def load_metadata(meeting_id: str) -> dict[str, Any]:
    path = meeting_dir(meeting_id) / "metadata.json"
    if not path.exists():
        return {"meeting_id": meeting_id}
    return json.loads(path.read_text(encoding="utf-8"))


def init_metadata(meeting_id: str, *, audio_path: str | None = None) -> None:
    folder = meeting_dir(meeting_id)
    meta_path = folder / "metadata.json"
    if meta_path.exists():
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
    meta_path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _update_metadata(meeting_id: str, **fields: Any) -> None:
    meta_path = meeting_dir(meeting_id) / "metadata.json"
    data = load_metadata(meeting_id) if meta_path.exists() else {"meeting_id": meeting_id}
    data.update(fields)
    data["updated_at"] = datetime.utcnow().isoformat()
    meta_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def save_error_message(meeting_id: str, message: str) -> None:
    _update_metadata(meeting_id, error_message=message)


def load_error_message(meeting_id: str) -> str | None:
    message = load_metadata(meeting_id).get("error_message")
    if message is None:
        return None
    text = str(message).strip()
    return text or None


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
