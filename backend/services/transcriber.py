import argparse
import io
from dataclasses import dataclass
from pathlib import Path

import requests
from pydub import AudioSegment

from utils.sarvam_config import get_sarvam_api_key

SARVAM_API_URL = "https://api.sarvam.ai/speech-to-text"


@dataclass
class TranscriptionResult:
    language: str
    language_probability: float
    transcript: str


def _to_wav_bytes(audio_path: Path) -> bytes:
    """Convert any audio file to 16 kHz mono 16-bit WAV in memory via ffmpeg."""
    audio = AudioSegment.from_file(str(audio_path))
    audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
    buf = io.BytesIO()
    audio.export(buf, format="wav")
    return buf.getvalue()


def transcribe_audio(audio_path: Path, print_output: bool = True) -> TranscriptionResult:
    if not audio_path.is_file():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    wav_bytes = _to_wav_bytes(audio_path)

    response = requests.post(
        SARVAM_API_URL,
        headers={"api-subscription-key": get_sarvam_api_key()},
        files={"file": ("audio.wav", wav_bytes, "audio/wav")},
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
