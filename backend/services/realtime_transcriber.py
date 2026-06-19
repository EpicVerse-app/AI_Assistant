"""
Real-time transcription using Sarvam AI.
Records audio from the microphone in 5-second chunks, transcribes each chunk,
shows an English translation, and prints a conversation summary on exit.
Press Ctrl+C to stop.
"""

import io
import json
import os
import sys
import wave
from datetime import datetime
from urllib.request import Request, urlopen

import numpy as np
import requests
import sounddevice as sd

# ── Terminal colour helpers ──────────────────────────────────────────────────
_USE_COLOR = sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text

def _step(icon: str, label: str, detail: str = "") -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"  {_c('90', ts)}  {icon}  {_c('1', label)}"
    if detail:
        line += f"  {_c('90', detail)}"
    print(line)

def _header(text: str) -> None:
    bar = "─" * 54
    print(f"\n{_c('36;1', bar)}")
    print(f"  {_c('36;1', text)}")
    print(f"{_c('36;1', bar)}\n")

def _result(label: str, text: str) -> None:
    print(f"  {_c('33', label + ':')}  {text}")

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
    _header(f"AI ASSISTANT  —  Real-time Transcription")
    print(f"  Chunk size : {CHUNK_SECONDS}s   |   Sample rate : {SAMPLE_RATE} Hz")
    print(f"  Model      : saarika:v2.5 (STT)  |  mayura:v1 (translate)")
    print(f"  Press  Ctrl+C  to stop and generate summary\n")

    all_transcripts: list[str] = []
    chunk_num = 0

    try:
        while True:
            chunk_num += 1
            print()
            _step("🎙 ", "RECORDING AUDIO",
                  f"chunk #{chunk_num}  ({CHUNK_SECONDS}s)")

            audio = sd.rec(
                int(CHUNK_SECONDS * SAMPLE_RATE),
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype="float32",
            )
            sd.wait()
            _step("✅", "AUDIO CAPTURED",
                  f"{len(audio):,} samples  |  {CHUNK_SECONDS}s @ {SAMPLE_RATE} Hz")

            _step("💾", "SAVING AUDIO",  "encoding → WAV (16-bit PCM, mono)")
            wav_bytes = audio_to_wav_bytes(audio.flatten())
            _step("✅", "AUDIO SAVED",   f"{len(wav_bytes):,} bytes in memory")

            _step("📡", "TRANSCRIBING",  "sending to Sarvam AI  (saarika:v2.5) …")
            wav_buf = io.BytesIO(wav_bytes)
            response = requests.post(
                SARVAM_STT_URL,
                headers={"api-subscription-key": SARVAM_API_KEY},
                files={"file": ("chunk.wav", wav_buf, "audio/wav")},
                data={"language_code": "unknown", "model": "saarika:v2.5"},
            )

            if not response.ok:
                _step("❌", "TRANSCRIPTION FAILED",
                      f"HTTP {response.status_code}")
                continue

            data = response.json()
            transcript = data.get("transcript", "").strip()
            lang = data.get("language_code", "unknown")

            if not transcript:
                _step("⚠️ ", "NO SPEECH DETECTED", "skipping chunk")
                continue

            _step("✅", "TRANSCRIPTION DONE", f"language detected → {lang.upper()}")
            _result("Transcript", _c("97", transcript))

            lang_bcp47 = LANGUAGE_MAP.get(lang, lang)
            if lang_bcp47 not in ("en-IN", "en", "unknown"):
                _step("🌐", "TRANSLATING",
                      f"{lang.upper()} → English  (Sarvam mayura:v1) …")
                trans_resp = requests.post(
                    SARVAM_TRANSLATE_URL,
                    headers={
                        "api-subscription-key": SARVAM_API_KEY,
                        "Content-Type": "application/json",
                    },
                    json={
                        "input": transcript,
                        "source_language_code": lang_bcp47,
                        "target_language_code": "en-IN",
                        "model": "mayura:v1",
                    },
                )
                if trans_resp.ok:
                    translation = trans_resp.json().get("translated_text", "").strip()
                    _step("✅", "TRANSLATION DONE")
                    _result("Translation", _c("97", translation))
                else:
                    translation = transcript
                    _step("❌", "TRANSLATION FAILED",
                          f"HTTP {trans_resp.status_code}")
            else:
                translation = transcript
                _step("⏭ ", "TRANSLATION SKIPPED", "already in English")

            all_transcripts.append(transcript)
            _step("💬", "ADDED TO CONVERSATION LOG",
                  f"{len(all_transcripts)} chunk(s) recorded so far")

    except KeyboardInterrupt:
        print(f"\n\n  {_c('33;1', 'Recording stopped by user.')}")

    if all_transcripts:
        _header("GENERATING CONVERSATION SUMMARY")
        _step("🤖", "SENDING TO OLLAMA",
              f"model: {OLLAMA_MODEL}  |  {len(all_transcripts)} chunk(s)")
        full_conversation = " ".join(all_transcripts)
        summary = generate_summary(full_conversation)
        _step("✅", "SUMMARY READY")
        print()
        print(_c("92", summary))
        print()
    else:
        print(f"\n  {_c('33', 'No speech was detected — nothing to summarise.')}\n")


if __name__ == "__main__":
    main()
