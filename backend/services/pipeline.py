"""Run transcription → translation → MoM and save everything to the meeting folder."""

from pathlib import Path

from sqlalchemy.orm import Session

from database.models import Meeting, MeetingStatus
from services.meeting_storage import (
    init_metadata,
    mom_to_markdown,
    save_mom,
    save_transcript,
    save_translation,
)
from services.summarizer import generate_mom_structured
from services.transcriber import transcribe_audio
from services.translator import translate_to_english


def process_meeting(meeting_id: str, audio_path: Path, db: Session) -> None:
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        return

    try:
        meeting.status = MeetingStatus.processing
        db.commit()

        init_metadata(meeting_id, audio_path=str(audio_path))

        # 1. Transcribe
        result = transcribe_audio(audio_path, print_output=False)
        if not result.transcript.strip():
            meeting.status = MeetingStatus.failed
            db.commit()
            return

        transcript_path = save_transcript(meeting_id, result.transcript, result.language)
        meeting.language = result.language
        meeting.transcript_path = str(transcript_path)

        # 2. Translate
        translation = translate_to_english(
            result.transcript,
            source_language=result.language or "unknown",
        )
        translation_path = save_translation(meeting_id, translation)
        meeting.translation_path = str(translation_path)

        # 3. Generate structured MoM
        source_text = translation if translation.strip() else result.transcript
        mom_data = generate_mom_structured(source_text)
        markdown = mom_to_markdown(mom_data)
        mom_json_path, mom_md_path = save_mom(meeting_id, mom_data, markdown)

        meeting.mom_path = str(mom_md_path)
        meeting.status = MeetingStatus.done
        db.commit()

    except Exception:
        meeting.status = MeetingStatus.failed
        db.commit()
