import uuid
from datetime import datetime

from sqlalchemy import Column, String, Integer, DateTime, Float, Enum as SAEnum
from sqlalchemy import event
from sqlalchemy.engine import Engine
import sqlite3
import enum

from database.db import Base


class MeetingStatus(str, enum.Enum):
    uploaded = "uploaded"
    processing = "processing"
    done = "done"
    failed = "failed"


@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if isinstance(dbapi_connection, sqlite3.Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


class Meeting(Base):
    __tablename__ = "meetings"

    meeting_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    client_id = Column(String, nullable=True)
    meeting_date = Column(String, nullable=True)       # ISO date string: YYYY-MM-DD
    meeting_time = Column(String, nullable=True)       # HH:MM
    duration_seconds = Column(Integer, nullable=True)
    language = Column(String, nullable=True)
    audio_filename = Column(String, nullable=True)
    transcript_path = Column(String, nullable=True)
    translation_path = Column(String, nullable=True)
    mom_path = Column(String, nullable=True)
    status = Column(SAEnum(MeetingStatus), default=MeetingStatus.uploaded, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
