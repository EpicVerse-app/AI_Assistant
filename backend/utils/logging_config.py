"""Logging configuration.

Switches between JSON (production / CloudWatch) and plain-text (local dev)
based on the LOG_FORMAT environment variable.

  LOG_FORMAT=json   — one JSON object per line; CloudWatch Logs Insights can
                       filter by any field (level, logger, meeting_id, etc.)
  LOG_FORMAT=text   — human-readable; default when unset
  LOG_LEVEL         — DEBUG / INFO / WARNING / ERROR (default: INFO)

Call configure_logging() once at application startup.
"""

from __future__ import annotations

import json
import logging
import os
import traceback


class _JsonFormatter(logging.Formatter):
    """Emit one JSON object per log record."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {
            "time": self.formatTime(record, datefmt="%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Include exception info when present
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        elif record.exc_text:
            payload["exception"] = record.exc_text

        # Carry any extra fields attached by the caller:
        #   logger.info("uploaded", extra={"meeting_id": mid})
        _skip = logging.LogRecord.__dict__.keys() | {
            "message", "asctime", "args", "msg", "exc_info", "exc_text",
            "stack_info", "taskName",
        }
        for key, value in record.__dict__.items():
            if key not in _skip and not key.startswith("_"):
                try:
                    json.dumps(value)   # only include JSON-serialisable extras
                    payload[key] = value
                except (TypeError, ValueError):
                    payload[key] = str(value)

        return json.dumps(payload, ensure_ascii=False)


def configure_logging() -> None:
    log_format = os.environ.get("LOG_FORMAT", "text").strip().lower()
    log_level_name = os.environ.get("LOG_LEVEL", "INFO").strip().upper()
    log_level = getattr(logging, log_level_name, logging.INFO)

    if log_format == "json":
        handler = logging.StreamHandler()
        handler.setFormatter(_JsonFormatter())
    else:
        handler = logging.StreamHandler()
        handler.setFormatter(
            logging.Formatter(
                fmt="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
                datefmt="%Y-%m-%d %H:%M:%S",
            )
        )

    # Configure the root logger; uvicorn's own loggers inherit from here.
    root = logging.getLogger()
    root.setLevel(log_level)
    # Replace any handlers already attached (e.g. uvicorn's default handler)
    root.handlers.clear()
    root.addHandler(handler)

    # Quieten noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
