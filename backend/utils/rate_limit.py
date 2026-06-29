"""Rate limiting for auth endpoints (per client IP).

Storage backend is controlled by RATE_LIMIT_STORAGE_URI:
  - memory://              — single-process only; resets on restart (dev default)
  - redis://[:password@]host:6379/0  — shared across all instances (required in prod)

Example (AWS ElastiCache / any Redis):
  RATE_LIMIT_STORAGE_URI=redis://:your_auth_token@your-redis-host:6379/0
"""

from __future__ import annotations

import logging
import os

from slowapi import Limiter
from starlette.requests import Request

logger = logging.getLogger(__name__)

LOGIN_LIMIT = os.environ.get("AUTH_LOGIN_RATE", "5/minute")
REGISTER_LIMIT = os.environ.get("AUTH_REGISTER_RATE", "10/hour")

_storage_uri = os.environ.get("RATE_LIMIT_STORAGE_URI", "memory://")

if _storage_uri == "memory://":
    logger.warning(
        "Rate limiting is using in-memory storage. "
        "Set RATE_LIMIT_STORAGE_URI=redis://... for multi-instance deployments."
    )


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


limiter = Limiter(
    key_func=client_ip,
    default_limits=[],
    storage_uri=_storage_uri,
)
