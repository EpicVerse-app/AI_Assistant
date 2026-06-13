import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, BackgroundTasks
from sqlalchemy.orm import Session

from database.db import get_db
from database.models import Meeting, MeetingStatus
from services.transcriber import transcribe_audio

router = APIRouter(prefix="/transcription", tags=["Transcription"])

UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads"
TRANSCRIPTS_DIR = Path(__file__).resolve().parent.parent / "outputs" / "transcripts"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
TRANSCRIPTS_DIR.mkdir(parents=True, exist_ok=True)


def _process_transcription(meeting_id: str, audio_path: Path, db: Session):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    try:
        meeting.status = MeetingStatus.processing
        db.commit()

        result = transcribe_audio(audio_path, print_output=False)

        transcript_file = TRANSCRIPTS_DIR / f"{meeting_id}.txt"
        transcript_file.write_text(result.transcript, encoding="utf-8")

        meeting.language = result.language
        meeting.transcript_path = str(transcript_file)
        meeting.status = MeetingStatus.done
        db.commit()
    except Exception as exc:
        meeting.status = MeetingStatus.failed
        db.commit()
        raise exc


@router.post("/upload")
async def upload_audio(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    client_id: str = None,
    db: Session = Depends(get_db),
):
    meeting_id = str(uuid.uuid4())
    suffix = Path(file.filename).suffix
    audio_path = UPLOADS_DIR / f"{meeting_id}{suffix}"

    with open(audio_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    meeting = Meeting(
        meeting_id=meeting_id,
        client_id=client_id,
        audio_filename=str(audio_path),
        status=MeetingStatus.uploaded,
    )
    db.add(meeting)
    db.commit()

    background_tasks.add_task(_process_transcription, meeting_id, audio_path, db)

    return {"meeting_id": meeting_id, "status": "uploaded", "message": "Transcription started."}


@router.get("/{meeting_id}")
def get_transcript(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if meeting.status != MeetingStatus.done or not meeting.transcript_path:
        return {"meeting_id": meeting_id, "status": meeting.status, "transcript": None}

    transcript = Path(meeting.transcript_path).read_text(encoding="utf-8")
    return {"meeting_id": meeting_id, "status": meeting.status, "language": meeting.language, "transcript": transcript}


@router.delete("/{meeting_id}/audio")
def delete_audio(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if meeting.audio_filename:
        audio_file = Path(meeting.audio_filename)
        if audio_file.exists():
            audio_file.unlink()
        meeting.audio_filename = None
        db.commit()
    return {"meeting_id": meeting_id, "message": "Audio file deleted."}
