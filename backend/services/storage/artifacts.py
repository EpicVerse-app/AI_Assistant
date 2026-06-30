"""Meeting artifact storage — local disk or S3 (transcripts, MoM, metadata)."""

from __future__ import annotations

import json
import os
import shutil
from functools import lru_cache
from pathlib import Path
from typing import Any

from botocore.exceptions import ClientError as _BotocoreClientError

from utils.storage_env import s3_client, storage_bucket

_BASE_DIR = Path(__file__).resolve().parent.parent
MEETINGS_ROOT = _BASE_DIR / "outputs" / "meetings"
MEETINGS_PREFIX = os.environ.get("STORAGE_MEETINGS_PREFIX", "meetings").strip() or "meetings"


def _use_s3() -> bool:
    return os.environ.get("STORAGE_BACKEND", "local").strip().lower() == "s3"


def _object_key(meeting_id: str, filename: str) -> str:
    return f"{MEETINGS_PREFIX.rstrip('/')}/{meeting_id}/{filename}"


@lru_cache(maxsize=1)
def _s3_client():
    return s3_client()


def _bucket() -> str:
    bucket = storage_bucket()
    if not bucket:
        raise RuntimeError(
            "STORAGE_BACKEND=s3 requires STORAGE_BUCKET "
            "(or legacy S3_BUCKET_NAME)."
        )
    return bucket


def _is_legacy_local_path(reference: str) -> bool:
    ref = reference.strip()
    if not ref:
        return False
    if ref.startswith("/") or ref.startswith("outputs"):
        return True
    return Path(ref).is_absolute()


def _resolve_local_path(meeting_id: str, filename: str, reference: str | None) -> Path | None:
    if reference and _is_legacy_local_path(reference):
        path = Path(reference)
        if path.is_file():
            return path
    folder = MEETINGS_ROOT / meeting_id
    path = folder / filename
    return path if path.is_file() else None


def write_text(meeting_id: str, filename: str, content: str) -> str:
    if _use_s3():
        key = _object_key(meeting_id, filename)
        _s3_client().put_object(
            Bucket=_bucket(),
            Key=key,
            Body=content.encode("utf-8"),
            ContentType="text/plain; charset=utf-8",
        )
        return key

    folder = MEETINGS_ROOT / meeting_id
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / filename
    path.write_text(content, encoding="utf-8")
    return str(path)


def read_text(meeting_id: str, filename: str, reference: str | None = None) -> str | None:
    if _use_s3():
        key = reference if reference and not _is_legacy_local_path(reference) else _object_key(
            meeting_id, filename
        )
        try:
            response = _s3_client().get_object(Bucket=_bucket(), Key=key)
            return response["Body"].read().decode("utf-8")
        except _BotocoreClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code in ("404", "NoSuchKey", "NotFound"):
                return None
            raise

    path = _resolve_local_path(meeting_id, filename, reference)
    if path is None:
        return None
    return path.read_text(encoding="utf-8")


def read_json(meeting_id: str, filename: str, reference: str | None = None) -> dict[str, Any] | None:
    raw = read_text(meeting_id, filename, reference)
    if raw is None:
        return None
    return json.loads(raw)


def exists(meeting_id: str, filename: str, reference: str | None = None) -> bool:
    return read_text(meeting_id, filename, reference) is not None


def delete_meeting_prefix(meeting_id: str) -> None:
    if _use_s3():
        prefix = f"{MEETINGS_PREFIX.rstrip('/')}/{meeting_id}/"
        client = _s3_client()
        bucket = _bucket()
        paginator = client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            objects = page.get("Contents") or []
            if not objects:
                continue
            client.delete_objects(
                Bucket=bucket,
                Delete={"Objects": [{"Key": obj["Key"]} for obj in objects]},
            )
        return

    folder = MEETINGS_ROOT / meeting_id
    if folder.exists():
        shutil.rmtree(folder)
