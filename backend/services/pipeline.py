"""Run transcription → translation → MoM and save everything to the meeting folder."""

import logging
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session

from database.models import Meeting, MeetingStatus
from services.meeting_storage import (
    init_metadata,
    mom_to_markdown,
    save_diarized_transcript,
    save_mom,
    save_transcript,
    save_translation,
)
from services.summarizer import generate_mom_structured, extract_speaker_names
from services.transcriber import transcribe_audio
from services.transcript_formatter import build_conversational_transcript
from services.translator import translate_to_english

logger = logging.getLogger(__name__)


def _recording_datetime(meeting: Meeting) -> datetime:
    return meeting.created_at or datetime.utcnow()


def _extract_speaker_names_from_transcript(transcript: str) -> list[str]:
    return extract_speaker_names(transcript)


def process_meeting(meeting_id: str, audio_path: Path, db: Session) -> None:
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        return

    try:
        meeting.status = MeetingStatus.processing
        db.commit()

        init_metadata(meeting_id, audio_path=str(audio_path))

        recorded_at = _recording_datetime(meeting)
        meeting.meeting_date = recorded_at.strftime("%Y-%m-%d")
        meeting.meeting_time = recorded_at.strftime("%H:%M")
        db.commit()

        # 1. Transcribe (with speaker diarization for long audio)
        result = transcribe_audio(audio_path, print_output=False)
        if not result.transcript.strip():
            meeting.status = MeetingStatus.failed
            db.commit()
            return

        conversational = build_conversational_transcript(result.diarized_transcript)
        display_transcript = conversational or result.diarized_transcript or result.transcript

        transcript_path = save_transcript(meeting_id, display_transcript, result.language)
        meeting.language = result.language
        meeting.transcript_path = str(transcript_path)

        if result.diarized_transcript:
            save_diarized_transcript(meeting_id, result.diarized_transcript)

        # 2. Translate (use plain/full text for translation quality)
        translation_source = result.transcript
        translation = translate_to_english(
            translation_source,
            source_language=result.language or "unknown",
        )
        translation_path = save_translation(meeting_id, translation)
        meeting.translation_path = str(translation_path)

        # 3. Generate structured MoM
        source_text = translation if translation.strip() else result.transcript
        mom_source = display_transcript if conversational else (result.diarized_transcript or source_text)
        speaker_names = _extract_speaker_names_from_transcript(display_transcript)
        mom_data = generate_mom_structured(
            mom_source,
            recorded_at=recorded_at,
            plain_transcript=source_text,
            speaker_names=speaker_names,
        )
        mom_data["meeting_date"] = meeting.meeting_date
        markdown = mom_to_markdown(mom_data)
        mom_json_path, mom_md_path = save_mom(meeting_id, mom_data, markdown)

        meeting.mom_path = str(mom_md_path)
        meeting.status = MeetingStatus.done
        db.commit()

    except Exception:
        logger.exception("Pipeline failed for meeting %s", meeting_id)
        meeting.status = MeetingStatus.failed
        db.commit()
