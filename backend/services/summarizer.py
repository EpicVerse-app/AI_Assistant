import json
import logging
import os
import re
from datetime import datetime
from urllib.request import Request, urlopen

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../utils/.env"))

logger = logging.getLogger(__name__)

_client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "gemma3:1b")
OLLAMA_FALLBACK_MODELS = [
    m.strip()
    for m in os.environ.get("OLLAMA_FALLBACK_MODELS", "gemma2:9b,gemma3:1b").split(",")
    if m.strip()
]

MOM_KEYS = [
    "meeting_date",
    "meeting_topic",
    "attendees",
    "summary",
    "decisions",
    "action_items",
    "deadlines",
    "important_notes",
]

MOM_SYSTEM_PROMPT = """You are a professional meeting assistant.
Generate structured Meeting Minutes (MoM) from the conversational transcript provided.

Return a JSON object with exactly these keys:
- meeting_date
- meeting_topic
- attendees
- summary
- decisions
- action_items
- deadlines
- important_notes

Follow this order of thinking: read the transcript → write summary → derive topic from summary → extract attendees → list decisions → list action items → list deadlines.

Rules:
- meeting_date: Use the recording date provided in the user message (YYYY-MM-DD). Never return "Not mentioned" when a recording date is supplied.
- summary: Exactly 5 to 6 bullet points. Each line must start with "- ". Each point covers one main topic, update, or discussion item from the meeting. Be specific and concise.
- meeting_topic: A short title (3-8 words) derived FROM the summary points you wrote. Must reflect what the meeting was actually about. Never use generic titles like "Recorded meeting" or "Not mentioned".
- attendees: Comma-separated list of speaker names from the transcript (the names before the colon in "Name: dialogue" lines). Use the provided speaker list when given. Do not include "Speaker 1" style labels if real names are available.
- decisions: Bullet points only. Each line starts with "- ". List concrete decisions taken or agreed during the meeting (approvals, role changes, policy choices, team moves, etc.). Use "Not mentioned" only if no decisions were made.
- action_items: Bullet list of tasks. Each line starts with "- " and uses this exact format:
  - [Task description] — Assigned by: [Name] → Assignee: [Name] | Deadline: [Date or "Not mentioned"]
  Include every task or follow-up mentioned. Extract who assigned it, who must do it, and any due date stated.
- deadlines: Bullet list of task completion dates and important dates mentioned. Each line starts with "- ". Format: "- [Date]: [Task or event]". Include dates from action items and any other deadlines discussed. Use "Not mentioned" if no dates were mentioned.
- important_notes: Bullet points only. Each line starts with "- ". Optional extra context not covered above.

Be concise, clear, and professional. Extract real content from the transcript — avoid returning "Not mentioned" for every field."""

SUMMARY_SYSTEM_PROMPT = """You are a helpful assistant. 
Summarize the conversation below in clear, natural English covering:
- What the conversation is about
- Key points discussed
- Any decisions or conclusions reached

Skip anything not mentioned. Keep it concise and readable."""


def extract_speaker_names(transcript: str) -> list[str]:
    """Extract speaker labels from conversational transcript lines."""
    return _extract_speaker_names(transcript)


def _extract_speaker_names(transcript: str) -> list[str]:
    """Extract speaker labels from conversational transcript lines."""
    names: list[str] = []
    for line in transcript.splitlines():
        if ": " not in line:
            continue
        speaker = line.split(": ", 1)[0].strip()
        if not speaker or speaker in names:
            continue
        if speaker.lower() in {"none", "null", "unknown"}:
            continue
        if speaker.lower().startswith("speaker "):
            continue
        names.append(speaker)
    return names


def _bullet_lines(text: str) -> list[str]:
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.lower() == "not mentioned":
            continue
        if stripped.startswith("- "):
            lines.append(stripped[2:].strip())
        else:
            lines.append(stripped)
    return lines


def _limit_bullets(text: str, *, min_count: int = 5, max_count: int = 6) -> str:
    lines = _bullet_lines(text)
    if not lines:
        return "Not mentioned"
    if len(lines) > max_count:
        lines = lines[:max_count]
    return "\n".join(f"- {line}" for line in lines)


