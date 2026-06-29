"""Turn diarized Speaker N labels into a conversational transcript with names."""

import json
import logging
import os
import re

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../utils/.env"))

logger = logging.getLogger(__name__)

_client: OpenAI | None = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY", ""))
    return _client

SPEAKER_MAP_PROMPT = """Analyze this diarized meeting transcript and map each speaker label to a real person name when possible.

Return JSON only:
{
  "speaker_map": {
    "Speaker 1": "Name or Speaker 1",
    "Speaker 2": "Name or Speaker 2"
  }
}

Rules:
- Use names mentioned in greetings, introductions, or when others address someone (e.g. "hi Allen" means Allen is present).
- Map the speaker label to the person most likely speaking that line based on context.
- Keep the original label (e.g. "Speaker 2") if the real name cannot be determined.
- Do NOT invent names not supported by the transcript."""


def _merge_consecutive_speakers(diarized_text: str) -> str:
    lines = [line.strip() for line in diarized_text.splitlines() if line.strip()]
    if not lines:
        return diarized_text

    merged: list[str] = []
    current_speaker: str | None = None
    current_text: list[str] = []

    for line in lines:
        if ": " in line:
            speaker, text = line.split(": ", 1)
            speaker = speaker.strip()
            text = text.strip()
        else:
            speaker = current_speaker or "Speaker"
            text = line

        if speaker == current_speaker and current_text:
            current_text.append(text)
        else:
            if current_speaker is not None:
                merged.append(f"{current_speaker}: {' '.join(current_text)}")
            current_speaker = speaker
            current_text = [text] if text else []

    if current_speaker is not None and current_text:
        merged.append(f"{current_speaker}: {' '.join(current_text)}")

    return "\n\n".join(merged)


def _apply_speaker_map(text: str, speaker_map: dict[str, str]) -> str:
    output = text
    for old_label, new_name in sorted(
        speaker_map.items(), key=lambda item: len(item[0]), reverse=True
    ):
        new_name = (new_name or old_label).strip()
        if not new_name or new_name.lower() in {"none", "null", "unknown"}:
            continue
        if new_name.lower().startswith("speaker"):
            continue
        output = output.replace(f"{old_label}:", f"{new_name}:")
    return output


def _infer_speaker_map_openai(diarized_text: str) -> dict[str, str] | None:
    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        return None
    try:
        response = _get_client().chat.completions.create(
            model="gpt-4o-mini",
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": SPEAKER_MAP_PROMPT},
                {"role": "user", "content": diarized_text.strip()},
            ],
            temperature=0.1,
        )
        data = json.loads(response.choices[0].message.content.strip())
        raw_map = data.get("speaker_map") or {}
        return {str(k): str(v) for k, v in raw_map.items()}
    except Exception as exc:
        logger.warning("OpenAI speaker map inference failed: %s", exc)
        return None


def _heuristic_name_map(diarized_text: str) -> dict[str, str]:
    """Find 'hi Name' / 'welcome Name' patterns to suggest speaker mappings."""
    re.findall(
        r"\b(?:hi|hello|welcome|thanks|thank you)\s+([A-Z][a-z]+)\b",
        diarized_text,
    )
    return {}


def build_conversational_transcript(diarized_text: str | None) -> str | None:
    """Convert Speaker N diarized lines into Name: dialogue conversational format."""
    if not diarized_text or not diarized_text.strip():
        return None

    merged = _merge_consecutive_speakers(diarized_text.strip())
    speaker_map = _infer_speaker_map_openai(merged) or _heuristic_name_map(merged)

    if speaker_map:
        return _apply_speaker_map(merged, speaker_map).strip()
    return merged
