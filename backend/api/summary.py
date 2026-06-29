from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting, User
from services.meeting_storage import (
    load_mom_json,
    load_mom_markdown,
    mom_to_markdown,
    read_transcript,
    read_translation,
    save_mom,
)
from services.summarizer import generate_mom_structured, generate_summary, extract_speaker_names
from utils.jwt_auth import get_current_user
from utils.meetings import get_owned_meeting

router = APIRouter(prefix="/summary", tags=["Summary"])


class SummaryRequest(BaseModel):
    type: str = "meeting"


@router.post("/{meeting_id}")
def create_summary(
    meeting_id: str,
    body: SummaryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    text = read_translation(meeting_id, meeting.translation_path)
    if not text:
        text = read_transcript(meeting_id, meeting.transcript_path)
    if not text or not text.strip():
        raise HTTPException(
            status_code=400,
            detail="No transcript or translation available yet.",
        )

    if body.type == "meeting":
        speaker_names = extract_speaker_names(text)
        recorded_at = meeting.created_at
        mom_data = generate_mom_structured(
            text,
            recorded_at=recorded_at,
            speaker_names=speaker_names,
        )
        mom_data["meeting_date"] = meeting.meeting_date or mom_data.get("meeting_date")
        markdown = mom_to_markdown(mom_data)
        _, mom_md_path = save_mom(meeting_id, mom_data, markdown)
        meeting.mom_path = mom_md_path
        db.commit()
        return {
            "meeting_id": meeting_id,
            "type": body.type,
            "summary": markdown,
            "mom": mom_data,
        }

    result = generate_summary(text)
    return {"meeting_id": meeting_id, "type": body.type, "summary": result}


@router.get("/{meeting_id}")
def get_summary(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_owned_meeting(meeting_id, current_user, db)

    markdown = load_mom_markdown(meeting_id)
    mom_data = load_mom_json(meeting_id)

    return {
        "meeting_id": meeting_id,
        "summary": markdown,
        "mom": mom_data,
    }
