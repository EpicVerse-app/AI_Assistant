"""Resolve storage-related environment variables (with legacy aliases)."""

from __future__ import annotations

import os
from typing import Any


def storage_bucket() -> str:
    """Bucket name for S3 audio and meeting artifacts."""
    for key in ("STORAGE_BUCKET", "S3_BUCKET_NAME"):
        value = os.environ.get(key, "").strip()
        if value:
            return value
    return ""


def aws_region(default: str = "us-east-1") -> str:
    for key in ("AWS_REGION", "AWS_DEFAULT_REGION"):
        value = os.environ.get(key, "").strip()
        if value:
            return value
    return default


def boto3_session_kwargs() -> dict[str, Any]:
    kwargs: dict[str, Any] = {"region_name": aws_region()}
    access_key = os.environ.get("AWS_ACCESS_KEY_ID", "").strip()
    secret_key = os.environ.get("AWS_SECRET_ACCESS_KEY", "").strip()
    if access_key:
        kwargs["aws_access_key_id"] = access_key
    if secret_key:
        kwargs["aws_secret_access_key"] = secret_key
    return kwargs


def s3_client():
    import boto3

    endpoint = os.environ.get("AWS_ENDPOINT_URL", "").strip() or None
    session = boto3.session.Session(**boto3_session_kwargs())
    return session.client("s3", endpoint_url=endpoint)


def check_s3_storage() -> tuple[str, str | None]:
    """
    Verify S3 is configured and reachable.
    Returns (status, detail) where status is 'ok', 'skipped', or 'error'.
    """
    backend = os.environ.get("STORAGE_BACKEND", "local").strip().lower()
    if backend != "s3":
        return "skipped", None

    bucket = storage_bucket()
    if not bucket:
        return (
            "error",
            "STORAGE_BUCKET is not set (legacy alias: S3_BUCKET_NAME).",
        )

    try:
        s3_client().head_bucket(Bucket=bucket)
        return "ok", None
    except Exception as exc:
        return "error", str(exc)
