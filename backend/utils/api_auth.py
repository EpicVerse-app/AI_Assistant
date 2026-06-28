"""Optional API key authentication for production deployments."""

from __future__ import annotations

import os

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

_PUBLIC_PREFIXES = ("/health", "/docs", "/redoc", "/openapi.json")


def _extract_api_key(request: Request) -> str:
    return request.headers.get("X-API-Key", "").strip()


def _is_public_path(path: str) -> bool:
    if path == "/":
        return True
    if path.startswith("/auth"):
        return True
    return any(path == prefix or path.startswith(f"{prefix}/") for prefix in _PUBLIC_PREFIXES)


def is_api_key_required() -> bool:
    configured = os.environ.get("API_KEY", "").strip()
    if not configured:
        return False
    flag = os.environ.get("REQUIRE_API_KEY", "true").strip().lower()
    return flag not in ("0", "false", "no", "off")


class ApiKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        expected = os.environ.get("API_KEY", "").strip()
        if not expected or not is_api_key_required() or _is_public_path(request.url.path):
            return await call_next(request)

        if _extract_api_key(request) != expected:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid or missing API key."},
            )
        return await call_next(request)
