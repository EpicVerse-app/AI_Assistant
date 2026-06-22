"""Load Sarvam API credentials from environment / backend/utils/.env."""

import os
from pathlib import Path

from dotenv import load_dotenv

_ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=_ENV_PATH)


def get_sarvam_api_key() -> str:
    key = os.environ.get("SARVAM_API_KEY", "").strip()
    if not key:
        raise RuntimeError(
            "SARVAM_API_KEY is not set. Add it to backend/utils/.env "
            "(see backend/utils/.env.example)."
        )
    return key
