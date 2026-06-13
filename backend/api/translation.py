from pathlib import Path

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting, MeetingStatus
from services.translator import translate_to_english

router = APIRouter(prefix="/translation", tags=["Translation"])

TRANSLATIONS_DIR = Path(__file__).resolve().parent.parent / "outputs" / "translations"
TRANSLATIONS_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/{meeting_id}")
def translate_meeting(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if not meeting.transcript_path or not Path(meeting.transcript_path).exists():
        raise HTTPException(status_code=400, detail="Transcript not available yet.")

    transcript = Path(meeting.transcript_path).read_text(encoding="utf-8")
    translation = translate_to_english(transcript, source_language=meeting.language or "unknown")

    translation_file = TRANSLATIONS_DIR / f"{meeting_id}.txt"
    translation_file.write_text(translation, encoding="utf-8")

    meeting.translation_path = str(translation_file)
    db.commit()

    return {"meeting_id": meeting_id, "translation": translation}


@router.get("/{meeting_id}")
def get_translation(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if not meeting.translation_path or not Path(meeting.translation_path).exists():
        return {"meeting_id": meeting_id, "translation": None}

    translation = Path(meeting.translation_path).read_text(encoding="utf-8")
    return {"meeting_id": meeting_id, "translation": translation}
