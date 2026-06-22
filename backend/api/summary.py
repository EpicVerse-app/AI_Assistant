from pathlib import Path

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting
from services.meeting_storage import load_mom_json, load_mom_markdown, mom_to_markdown, save_mom
from services.summarizer import generate_mom_structured, generate_summary, extract_speaker_names

router = APIRouter(prefix="/summary", tags=["Summary"])


class SummaryRequest(BaseModel):
    type: str = "meeting"   # "meeting" or "conversation"


@router.post("/{meeting_id}")
def create_summary(meeting_id: str, body: SummaryRequest, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    text_path = meeting.translation_path or meeting.transcript_path
    if not text_path or not Path(text_path).exists():
        raise HTTPException(status_code=400, detail="No transcript or translation available yet.")

    text = Path(text_path).read_text(encoding="utf-8")
    if not text.strip():
        raise HTTPException(status_code=400, detail="Transcript is empty — no speech was detected in the audio.")

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
        meeting.mom_path = str(mom_md_path)
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
def get_summary(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    markdown = load_mom_markdown(meeting_id)
    mom_data = load_mom_json(meeting_id)

    if markdown is None and meeting.mom_path and Path(meeting.mom_path).exists():
        markdown = Path(meeting.mom_path).read_text(encoding="utf-8")

    return {
        "meeting_id": meeting_id,
        "summary": markdown,
        "mom": mom_data,
        "folder": str(Path(__file__).resolve().parent.parent / "outputs" / "meetings" / meeting_id),
    }
