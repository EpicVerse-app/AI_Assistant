"""Audio storage abstraction — local filesystem or S3."""

from __future__ import annotations

from abc import ABC, abstractmethod
from contextlib import AbstractContextManager
from pathlib import Path
from typing import Iterator


class AudioStorage(ABC):
    @abstractmethod
    def save_wav(self, meeting_id: str, data: bytes) -> str:
        """Persist WAV bytes; return value to store in Meeting.audio_filename."""

    @abstractmethod
    def exists(self, meeting_id: str, stored_reference: str) -> bool:
        ...

    @abstractmethod
    def read_bytes(self, meeting_id: str, stored_reference: str) -> bytes:
        ...

    @abstractmethod
    def stream(
        self, meeting_id: str, stored_reference: str, *, chunk_size: int = 65536
    ) -> Iterator[bytes]:
        ...

    @abstractmethod
    def head(self, meeting_id: str, stored_reference: str) -> dict:
        """Must include size_bytes (int)."""
        ...

    @abstractmethod
    def delete(self, meeting_id: str, stored_reference: str) -> None:
        ...

    @abstractmethod
    def local_path(
        self, meeting_id: str, stored_reference: str
    ) -> AbstractContextManager[Path]:
        ...

    @staticmethod
    def object_key(meeting_id: str, prefix: str = "audio") -> str:
        return f"{prefix.rstrip('/')}/{meeting_id}.wav"

    @staticmethod
    def display_filename(meeting_id: str) -> str:
        return f"{meeting_id}.wav"

    @staticmethod
    def is_legacy_local_path(stored_reference: str) -> bool:
        ref = stored_reference.strip()
        if not ref:
            return False
        if ref.startswith("/") or ref.startswith("uploads"):
            return True
        path = Path(ref)
        return path.is_absolute() or (path.suffix.lower() == ".wav" and "/" in ref)
