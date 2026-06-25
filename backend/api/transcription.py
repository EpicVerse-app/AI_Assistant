import io
import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydub import AudioSegment
from pydub.exceptions import CouldntDecodeError
from sqlalchemy.orm import Session

from database.db import SessionLocal, get_db
from database.models import Meeting, MeetingStatus
from services.meeting_storage import (
    MEETINGS_ROOT,
    delete_meeting_folder,
    init_metadata,
    load_error_message,
    load_mom_json,
    load_mom_markdown,
    meeting_dir,
)
from utils.datetime_format import local_wall_clock, utc_epoch_ms, utc_iso
from services.pipeline import process_meeting

router = APIRouter(prefix="/transcription", tags=["Transcription"])

UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)


def _convert_to_wav(src: Path, dest: Path) -> None:
    """Convert any audio file to 16 kHz mono 16-bit WAV and save to dest."""
    audio = AudioSegment.from_file(str(src))
    audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
    audio.export(str(dest), format="wav")


def _process_transcription(meeting_id: str, audio_path: Path) -> None:
    db = SessionLocal()
    try:
        process_meeting(meeting_id, audio_path, db)
    finally:
        db.close()


def _meeting_list_item(m: Meeting) -> dict:
    local_dt = local_wall_clock(m.created_at, m.timezone_offset_minutes)
    return {
        "meeting_id": m.meeting_id,
        "status": m.status,
        "language": m.language,
        "created_at": utc_iso(m.created_at),
        "created_at_ms": utc_epoch_ms(m.created_at),
        "meeting_date": local_dt.strftime("%Y-%m-%d"),
        "meeting_time": local_dt.strftime("%H:%M"),
        "duration_seconds": m.duration_seconds,
    }


