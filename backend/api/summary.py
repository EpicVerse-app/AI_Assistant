from pathlib import Path

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting
from services.summarizer import generate_mom, generate_summary

router = APIRouter(prefix="/summary", tags=["Summary"])

SUMMARIES_DIR = Path(__file__).resolve().parent.parent / "outputs" / "summaries"
SUMMARIES_DIR.mkdir(parents=True, exist_ok=True)


class SummaryRequest(BaseModel):
    type: str = "meeting"   # "meeting" or "conversation"


@router.post("/{meeting_id}")
def create_summary(meeting_id: str, body: SummaryRequest, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    # Prefer the English translation if available, fall back to raw transcript
    text_path = meeting.translation_path or meeting.transcript_path
    if not text_path or not Path(text_path).exists():
        raise HTTPException(status_code=400, detail="No transcript or translation available yet.")

    text = Path(text_path).read_text(encoding="utf-8")

    if body.type == "meeting":
        result = generate_mom(text)
    else:
        result = generate_summary(text)

    mom_file = SUMMARIES_DIR / f"{meeting_id}.md"
    mom_file.write_text(result, encoding="utf-8")

    meeting.mom_path = str(mom_file)
    db.commit()

    return {"meeting_id": meeting_id, "type": body.type, "summary": result}


@router.get("/{meeting_id}")
def get_summary(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if not meeting.mom_path or not Path(meeting.mom_path).exists():
        return {"meeting_id": meeting_id, "summary": None}

    summary = Path(meeting.mom_path).read_text(encoding="utf-8")
    return {"meeting_id": meeting_id, "summary": summary}
