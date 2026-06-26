import os
from pathlib import Path

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "database" / "ai_assistant.db"

DEFAULT_SQLITE_URL = f"sqlite:///{DB_PATH}"
DATABASE_URL = os.environ.get("DATABASE_URL", DEFAULT_SQLITE_URL)

_connect_args: dict = {}
if DATABASE_URL.startswith("sqlite"):
    _connect_args["check_same_thread"] = False

engine = create_engine(
    DATABASE_URL,
    connect_args=_connect_args,
    pool_pre_ping=True,
)
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
    """Apply lightweight schema migrations for existing databases."""
    inspector = inspect(engine)
    if not inspector.has_table("meetings"):
        return

    columns = {col["name"] for col in inspector.get_columns("meetings")}
    if "timezone_offset_minutes" in columns:
        return

    with engine.begin() as conn:
        conn.execute(
            text("ALTER TABLE meetings ADD COLUMN timezone_offset_minutes INTEGER")
        )
