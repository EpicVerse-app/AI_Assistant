"""Storage factory — local filesystem or S3."""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from services.storage.base import AudioStorage
from services.storage.local import LocalAudioStorage
from services.storage.s3 import S3AudioStorage
from utils.storage_env import aws_region, storage_bucket

_BASE_DIR = Path(__file__).resolve().parent.parent.parent


@lru_cache(maxsize=1)
def get_audio_storage() -> AudioStorage:
    backend = os.environ.get("STORAGE_BACKEND", "local").strip().lower()
    prefix = os.environ.get("STORAGE_AUDIO_PREFIX", "audio").strip() or "audio"

    if backend == "s3":
        bucket = storage_bucket()
        if not bucket:
            raise RuntimeError(
                "STORAGE_BACKEND=s3 requires STORAGE_BUCKET "
                "(or legacy S3_BUCKET_NAME)."
            )
        return S3AudioStorage(
            bucket,
            prefix=prefix,
            region=aws_region(),
            endpoint_url=os.environ.get("AWS_ENDPOINT_URL") or None,
        )

    root = os.environ.get("STORAGE_LOCAL_ROOT", "").strip()
    local_root = Path(root) if root else _BASE_DIR / "uploads"
    return LocalAudioStorage(local_root, prefix=prefix)


def storage_backend_name() -> str:
    return os.environ.get("STORAGE_BACKEND", "local").strip().lower() or "local"


__all__ = ["AudioStorage", "get_audio_storage", "storage_backend_name"]
