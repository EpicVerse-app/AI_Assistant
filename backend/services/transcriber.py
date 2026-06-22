import argparse
import io
import json
import logging
import shutil
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import requests
from pydub import AudioSegment
from sarvamai import SarvamAI

from utils.sarvam_config import get_sarvam_api_key

logger = logging.getLogger(__name__)

SARVAM_API_URL = "https://api.sarvam.ai/speech-to-text"
CHUNK_MS = 30_000  # Sarvam sync STT max duration per request
BATCH_MODEL = "saaras:v3"
SYNC_MODEL = "saaras:v3"


@dataclass
class TranscriptionResult:
    language: str
    language_probability: float
    transcript: str
    diarized_transcript: str | None = None


def _get_client() -> SarvamAI:
    return SarvamAI(api_subscription_key=get_sarvam_api_key())


def _load_normalized_audio(audio_path: Path) -> AudioSegment:
    audio = AudioSegment.from_file(str(audio_path))
    return audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)


def _chunk_to_wav_bytes(chunk: AudioSegment) -> bytes:
    buf = io.BytesIO()
    chunk.export(buf, format="wav")
    return buf.getvalue()


def _format_diarized_entries(entries: list[dict]) -> str:
    lines: list[str] = []
    for entry in entries:
        speaker_id = entry.get("speaker_id", "?")
        text = (entry.get("transcript") or "").strip()
        if not text:
            continue
        try:
            label = f"Speaker {int(speaker_id) + 1}"
        except (TypeError, ValueError):
            label = f"Speaker {speaker_id}"
        lines.append(f"{label}: {text}")
    return "\n\n".join(lines)


def _parse_batch_json(data: dict) -> tuple[str, str, str | None]:
    transcript = (data.get("transcript") or "").strip()
    language = data.get("language_code") or "unknown"
    diarized_transcript: str | None = None

    diarized = data.get("diarized_transcript") or {}
    entries = diarized.get("entries") or []
    if entries:
        diarized_transcript = _format_diarized_entries(entries)
        if not transcript:
            transcript = " ".join(
                (entry.get("transcript") or "").strip()
                for entry in entries
                if entry.get("transcript")
            ).strip()

    if not transcript:
        timestamps = data.get("timestamps") or {}
        chunks = timestamps.get("chunks") or []
        if chunks:
            transcript = " ".join(str(c).strip() for c in chunks if str(c).strip()).strip()

    return transcript, language, diarized_transcript


def _read_batch_output(output_dir: Path) -> tuple[str, str, str | None]:
    json_files = sorted(output_dir.glob("*.json"))
    if not json_files:
        raise RuntimeError(f"No batch output JSON found in {output_dir}")

    transcripts: list[str] = []
    diarized_parts: list[str] = []
    languages: list[str] = []

    for json_file in json_files:
        data = json.loads(json_file.read_text(encoding="utf-8"))
        text, lang, diarized = _parse_batch_json(data)
        if text:
            transcripts.append(text)
            languages.append(lang)
        if diarized:
            diarized_parts.append(diarized)

    if not transcripts:
        return "", languages[0] if languages else "unknown", None

    dominant = Counter(languages).most_common(1)[0][0] if languages else "unknown"
    diarized_transcript = "\n\n".join(diarized_parts) if diarized_parts else None
    return " ".join(transcripts), dominant, diarized_transcript


def _transcribe_batch(audio_path: Path) -> TranscriptionResult:
    client = _get_client()
    output_dir = Path(tempfile.mkdtemp(prefix="sarvam_batch_"))

    try:
        logger.info("Starting Sarvam batch transcription for %s", audio_path.name)
        job = client.speech_to_text_job.create_job(
            model=BATCH_MODEL,
            mode="transcribe",
            language_code="unknown",
            with_diarization=True,
            num_speakers=4,
        )
        job.upload_files(file_paths=[str(audio_path)])
        job.start()
        job.wait_until_complete()

        file_results = job.get_file_results()
        failed = file_results.get("failed") or []
        if failed:
            message = failed[0].get("error_message") or "Batch transcription failed"
            raise RuntimeError(message)

        successful = file_results.get("successful") or []
        if not successful:
            raise RuntimeError("Batch transcription returned no successful files")

        job.download_outputs(output_dir=str(output_dir))
        transcript, language, diarized_transcript = _read_batch_output(output_dir)

        return TranscriptionResult(
            language=language,
            language_probability=1.0,
            transcript=transcript,
            diarized_transcript=diarized_transcript,
        )
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def _transcribe_sync_sdk(audio_path: Path) -> TranscriptionResult:
    client = _get_client()
    with open(audio_path, "rb") as audio_file:
        response = client.speech_to_text.transcribe(
            file=audio_file,
            model=SYNC_MODEL,
            mode="transcribe",
            language_code="unknown",
        )

    transcript = (getattr(response, "transcript", None) or "").strip()
    language = getattr(response, "language_code", None) or "unknown"

    if not transcript and hasattr(response, "model_dump"):
        data = response.model_dump()
        transcript, language, diarized_transcript = _parse_batch_json(data)
    else:
        diarized_transcript = None

    return TranscriptionResult(
        language=language,
        language_probability=1.0,
        transcript=transcript,
        diarized_transcript=diarized_transcript,
    )


def _transcribe_sync_rest(wav_bytes: bytes) -> tuple[str, str]:
    """Fallback sync REST call using raw WAV bytes."""
    response = requests.post(
        SARVAM_API_URL,
        headers={"api-subscription-key": get_sarvam_api_key()},
        files={"file": ("audio.wav", wav_bytes, "audio/wav")},
        data={"language_code": "unknown", "model": SYNC_MODEL},
    )
    if not response.ok:
        raise RuntimeError(
            f"Sarvam AI API error {response.status_code}: {response.text}"
        )
    data = response.json()
    return data.get("transcript", "").strip(), data.get("language_code", "unknown")


def transcribe_audio(audio_path: Path, print_output: bool = True) -> TranscriptionResult:
    if not audio_path.is_file():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    audio = _load_normalized_audio(audio_path)
    duration_ms = len(audio)

    if duration_ms <= CHUNK_MS:
        try:
            result = _transcribe_sync_sdk(audio_path)
        except Exception as exc:
            logger.warning("SDK sync transcribe failed, using REST fallback: %s", exc)
            transcript, language = _transcribe_sync_rest(_chunk_to_wav_bytes(audio))
            result = TranscriptionResult(
                language=language,
                language_probability=1.0,
                transcript=transcript,
            )
    else:
        result = _transcribe_batch(audio_path)

    if print_output:
        print(f"Detected language: {result.language}")
        print("Transcript:")
        print(result.transcript if result.transcript else "[No speech detected]")

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Transcribe an audio file using Sarvam AI."
    )
    parser.add_argument("audio", help="Path to the audio file to transcribe")
    args = parser.parse_args()

    transcribe_audio(Path(args.audio).expanduser())


if __name__ == "__main__":
    main()