def _derive_topic_from_summary(summary: str) -> str:
    lines = _bullet_lines(summary)
    if not lines:
        return "Not mentioned"
    words = lines[0].split()
    if len(words) <= 8:
        return lines[0].rstrip(".")
    return " ".join(words[:8]).rstrip(",") + "…"


def _normalize_mom(data: dict) -> dict:
    cleaned = {k: v for k, v in data.items() if k in MOM_KEYS or not k.startswith(" ")}
    for key in MOM_KEYS:
        cleaned.setdefault(key, "Not mentioned")
    return cleaned


def _format_as_bullets(value) -> str:
    """Ensure multi-line bullet formatting for MoM text fields."""
    if value is None:
        return "Not mentioned"
    if isinstance(value, list):
        lines = []
        for item in value:
            if isinstance(item, dict):
                task = item.get("task") or item.get("description") or item.get("action")
                assigned_by = item.get("assigned_by") or item.get("assigner") or "Not mentioned"
                assignee = (
                    item.get("assignee")
                    or item.get("assigned_to")
                    or item.get("assignedTo")
                    or "Not mentioned"
                )
                deadline = item.get("deadline") or item.get("due_date") or "Not mentioned"
                if task:
                    lines.append(
                        f"- {task} — Assigned by: {assigned_by} → Assignee: {assignee} | Deadline: {deadline}"
                    )
                else:
                    lines.append(f"- {_stringify_mom_value(item)}")
            else:
                text = str(item).strip()
                if text:
                    lines.append(text if text.startswith("- ") else f"- {text}")
        return "\n".join(lines) if lines else "Not mentioned"

    text = str(value).strip()
    if not text or text.lower() == "not mentioned":
        return "Not mentioned"
    if "\n" in text:
        return "\n".join(
            line if line.strip().startswith("- ") else f"- {line.strip()}"
            for line in text.splitlines()
            if line.strip()
        )
    if text.startswith("- "):
        return text
    return f"- {text}"


def _stringify_mom_value(value) -> str:
    if value is None:
        return "Not mentioned"
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, dict):
                parts.append(
                    ", ".join(f"{k}: {v}" for k, v in item.items() if v)
                )
            else:
                parts.append(str(item))
        return "; ".join(p for p in parts if p.strip()) or "Not mentioned"
    text = str(value).strip()
    return text or "Not mentioned"


def _clean_attendees(value: str) -> str:
    if not value or value == "Not mentioned":
        return "Not mentioned"
    names = [name.strip(" .") for name in value.split(",") if name.strip(" .")]
    return ", ".join(names) if names else "Not mentioned"


def _clean_topic(value: str) -> str:
    text = str(value).strip().lstrip(".")
    if not text or text.lower() == "recorded meeting":
        return "Not mentioned"
    return text


def _finalize_mom(mom: dict, *, speaker_names: list[str] | None = None) -> dict:
    bullet_fields = {
        "summary",
        "decisions",
        "action_items",
        "deadlines",
        "important_notes",
    }
    for key in MOM_KEYS:
        if key in ("meeting_date", "meeting_topic", "attendees"):
            continue
        if key in mom:
            if key in bullet_fields:
                mom[key] = _format_as_bullets(mom[key])
            else:
                mom[key] = _stringify_mom_value(mom[key])

    if "summary" in mom:
        mom["summary"] = _limit_bullets(mom.get("summary", ""), min_count=5, max_count=6)

    topic = _clean_topic(mom.get("meeting_topic", ""))
    if topic == "Not mentioned" and mom.get("summary", "") != "Not mentioned":
        topic = _derive_topic_from_summary(mom["summary"])
    mom["meeting_topic"] = topic

    attendees = _clean_attendees(mom.get("attendees", ""))
    if attendees == "Not mentioned" and speaker_names:
        attendees = ", ".join(speaker_names)
    mom["attendees"] = attendees

    return _normalize_mom(mom)


