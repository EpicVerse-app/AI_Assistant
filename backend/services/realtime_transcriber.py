"""
Real-time transcription using Sarvam AI.
Records audio from the microphone in 5-second chunks, transcribes each chunk,
shows an English translation, and prints a conversation summary on exit.
Press Ctrl+C to stop.
"""

import io
import json
import os
import wave
from urllib.request import Request, urlopen

import numpy as np
import requests
import sounddevice as sd

SARVAM_API_KEY = os.environ.get("SARVAM_API_KEY", "sk_nkz538vv_VCZFn21xyI6P1Oxo0v8QnsKH")
SARVAM_STT_URL = "https://api.sarvam.ai/speech-to-text"
SARVAM_TRANSLATE_URL = "https://api.sarvam.ai/translate"

OLLAMA_URL = "http://localhost:11434"
OLLAMA_MODEL = "gemma3:1b"

SAMPLE_RATE = 16000
CHUNK_SECONDS = 5
CHANNELS = 1

# Maps ISO 639-1 codes returned by Sarvam STT → BCP-47 codes for translate API
LANGUAGE_MAP = {
    "hi": "hi-IN",
    "ta": "ta-IN",
    "te": "te-IN",
    "ml": "ml-IN",
    "kn": "kn-IN",
    "bn": "bn-IN",
    "gu": "gu-IN",
    "mr": "mr-IN",
    "pa": "pa-IN",
    "od": "od-IN",
    "en": "en-IN",
}


def audio_to_wav_bytes(audio: np.ndarray) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes((audio * 32767).astype(np.int16).tobytes())
    return buf.getvalue()


def transcribe_chunk(audio: np.ndarray) -> tuple[str, str]:
    """Returns (transcript, language_code)."""
    wav_bytes = audio_to_wav_bytes(audio)
    response = requests.post(
        SARVAM_STT_URL,
        headers={"api-subscription-key": SARVAM_API_KEY},
        files={"file": ("chunk.wav", wav_bytes, "audio/wav")},
        data={"language_code": "unknown", "model": "saarika:v2.5"},
    )
    if not response.ok:
        return f"[STT error {response.status_code}]", "unknown"
    data = response.json()
    return data.get("transcript", "").strip(), data.get("language_code", "unknown")


def translate_to_english(text: str, source_lang: str) -> str:
    source_bcp47 = LANGUAGE_MAP.get(source_lang, source_lang)
    if source_bcp47 in ("en-IN", "en", "unknown"):
        return text

    response = requests.post(
        SARVAM_TRANSLATE_URL,
        headers={
            "api-subscription-key": SARVAM_API_KEY,
            "Content-Type": "application/json",
        },
        json={
            "input": text,
            "source_language_code": source_bcp47,
            "target_language_code": "en-IN",
            "model": "mayura:v1",
        },
    )
    if not response.ok:
        return f"[Translation error {response.status_code}]"
    return response.json().get("translated_text", "").strip()


def generate_summary(conversation: str) -> str:
    prompt = (
        "Below is a conversation transcript. Write a concise summary in English "
        "covering the main topics discussed, key points, and any decisions made.\n\n"
        f"Conversation:\n{conversation}\n\nSummary:"
    )
    payload = {"model": OLLAMA_MODEL, "prompt": prompt, "stream": False}
    req = Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(req, timeout=120) as resp:
            return json.loads(resp.read()).get("response", "").strip()
    except Exception as exc:
        return f"[Summary error: {exc}]"


def main() -> None:
    print(f"Listening... (recording in {CHUNK_SECONDS}s chunks, Ctrl+C to stop)\n")
    all_transcripts: list[str] = []
    detected_lang = "unknown"

    try:
        while True:
            audio = sd.rec(
                int(CHUNK_SECONDS * SAMPLE_RATE),
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype="float32",
            )
            sd.wait()

            transcript, lang = transcribe_chunk(audio.flatten())
            if not transcript or transcript.startswith("["):
                continue

            if lang != "unknown":
                detected_lang = lang

            translation = translate_to_english(transcript, lang)
            all_transcripts.append(transcript)

            print(f"[{lang}] {transcript}")
            if translation and translation != transcript:
                print(f"  → {translation}")

    except KeyboardInterrupt:
        print("\n\nStopped.")

    if all_transcripts:
        print("\n" + "=" * 50)
        print("CONVERSATION SUMMARY")
        print("=" * 50)
        full_conversation = " ".join(all_transcripts)
        print(generate_summary(full_conversation))
    else:
        print("No speech was detected.")


if __name__ == "__main__":
    main()
