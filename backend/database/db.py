import os
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "database" / "ai_assistant.db"

engine = create_engine(f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from database import models  # noqa: F401 — ensures tables are registered
    Base.metadata.create_all(bind=engine)
    _migrate_schema()


def _migrate_schema():
    """Apply lightweight SQLite migrations for existing databases."""
    with engine.connect() as conn:
        columns = {
            row[1]
            for row in conn.exec_driver_sql("PRAGMA table_info(meetings)").fetchall()
        }
        if "timezone_offset_minutes" not in columns:
            conn.exec_driver_sql(
                "ALTER TABLE meetings ADD COLUMN timezone_offset_minutes INTEGER"
            )
        conn.commit()
