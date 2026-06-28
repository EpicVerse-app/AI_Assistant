"""Local filesystem audio storage."""

from __future__ import annotations

from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from services.storage.base import AudioStorage


class LocalAudioStorage(AudioStorage):
    def __init__(self, root: Path, *, prefix: str = "audio") -> None:
        self._root = root
        self._prefix = prefix.strip("/")
        self._root.mkdir(parents=True, exist_ok=True)

    def _path_for_key(self, key: str) -> Path:
        return self._root / key

    def _resolve_path(self, meeting_id: str, stored_reference: str) -> Path | None:
        ref = stored_reference.strip()
        if self.is_legacy_local_path(ref):
            legacy = Path(ref)
            if legacy.is_file():
                return legacy
            if ref.startswith("uploads/"):
                candidate = self._root.parent / ref
                if candidate.is_file():
                    return candidate
            legacy_name = self._root / f"{meeting_id}.wav"
            if legacy_name.is_file():
                return legacy_name
        key = ref if ref else self.object_key(meeting_id, self._prefix)
        path = self._path_for_key(key)
        return path if path.is_file() else None

    def save_wav(self, meeting_id: str, data: bytes) -> str:
        key = self.object_key(meeting_id, self._prefix)
        path = self._path_for_key(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return key

    def exists(self, meeting_id: str, stored_reference: str) -> bool:
        return self._resolve_path(meeting_id, stored_reference) is not None

    def read_bytes(self, meeting_id: str, stored_reference: str) -> bytes:
        path = self._resolve_path(meeting_id, stored_reference)
        if path is None:
            raise FileNotFoundError(
                f"Audio not found for meeting {meeting_id}: {stored_reference!r}"
            )
        return path.read_bytes()

    def stream(
        self, meeting_id: str, stored_reference: str, *, chunk_size: int = 65536
    ) -> Iterator[bytes]:
        path = self._resolve_path(meeting_id, stored_reference)
        if path is None:
            raise FileNotFoundError(
                f"Audio not found for meeting {meeting_id}: {stored_reference!r}"
            )
        with path.open("rb") as handle:
            while chunk := handle.read(chunk_size):
                yield chunk

    def head(self, meeting_id: str, stored_reference: str) -> dict:
        path = self._resolve_path(meeting_id, stored_reference)
        if path is None:
            raise FileNotFoundError(
                f"Audio not found for meeting {meeting_id}: {stored_reference!r}"
            )
        return {"size_bytes": path.stat().st_size, "content_type": "audio/wav"}

    def delete(self, meeting_id: str, stored_reference: str) -> None:
        path = self._resolve_path(meeting_id, stored_reference)
        if path is not None:
            path.unlink(missing_ok=True)

    @contextmanager
    def local_path(self, meeting_id: str, stored_reference: str):
        path = self._resolve_path(meeting_id, stored_reference)
        if path is None:
            raise FileNotFoundError(
                f"Audio not found for meeting {meeting_id}: {stored_reference!r}"
            )
        yield path
