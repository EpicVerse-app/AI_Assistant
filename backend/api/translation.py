from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting, User
from services.meeting_storage import read_transcript, read_translation, save_translation
from services.translator import translate_to_english
from utils.jwt_auth import get_current_user
from utils.meetings import get_owned_meeting

router = APIRouter(prefix="/translation", tags=["Translation"])


@router.post("/{meeting_id}")
def translate_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    transcript = read_transcript(meeting_id, meeting.transcript_path)
    if not transcript:
        raise HTTPException(status_code=400, detail="Transcript not available yet.")

    translation = translate_to_english(transcript, source_language=meeting.language or "unknown")
    translation_ref = save_translation(meeting_id, translation)
    meeting.translation_path = translation_ref
    db.commit()

    return {"meeting_id": meeting_id, "translation": translation}


@router.get("/{meeting_id}")
def get_translation(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    translation = read_translation(meeting_id, meeting.translation_path)
    return {"meeting_id": meeting_id, "translation": translation}
