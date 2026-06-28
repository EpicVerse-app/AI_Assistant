"""In-memory rate limiting for auth endpoints (per client IP)."""

from __future__ import annotations

import os

from slowapi import Limiter
from starlette.requests import Request

LOGIN_LIMIT = os.environ.get("AUTH_LOGIN_RATE", "5/minute")
REGISTER_LIMIT = os.environ.get("AUTH_REGISTER_RATE", "10/hour")


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
    storage_uri=os.environ.get("RATE_LIMIT_STORAGE_URI", "memory://"),
)
