import io
import shutil
import tempfile
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydub import AudioSegment
from pydub.exceptions import CouldntDecodeError
from sqlalchemy.orm import Session

from database.db import SessionLocal, get_db
from database.models import Meeting, MeetingStatus, User
from services.meeting_storage import (
    delete_meeting_folder,
    init_metadata,
    load_error_message,
    load_mom_json,
    load_mom_markdown,
    meeting_dir,
    read_transcript,
    read_translation,
)
from services.storage import get_audio_storage
from services.storage.base import AudioStorage
from utils.datetime_format import local_wall_clock, utc_epoch_ms, utc_iso
from utils.jwt_auth import get_current_user
from utils.meetings import get_owned_meeting
from services.pipeline import process_meeting

router = APIRouter(prefix="/transcription", tags=["Transcription"])

_UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads"
_UPLOADS_DIR.mkdir(parents=True, exist_ok=True)


def _convert_to_wav_bytes(src: Path) -> bytes:
    audio = AudioSegment.from_file(str(src))
    audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
    buf = io.BytesIO()
    audio.export(buf, format="wav")
    return buf.getvalue()


def _process_transcription(meeting_id: str, audio_reference: str) -> None:
    db = SessionLocal()
    try:
        process_meeting(meeting_id, audio_reference, db)
    finally:
        db.close()


def _require_audio(meeting: Meeting) -> tuple[AudioStorage, str]:
    if not meeting.audio_filename:
        raise HTTPException(status_code=404, detail="Audio file not available.")
    storage = get_audio_storage()
    if not storage.exists(meeting.meeting_id, meeting.audio_filename):
        raise HTTPException(status_code=404, detail="Audio file not found in storage.")
    return storage, meeting.audio_filename


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
    current_user: User = Depends(get_current_user),
):
    meeting_id = str(uuid.uuid4())
    storage = get_audio_storage()

    original_suffix = Path(file.filename or "audio").suffix or ".audio"
    with tempfile.TemporaryDirectory(prefix="upload_") as tmp_dir:
        tmp_path = Path(tmp_dir) / f"original{original_suffix}"
        with tmp_path.open("wb") as handle:
            shutil.copyfileobj(file.file, handle)

        try:
            wav_bytes = _convert_to_wav_bytes(tmp_path)
        except CouldntDecodeError as e:
            raise HTTPException(
                status_code=422,
                detail=(
                    "Audio file could not be decoded — it may be incomplete or still recording. "
                    "Please ensure the recording is fully stopped before uploading. "
                    f"Detail: {e}"
                ),
            ) from e

    audio_reference = storage.save_wav(meeting_id, wav_bytes)

    meeting = Meeting(
        meeting_id=meeting_id,
        user_id=current_user.user_id,
        client_id=client_id,
        audio_filename=audio_reference,
        timezone_offset_minutes=timezone_offset_minutes,
        status=MeetingStatus.uploaded,
    )
    db.add(meeting)
    db.commit()

    init_metadata(meeting_id, audio_path=audio_reference)
    background_tasks.add_task(_process_transcription, meeting_id, audio_reference)

    return {
        "meeting_id": meeting_id,
        "status": "uploaded",
        "message": "Audio converted to WAV and transcription started.",
        "wav_filename": AudioStorage.display_filename(meeting_id),
    }


@router.get("/{meeting_id}/audio/info")
def get_audio_info(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    storage, audio_reference = _require_audio(meeting)
    meta = storage.head(meeting_id, audio_reference)
    wav_bytes = storage.read_bytes(meeting_id, audio_reference)
    audio = AudioSegment.from_file(io.BytesIO(wav_bytes))
    size_kb = round(meta["size_bytes"] / 1024, 1)

    filename = AudioStorage.display_filename(meeting_id)
    return {
        "meeting_id": meeting_id,
        "filename": filename,
        "format": "WAV (16 kHz, mono, 16-bit PCM)",
        "duration_seconds": round(len(audio) / 1000, 2),
        "channels": audio.channels,
        "frame_rate_hz": audio.frame_rate,
        "file_size_kb": size_kb,
        "actions": {
            "play": f"/transcription/{meeting_id}/audio/play",
            "download": f"/transcription/{meeting_id}/audio/play",
            "delete": f"/transcription/{meeting_id}/audio",
        },
    }


@router.get("/{meeting_id}/audio/play")
def play_audio(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    storage, audio_reference = _require_audio(meeting)
    meta = storage.head(meeting_id, audio_reference)
    filename = AudioStorage.display_filename(meeting_id)

    return StreamingResponse(
        storage.stream(meeting_id, audio_reference),
        media_type="audio/wav",
        headers={
            "Content-Disposition": f'inline; filename="{filename}"',
            "Content-Length": str(meta["size_bytes"]),
            "Accept-Ranges": "bytes",
        },
    )


@router.get("/list/all")
def list_meetings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meetings = (
        db.query(Meeting)
        .filter(Meeting.user_id == current_user.user_id)
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

        transcript_preview = None
        full_t = read_transcript(m.meeting_id, m.transcript_path)
        if full_t:
            transcript_preview = full_t.strip()[:150] + (
                "…" if len(full_t.strip()) > 150 else ""
            )

        has_summary = markdown is not None or m.mom_path is not None
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
def delete_all_meetings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meetings = (
        db.query(Meeting)
        .filter(Meeting.user_id == current_user.user_id)
        .all()
    )
    deleted = 0
    for meeting in meetings:
        delete_meeting_folder(meeting.meeting_id)
        db.delete(meeting)
        deleted += 1
    db.commit()
    return {"deleted": deleted, "message": f"Deleted {deleted} meeting(s)."}


@router.get("/{meeting_id}/detail")
def get_meeting_detail(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    transcript = read_transcript(meeting_id, meeting.transcript_path)
    translation = read_translation(meeting_id, meeting.translation_path)
    summary = load_mom_markdown(meeting_id)
    mom = load_mom_json(meeting_id)

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
        "transcript": transcript.strip() if transcript else None,
        "translation": translation.strip() if translation else None,
        "summary": summary,
        "mom": mom,
        "error_message": load_error_message(meeting_id),
        "output_folder": str(meeting_dir(meeting_id)),
    }


@router.get("/{meeting_id}")
def get_transcript(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

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

    transcript = read_transcript(meeting_id, meeting.transcript_path)
    if not transcript:
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
def delete_audio(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)
    if meeting.audio_filename:
        get_audio_storage().delete(meeting_id, meeting.audio_filename)
        meeting.audio_filename = None
        db.commit()
    return {"meeting_id": meeting_id, "message": "Audio file deleted."}


@router.delete("/{meeting_id}")
def delete_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    meeting = get_owned_meeting(meeting_id, current_user, db)

    delete_meeting_folder(meeting_id)
    db.delete(meeting)
    db.commit()

    return {
        "meeting_id": meeting_id,
        "message": "Meeting deleted. Audio file was kept.",
    }
