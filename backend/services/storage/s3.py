"""Amazon S3 (or S3-compatible) audio storage."""

from __future__ import annotations

import os
import shutil
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from services.storage.base import AudioStorage


class S3AudioStorage(AudioStorage):
    def __init__(
        self,
        bucket: str,
        *,
        prefix: str = "audio",
        region: str | None = None,
        endpoint_url: str | None = None,
    ) -> None:
        import boto3

        self._bucket = bucket
        self._prefix = prefix.strip("/")
        session = boto3.session.Session(
            region_name=region or os.environ.get("AWS_REGION", "us-east-1"),
            aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID") or None,
            aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY") or None,
        )
        self._client = session.client("s3", endpoint_url=endpoint_url or None)

    def _key(self, meeting_id: str, stored_reference: str) -> str:
        ref = stored_reference.strip()
        if ref and not self.is_legacy_local_path(ref):
            return ref
        return self.object_key(meeting_id, self._prefix)

    def save_wav(self, meeting_id: str, data: bytes) -> str:
        key = self.object_key(meeting_id, self._prefix)
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=data,
            ContentType="audio/wav",
        )
        return key

    def exists(self, meeting_id: str, stored_reference: str) -> bool:
        key = self._key(meeting_id, stored_reference)
        try:
            self._client.head_object(Bucket=self._bucket, Key=key)
            return True
        except self._client.exceptions.ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code in ("404", "NoSuchKey", "NotFound"):
                return False
            raise

    def read_bytes(self, meeting_id: str, stored_reference: str) -> bytes:
        key = self._key(meeting_id, stored_reference)
        response = self._client.get_object(Bucket=self._bucket, Key=key)
        return response["Body"].read()

    def stream(
        self, meeting_id: str, stored_reference: str, *, chunk_size: int = 65536
    ) -> Iterator[bytes]:
        key = self._key(meeting_id, stored_reference)
        response = self._client.get_object(Bucket=self._bucket, Key=key)
        body = response["Body"]
        try:
            while chunk := body.read(chunk_size):
                yield chunk
        finally:
            body.close()

    def head(self, meeting_id: str, stored_reference: str) -> dict:
        key = self._key(meeting_id, stored_reference)
        response = self._client.head_object(Bucket=self._bucket, Key=key)
        return {
            "size_bytes": int(response["ContentLength"]),
            "content_type": response.get("ContentType", "audio/wav"),
        }

    def delete(self, meeting_id: str, stored_reference: str) -> None:
        key = self._key(meeting_id, stored_reference)
        self._client.delete_object(Bucket=self._bucket, Key=key)

    @contextmanager
    def local_path(self, meeting_id: str, stored_reference: str):
        data = self.read_bytes(meeting_id, stored_reference)
        tmp_dir = tempfile.mkdtemp(prefix="audio_s3_")
        path = Path(tmp_dir) / self.display_filename(meeting_id)
        try:
            path.write_bytes(data)
            yield path
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)
