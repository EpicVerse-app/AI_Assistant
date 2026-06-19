import json
import os
from urllib.request import Request, urlopen

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../utils/.env"))

_client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))

OLLAMA_URL = "http://localhost:11434"
OLLAMA_MODEL = "gemma3:1b"

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
Generate structured Meeting Minutes (MoM) from the transcript provided.

Return a JSON object with exactly these keys:
- meeting_date
- meeting_topic
- attendees
- summary
- decisions
- action_items
- deadlines
- important_notes

If a detail is not mentioned in the transcript, set its value to "Not mentioned".
Be concise, clear, and professional."""

SUMMARY_SYSTEM_PROMPT = """You are a helpful assistant. 
Summarize the conversation below in clear, natural English covering:
- What the conversation is about
- Key points discussed
- Any decisions or conclusions reached

Skip anything not mentioned. Keep it concise and readable."""


def _normalize_mom(data: dict) -> dict:
    for key in MOM_KEYS:
        data.setdefault(key, "Not mentioned")
    return data


def _fallback_mom(transcript: str) -> dict:
    snippet = transcript.strip()
    if len(snippet) > 400:
        snippet = snippet[:400] + "…"
    return _normalize_mom({
        "meeting_date": "Not mentioned",
        "meeting_topic": "Recorded meeting",
        "attendees": "Not mentioned",
        "summary": snippet or "Not mentioned",
        "decisions": "Not mentioned",
        "action_items": "Not mentioned",
        "deadlines": "Not mentioned",
        "important_notes": "Auto-generated from transcript.",
    })


def _generate_mom_with_ollama(transcript: str) -> dict:
    prompt = (
        f"{MOM_SYSTEM_PROMPT}\n\nTranscript:\n{transcript}\n\n"
        "Respond with JSON only."
    )
    payload = {
        "model": OLLAMA_MODEL,
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
        with urlopen(req, timeout=90) as resp:
            raw = json.loads(resp.read()).get("response", "{}")
        if isinstance(raw, str):
            data = json.loads(raw)
        else:
            data = raw
        return _normalize_mom(data)
    except Exception:
        return _fallback_mom(transcript)


def generate_mom_structured(transcript: str) -> dict:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Transcript is empty.")

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if api_key:
        try:
            response = _client.chat.completions.create(
                model="gpt-4o-mini",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": MOM_SYSTEM_PROMPT},
                    {"role": "user", "content": f"Transcript:\n{transcript}"},
                ],
                temperature=0.3,
            )
            data = json.loads(response.choices[0].message.content.strip())
            return _normalize_mom(data)
        except Exception:
            pass

    return _generate_mom_with_ollama(transcript)


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
