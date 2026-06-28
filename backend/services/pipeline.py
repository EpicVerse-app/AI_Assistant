"""Run transcription → translation → MoM and save everything to the meeting folder."""

import logging
from datetime import datetime

from sqlalchemy.orm import Session

from database.models import Meeting, MeetingStatus
from services.meeting_storage import (
    init_metadata,
    mom_to_markdown,
    save_diarized_transcript,
    save_error_message,
    save_mom,
    save_transcript,
    save_translation,
)
from services.summarizer import (
    _fallback_mom,
    extract_speaker_names,
    generate_mom_structured,
)
from services.transcriber import transcribe_audio
from services.transcript_formatter import build_conversational_transcript
from services.translator import translate_to_english

logger = logging.getLogger(__name__)


from utils.datetime_format import local_wall_clock


def _recording_datetime(meeting: Meeting) -> datetime:
    if meeting.created_at is None:
        return datetime.utcnow()
    return local_wall_clock(meeting.created_at, meeting.timezone_offset_minutes)


def _extract_speaker_names_from_transcript(transcript: str) -> list[str]:
    return extract_speaker_names(transcript)


def _translate_with_fallback(text: str, source_language: str) -> str:
    try:
        return translate_to_english(text, source_language=source_language)
    except Exception as exc:
        logger.warning("Translation failed (%s); using original transcript text.", exc)
        return text


def _generate_mom_with_fallback(
    mom_source: str,
    *,
    recorded_at: datetime,
    plain_transcript: str,
    speaker_names: list[str],
) -> dict:
    try:
        return generate_mom_structured(
            mom_source,
            recorded_at=recorded_at,
            plain_transcript=plain_transcript,
            speaker_names=speaker_names,
        )
    except Exception as exc:
        logger.warning("MoM generation failed (%s); using heuristic fallback.", exc)
        return _fallback_mom(
            mom_source,
            recorded_at=recorded_at,
            speaker_names=speaker_names,
        )


def process_meeting(meeting_id: str, audio_reference: str, db: Session) -> None:
    from services.storage import get_audio_storage

    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        return

    storage = get_audio_storage()

    try:
        meeting.status = MeetingStatus.processing
        db.commit()

        init_metadata(meeting_id, audio_path=audio_reference)

        recorded_at = _recording_datetime(meeting)
        meeting.meeting_date = recorded_at.strftime("%Y-%m-%d")
        meeting.meeting_time = recorded_at.strftime("%H:%M")
        db.commit()

        with storage.local_path(meeting_id, audio_reference) as audio_path:
            result = transcribe_audio(audio_path, print_output=False)
        if not result.transcript.strip():
            save_error_message(
                meeting_id,
                "No speech was detected in the recording. Try speaking closer to the "
                "microphone and record for at least a few seconds.",
            )
            meeting.status = MeetingStatus.failed
            db.commit()
            return

        conversational = build_conversational_transcript(result.diarized_transcript)
        display_transcript = conversational or result.diarized_transcript or result.transcript

        transcript_path = save_transcript(meeting_id, display_transcript, result.language)
        meeting.language = result.language
        meeting.transcript_path = transcript_path

        if result.diarized_transcript:
            save_diarized_transcript(meeting_id, result.diarized_transcript)

        # 2. Translate — fall back to original language if Sarvam translate fails
        translation_source = result.transcript
        translation = _translate_with_fallback(
            translation_source,
            result.language or "unknown",
        )
        translation_path = save_translation(meeting_id, translation)
        meeting.translation_path = translation_path

        # 3. Generate structured MoM — fall back to heuristic summary if LLM fails
        source_text = translation if translation.strip() else result.transcript
        mom_source = display_transcript if conversational else (result.diarized_transcript or source_text)
        speaker_names = _extract_speaker_names_from_transcript(display_transcript)
        mom_data = _generate_mom_with_fallback(
            mom_source,
            recorded_at=recorded_at,
            plain_transcript=source_text,
            speaker_names=speaker_names,
        )
        mom_data["meeting_date"] = meeting.meeting_date
        markdown = mom_to_markdown(mom_data)
        _, mom_md_path = save_mom(meeting_id, mom_data, markdown)

        meeting.mom_path = mom_md_path
        meeting.status = MeetingStatus.done
        db.commit()

    except Exception as exc:
        logger.exception("Pipeline failed for meeting %s", meeting_id)
        save_error_message(
            meeting_id,
            f"Processing failed: {exc}",
        )
        meeting.status = MeetingStatus.failed
        db.commit()
