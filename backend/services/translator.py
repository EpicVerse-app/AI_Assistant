import logging
import re

import requests

from utils.sarvam_config import get_sarvam_api_key

logger = logging.getLogger(__name__)

SARVAM_TRANSLATE_URL = "https://api.sarvam.ai/translate"
# Sarvam mayura:v1 allows at most 1000 characters per request.
MAX_CHUNK_CHARS = 950

# Maps language codes from STT → BCP-47 for Sarvam translate API
LANGUAGE_MAP = {
    "hi": "hi-IN",
    "hi-IN": "hi-IN",
    "ta": "ta-IN",
    "ta-IN": "ta-IN",
    "te": "te-IN",
    "te-IN": "te-IN",
    "ml": "ml-IN",
    "ml-IN": "ml-IN",
    "kn": "kn-IN",
    "kn-IN": "kn-IN",
    "bn": "bn-IN",
    "bn-IN": "bn-IN",
    "gu": "gu-IN",
    "gu-IN": "gu-IN",
    "mr": "mr-IN",
    "mr-IN": "mr-IN",
    "pa": "pa-IN",
    "pa-IN": "pa-IN",
    "od": "od-IN",
    "od-IN": "od-IN",
    "en": "en-IN",
    "en-IN": "en-IN",
    "unknown": "unknown",
}


def _split_text(text: str, max_chars: int = MAX_CHUNK_CHARS) -> list[str]:
    text = text.strip()
    if len(text) <= max_chars:
        return [text]

    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        if end < len(text):
            split_at = text.rfind("\n", start, end)
            if split_at <= start:
                split_at = text.rfind(" ", start, end)
            if split_at <= start:
                split_at = end
            end = split_at
        piece = text[start:end].strip()
        if piece:
            chunks.append(piece)
        start = end if end > start else end + 1

    return chunks or [text]


def _translate_chunk(text: str, source_bcp47: str) -> str:
    response = requests.post(
        SARVAM_TRANSLATE_URL,
        headers={
            "api-subscription-key": get_sarvam_api_key(),
            "Content-Type": "application/json",
        },
        json={
            "input": text,
            "source_language_code": source_bcp47,
            "target_language_code": "en-IN",
            "model": "mayura:v1",
        },
        timeout=120,
    )
    if not response.ok:
        raise RuntimeError(
            f"Sarvam translate error {response.status_code}: {response.text}"
        )
    return response.json().get("translated_text", "").strip() or text


def translate_to_english(text: str, source_language: str = "unknown") -> str:
    text = text.strip()
    if not text:
        return ""

    source_bcp47 = LANGUAGE_MAP.get(source_language, source_language)
    if source_bcp47 in ("en-IN", "en", "unknown"):
        return text

    chunks = _split_text(text)
    translated: list[str] = []
    for chunk in chunks:
        translated.append(_translate_chunk(chunk, source_bcp47))
    return re.sub(r"\s+", " ", " ".join(translated)).strip() or text
