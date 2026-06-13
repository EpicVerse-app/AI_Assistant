import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../utils/.env"))

_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

LANGUAGE_NAMES = {
    "hi-IN": "Hindi", "ta-IN": "Tamil", "te-IN": "Telugu",
    "ml-IN": "Malayalam", "kn-IN": "Kannada", "bn-IN": "Bengali",
    "gu-IN": "Gujarati", "mr-IN": "Marathi", "pa-IN": "Punjabi",
    "od-IN": "Odia", "en-IN": "English", "unknown": "the source language",
}


def translate_to_english(text: str, source_language: str = "unknown") -> str:
    text = text.strip()
    if not text:
        return ""

    lang_name = LANGUAGE_NAMES.get(source_language, source_language)

    if source_language in ("en-IN", "en"):
        return text

    response = _client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {
                "role": "system",
                "content": (
                    f"You are a professional translator. "
                    f"Translate the following {lang_name} text to English accurately. "
                    "Preserve the meaning, tone, and structure. Return only the translation."
                ),
            },
            {"role": "user", "content": text},
        ],
        temperature=0.2,
    )
    return response.choices[0].message.content.strip()
