"""Meeting access checks scoped to the authenticated user."""

from fastapi import HTTPException
from sqlalchemy.orm import Session

from database.models import Meeting, User


def get_owned_meeting(meeting_id: str, user: User, db: Session) -> Meeting:
    meeting = db.query(Meeting).filter(Meeting.meeting_id == meeting_id).first()
    if meeting is None:
        raise HTTPException(status_code=404, detail="Meeting not found.")
    if meeting.user_id is None:
        raise HTTPException(status_code=403, detail="Not allowed to access this meeting.")
    if meeting.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed to access this meeting.")
    return meeting
