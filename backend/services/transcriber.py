import argparse
import os
from dataclasses import dataclass
from pathlib import Path

import requests

SARVAM_API_URL = "https://api.sarvam.ai/speech-to-text"
SARVAM_API_KEY = os.environ.get("SARVAM_API_KEY", "sk_nkz538vv_VCZFn21xyI6P1Oxo0v8QnsKH")


@dataclass
class TranscriptionResult:
    language: str
    language_probability: float
    transcript: str


def transcribe_audio(audio_path: Path, print_output: bool = True) -> TranscriptionResult:
    if not audio_path.is_file():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    with open(audio_path, "rb") as audio_file:
        response = requests.post(
            SARVAM_API_URL,
            headers={"api-subscription-key": SARVAM_API_KEY},
            files={"file": (audio_path.name, audio_file, "audio/mpeg")},
            data={"language_code": "unknown", "model": "saarika:v2.5"},
        )

    if not response.ok:
        raise RuntimeError(
            f"Sarvam AI API error {response.status_code}: {response.text}"
        )

    data = response.json()
    transcript = data.get("transcript", "").strip()
    language = data.get("language_code", "unknown")

    if print_output:
        print(f"Detected language: {language}")
        print("Transcript:")
        print(transcript if transcript else "[No speech detected]")

    return TranscriptionResult(
        language=language,
        language_probability=1.0,
        transcript=transcript,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Transcribe an audio file using Sarvam AI."
    )
    parser.add_argument("audio", help="Path to the audio file to transcribe")
    args = parser.parse_args()

    transcribe_audio(Path(args.audio).expanduser())


if __name__ == "__main__":
    main()