@router.post("/upload")
async def upload_audio(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    client_id: str = Form(None),
    timezone_offset_minutes: int = Form(None),
    db: Session = Depends(get_db),
):
    meeting_id = str(uuid.uuid4())

    # Save the original upload to a temp path first
    original_suffix = Path(file.filename).suffix or ".audio"
    tmp_path = UPLOADS_DIR / f"{meeting_id}_original{original_suffix}"
    with open(tmp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Convert to standard WAV and remove the original
    wav_path = UPLOADS_DIR / f"{meeting_id}.wav"
    try:
        _convert_to_wav(tmp_path, wav_path)
    except CouldntDecodeError as e:
        tmp_path.unlink(missing_ok=True)
        raise HTTPException(
            status_code=422,
            detail=(
                "Audio file could not be decoded — it may be incomplete or still recording. "
                "Please ensure the recording is fully stopped before uploading. "
                f"Detail: {e}"
            ),
        )
    finally:
        tmp_path.unlink(missing_ok=True)

    meeting = Meeting(
        meeting_id=meeting_id,
        client_id=client_id,
        audio_filename=str(wav_path),
        timezone_offset_minutes=timezone_offset_minutes,
        status=MeetingStatus.uploaded,
    )
    db.add(meeting)
    db.commit()

    init_metadata(meeting_id, audio_path=str(wav_path))

    background_tasks.add_task(_process_transcription, meeting_id, wav_path)

    return {
        "meeting_id": meeting_id,
        "status": "uploaded",
        "message": "Audio converted to WAV and transcription started.",
        "wav_filename": wav_path.name,
    }


@router.get("/{meeting_id}/audio/info")
def get_audio_info(meeting_id: str, db: Session = Depends(get_db)):
    """Return metadata about the saved WAV recording."""
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if not meeting.audio_filename:
        raise HTTPException(status_code=404, detail="Audio file not available.")

    audio_file = Path(meeting.audio_filename)
    if not audio_file.exists():
        raise HTTPException(status_code=404, detail="Audio file not found on disk.")

    audio = AudioSegment.from_file(str(audio_file))
    size_kb = round(audio_file.stat().st_size / 1024, 1)

    return {
        "meeting_id": meeting_id,
        "filename": audio_file.name,
        "format": "WAV (16 kHz, mono, 16-bit PCM)",
        "duration_seconds": round(len(audio) / 1000, 2),
        "channels": audio.channels,
        "frame_rate_hz": audio.frame_rate,
        "file_size_kb": size_kb,
        "actions": {
            "play":   f"/transcription/{meeting_id}/audio/play",
            "download": f"/transcription/{meeting_id}/audio/play",
            "delete": f"/transcription/{meeting_id}/audio",
        },
    }


@router.get("/{meeting_id}/audio/play")
def play_audio(meeting_id: str, db: Session = Depends(get_db)):
    """Stream the saved WAV file so the client can play it back."""
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if not meeting.audio_filename:
        raise HTTPException(status_code=404, detail="Audio file not available.")

    audio_file = Path(meeting.audio_filename)
    if not audio_file.exists():
        raise HTTPException(status_code=404, detail="Audio file not found on disk.")

    def _iter_file():
        with open(audio_file, "rb") as f:
            while chunk := f.read(65536):
                yield chunk

    return StreamingResponse(
        _iter_file(),
        media_type="audio/wav",
        headers={
            "Content-Disposition": f'inline; filename="{audio_file.name}"',
            "Content-Length": str(audio_file.stat().st_size),
            "Accept-Ranges": "bytes",
        },
    )


@router.get("/list/all")
def list_meetings(db: Session = Depends(get_db)):
    """Return all meetings sorted newest first, with a MoM preview snippet."""
    meetings = (
        db.query(Meeting)
        .order_by(Meeting.created_at.desc())
        .all()
    )
    results = []
    for m in meetings:
        summary_preview = None
        mom_data = load_mom_json(m.meeting_id)
        markdown = load_mom_markdown(m.meeting_id)

        if markdown:
            summary_preview = markdown[:200] + ("…" if len(markdown) > 200 else "")
        elif m.mom_path and Path(m.mom_path).exists():
            full = Path(m.mom_path).read_text(encoding="utf-8").strip()
            summary_preview = full[:200] + ("…" if len(full) > 200 else "")

        transcript_preview = None
        folder_transcript = meeting_dir(m.meeting_id) / "transcript.txt"
        if folder_transcript.exists():
            full_t = folder_transcript.read_text(encoding="utf-8").strip()
            transcript_preview = full_t[:150] + ("…" if len(full_t) > 150 else "")
        elif m.transcript_path and Path(m.transcript_path).exists():
            full_t = Path(m.transcript_path).read_text(encoding="utf-8").strip()
            transcript_preview = full_t[:150] + ("…" if len(full_t) > 150 else "")

        has_summary = markdown is not None or (m.mom_path is not None and Path(m.mom_path).exists())
        topic = mom_data.get("meeting_topic") if mom_data else None
        item = _meeting_list_item(m)
        item.update({
            "meeting_topic": topic,
            "summary_preview": summary_preview,
            "transcript_preview": transcript_preview,
            "has_summary": has_summary,
            "output_folder": str(meeting_dir(m.meeting_id)),
        })
        results.append(item)
    return {"meetings": results}


@router.delete("/list/all")
def delete_all_meetings(db: Session = Depends(get_db)):
    """Delete every meeting record and its output folder (server audio kept)."""
    meetings = db.query(Meeting).all()
    deleted = 0
    for meeting in meetings:
        delete_meeting_folder(meeting.meeting_id)
        db.delete(meeting)
        deleted += 1
    db.commit()
    return {"deleted": deleted, "message": f"Deleted {deleted} meeting(s)."}


@router.get("/{meeting_id}/detail")
def get_meeting_detail(meeting_id: str, db: Session = Depends(get_db)):
    """Return full meeting data for the detail / MoM screen."""
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    folder = meeting_dir(meeting_id)
    transcript = None
    translation = None
    summary = load_mom_markdown(meeting_id)
    mom = load_mom_json(meeting_id)

    t_file = folder / "transcript.txt"
    if t_file.exists():
        transcript = t_file.read_text(encoding="utf-8").strip()
    elif meeting.transcript_path and Path(meeting.transcript_path).exists():
        transcript = Path(meeting.transcript_path).read_text(encoding="utf-8").strip()

    tr_file = folder / "translation.txt"
    if tr_file.exists():
        translation = tr_file.read_text(encoding="utf-8").strip()
    elif meeting.translation_path and Path(meeting.translation_path).exists():
        translation = Path(meeting.translation_path).read_text(encoding="utf-8").strip()

    if summary is None and meeting.mom_path and Path(meeting.mom_path).exists():
        summary = Path(meeting.mom_path).read_text(encoding="utf-8").strip()

    if mom and meeting.meeting_date:
        if not mom.get("meeting_date") or mom.get("meeting_date") == "Not mentioned":
            mom = {**mom, "meeting_date": meeting.meeting_date}

    local_dt = local_wall_clock(meeting.created_at, meeting.timezone_offset_minutes)

    return {
        "meeting_id": meeting.meeting_id,
        "status": meeting.status,
        "language": meeting.language,
        "created_at": utc_iso(meeting.created_at),
        "created_at_ms": utc_epoch_ms(meeting.created_at),
        "meeting_date": local_dt.strftime("%Y-%m-%d"),
        "meeting_time": local_dt.strftime("%H:%M"),
        "duration_seconds": meeting.duration_seconds,
        "transcript": transcript,
        "translation": translation,
        "summary": summary,
        "mom": mom,
        "error_message": load_error_message(meeting_id),
        "output_folder": str(folder),
    }


@router.get("/{meeting_id}")
def get_transcript(meeting_id: str, db: Session = Depends(get_db)):
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    error_message = load_error_message(meeting_id)

    if meeting.status == MeetingStatus.failed:
        return {
            "meeting_id": meeting_id,
            "status": meeting.status,
            "transcript": None,
            "error_message": error_message
            or "Processing failed. No speech detected or the server could not finish.",
        }

    if meeting.status != MeetingStatus.done:
        return {
            "meeting_id": meeting_id,
            "status": meeting.status,
            "transcript": None,
            "error_message": error_message,
        }

    folder_transcript = meeting_dir(meeting_id) / "transcript.txt"
    if folder_transcript.exists():
        transcript = folder_transcript.read_text(encoding="utf-8")
    elif meeting.transcript_path:
        transcript = Path(meeting.transcript_path).read_text(encoding="utf-8")
    else:
        return {
            "meeting_id": meeting_id,
            "status": meeting.status,
            "transcript": None,
            "error_message": error_message,
        }

    return {
        "meeting_id": meeting_id,
        "status": meeting.status,
        "language": meeting.language,
        "transcript": transcript,
        "error_message": error_message,
    }


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


@router.delete("/{meeting_id}")
def delete_meeting(meeting_id: str, db: Session = Depends(get_db)):
    """Delete meeting record and all artifacts except the server audio file."""
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found.")

    delete_meeting_folder(meeting_id)
    db.delete(meeting)
    db.commit()

    return {
        "meeting_id": meeting_id,
        "message": "Meeting deleted. Audio file was kept.",
    }
