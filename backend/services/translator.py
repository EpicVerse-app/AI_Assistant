import requests

from utils.sarvam_config import get_sarvam_api_key

SARVAM_TRANSLATE_URL = "https://api.sarvam.ai/translate"

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


def translate_to_english(text: str, source_language: str = "unknown") -> str:
    text = text.strip()
    if not text:
        return ""

    source_bcp47 = LANGUAGE_MAP.get(source_language, source_language)
    if source_bcp47 in ("en-IN", "en", "unknown"):
        return text

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