def _heuristic_mom(
    transcript: str,
    *,
    recorded_at: datetime | None = None,
    speaker_names: list[str] | None = None,
) -> dict:
    """Build structured MoM from transcript when LLM calls fail."""
    date_str = recorded_at.strftime("%Y-%m-%d") if recorded_at else "Not mentioned"
    names = speaker_names or _extract_speaker_names(transcript)

    # Strip speaker prefixes for sentence extraction
    plain = re.sub(r"^[^:]+:\s*", "", transcript, flags=re.MULTILINE)
    sentences = [
        s.strip()
        for s in re.split(r"(?<=[.!?])\s+", plain.replace("\n", " "))
        if len(s.strip()) > 20
    ]

    summary_bullets: list[str] = []
    if sentences:
        chunk_size = max(1, len(sentences) // 6)
        for i in range(0, min(len(sentences), 6 * chunk_size), chunk_size):
            chunk = " ".join(sentences[i : i + chunk_size])
            if len(chunk) > 220:
                chunk = chunk[:217].rsplit(" ", 1)[0] + "…"
            summary_bullets.append(chunk)
    while len(summary_bullets) < 5 and sentences:
        summary_bullets.append(sentences[min(len(summary_bullets), len(sentences) - 1)])
    summary_bullets = summary_bullets[:6]

    decision_keywords = re.compile(
        r"\b(decided|decision|approved|accepted|moving|will include|step in as|welcome)\b",
        re.I,
    )
    action_keywords = re.compile(
        r"\b(will work|need to|assigned|follow up|hire|compile and report|working through)\b",
        re.I,
    )
    date_pattern = re.compile(
        r"\b(?:January|February|March|April|May|June|July|August|September|October|November|December"
        r"|\d{1,2}(?:st|nd|rd|th)?)\b[^.!?]{0,40}",
        re.I,
    )

    decisions = [s for s in sentences if decision_keywords.search(s)]
    actions = [s for s in sentences if action_keywords.search(s)]
    deadlines = [m.group(0).strip() for s in sentences for m in [date_pattern.search(s)] if m]

    def _bullets(items: list[str], limit: int = 6) -> str:
        if not items:
            return "Not mentioned"
        return "\n".join(f"- {item}" for item in items[:limit])

    topic = _derive_topic_from_summary(_bullets(summary_bullets)) if summary_bullets else "Not mentioned"

    action_lines = []
    for sent in actions[:6]:
        assigner = names[0] if names else "Not mentioned"
        assignee = names[1] if len(names) > 1 else "Not mentioned"
        deadline_match = date_pattern.search(sent)
        deadline = deadline_match.group(0).strip() if deadline_match else "Not mentioned"
        action_lines.append(
            f"- {sent} — Assigned by: {assigner} → Assignee: {assignee} | Deadline: {deadline}"
        )

    deadline_lines = []
    for sent in sentences:
        for match in date_pattern.finditer(sent):
            deadline_lines.append(f"- {match.group(0).strip()}: {sent[:120].rstrip()}…")

    return {
        "meeting_date": date_str,
        "meeting_topic": topic,
        "attendees": ", ".join(names) if names else "Not mentioned",
        "summary": _bullets(summary_bullets),
        "decisions": _bullets(decisions),
        "action_items": "\n".join(action_lines) if action_lines else "Not mentioned",
        "deadlines": "\n".join(deadline_lines[:6]) if deadline_lines else "Not mentioned",
        "important_notes": "Not mentioned",
    }


def _fallback_mom(
    transcript: str,
    *,
    recorded_at: datetime | None = None,
    speaker_names: list[str] | None = None,
) -> dict:
    return _heuristic_mom(
        transcript,
        recorded_at=recorded_at,
        speaker_names=speaker_names,
    )


def _build_mom_user_message(
    transcript: str,
    *,
    recorded_at: datetime | None = None,
    plain_transcript: str | None = None,
    speaker_names: list[str] | None = None,
) -> str:
    parts: list[str] = []
    if recorded_at:
        parts.append(f"Recording date: {recorded_at.strftime('%Y-%m-%d')}")
        parts.append(f"Recording time: {recorded_at.strftime('%H:%M')}")
        parts.append("")
    if speaker_names:
        parts.append(f"Speakers in this meeting: {', '.join(speaker_names)}")
        parts.append("Use these names for the attendees field.")
        parts.append("")
    parts.append("Transcript:")
    parts.append(transcript.strip())
    if plain_transcript and plain_transcript.strip() != transcript.strip():
        parts.append("")
        parts.append("Full plain transcript (for reference):")
        parts.append(plain_transcript.strip())
    return "\n".join(parts)


def _apply_recorded_date(mom: dict, recorded_at: datetime | None) -> dict:
    if recorded_at:
        mom["meeting_date"] = recorded_at.strftime("%Y-%m-%d")
    return mom


def _ollama_models_to_try() -> list[str]:
    models: list[str] = []
    for name in [OLLAMA_MODEL, *OLLAMA_FALLBACK_MODELS]:
        if name and name not in models:
            models.append(name)
    return models


def _generate_mom_with_ollama(
    transcript: str,
    *,
    recorded_at: datetime | None = None,
    plain_transcript: str | None = None,
    speaker_names: list[str] | None = None,
) -> dict:
    user_content = _build_mom_user_message(
        transcript,
        recorded_at=recorded_at,
        plain_transcript=plain_transcript,
        speaker_names=speaker_names,
    )
    prompt = f"{MOM_SYSTEM_PROMPT}\n\n{user_content}\n\nRespond with JSON only."
    last_error: Exception | None = None
    for model in _ollama_models_to_try():
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "format": "json",
        }
        req = Request(
            f"{OLLAMA_URL}/api/generate",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urlopen(req, timeout=120) as resp:
                raw = json.loads(resp.read()).get("response", "{}")
            if isinstance(raw, str):
                data = json.loads(raw)
            else:
                data = raw
            if not data or not any(data.get(k) for k in ("summary", "meeting_topic", "decisions")):
                raise ValueError(f"Empty MoM JSON from Ollama model {model}")
            return _apply_recorded_date(
                _finalize_mom(data, speaker_names=speaker_names),
                recorded_at,
            )
        except Exception as exc:
            last_error = exc
            logger.warning("Ollama MoM generation failed for model %s (%s).", model, exc)
            continue

    logger.warning("All Ollama models failed (%s); using heuristic fallback.", last_error)
    return _finalize_mom(
        _fallback_mom(transcript, recorded_at=recorded_at, speaker_names=speaker_names),
        speaker_names=speaker_names,
    )


def generate_mom_structured(
    transcript: str,
    *,
    recorded_at: datetime | None = None,
    plain_transcript: str | None = None,
    speaker_names: list[str] | None = None,
) -> dict:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Transcript is empty.")

    if not speaker_names:
        speaker_names = _extract_speaker_names(transcript)

    user_content = _build_mom_user_message(
        transcript,
        recorded_at=recorded_at,
        plain_transcript=plain_transcript,
        speaker_names=speaker_names,
    )

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if api_key:
        try:
            response = _client.chat.completions.create(
                model="gpt-4o-mini",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": MOM_SYSTEM_PROMPT},
                    {"role": "user", "content": user_content},
                ],
                temperature=0.3,
            )
            data = json.loads(response.choices[0].message.content.strip())
            return _apply_recorded_date(
                _finalize_mom(data, speaker_names=speaker_names),
                recorded_at,
            )
        except Exception as exc:
            logger.warning("OpenAI MoM generation failed (%s); falling back to Ollama.", exc)

    return _generate_mom_with_ollama(
        transcript,
        recorded_at=recorded_at,
        plain_transcript=plain_transcript,
        speaker_names=speaker_names,
    )


def generate_mom(transcript: str) -> str:
    from services.meeting_storage import mom_to_markdown

    return mom_to_markdown(generate_mom_structured(transcript))


def generate_summary(transcript: str) -> str:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Transcript is empty.")

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if api_key:
        try:
            response = _client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SUMMARY_SYSTEM_PROMPT},
                    {"role": "user", "content": f"Transcript:\n{transcript}"},
                ],
                temperature=0.3,
            )
            return response.choices[0].message.content.strip()
        except Exception:
            pass

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": f"{SUMMARY_SYSTEM_PROMPT}\n\nTranscript:\n{transcript}\n\nSummary:",
        "stream": False,
    }
    req = Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(req, timeout=180) as resp:
        return json.loads(resp.read()).get("response", "").strip()
