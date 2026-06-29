import os
from pathlib import Path

from sqlalchemy import create_engine
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
    """Run all pending Alembic migrations on startup."""
    import database.models  # noqa: F401 — register models before migration

    from alembic.config import Config
    from alembic import command

    alembic_cfg = Config(BASE_DIR / "alembic.ini")
    alembic_cfg.set_main_option("script_location", str(BASE_DIR / "alembic"))
    command.upgrade(alembic_cfg, "head")
