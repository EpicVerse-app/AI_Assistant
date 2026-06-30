import os

from utils.logging_config import configure_logging
configure_logging()

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi import _rate_limit_exceeded_handler
from sqlalchemy import text
from sqlalchemy.orm import Session

from database.db import get_db
from api.auth import router as auth_router
from api.transcription import router as transcription_router
from api.translation import router as translation_router
from api.summary import router as summary_router
from services.storage import storage_backend_name
from utils.storage_env import check_s3_storage
from utils.api_auth import ApiKeyMiddleware
from utils.jwt_auth import get_current_user
from utils.rate_limit import limiter

# 5 hours of audio at the app's normalised format (16 kHz, mono, 16-bit PCM)
# plus 10 % headroom for compressed originals with higher bitrates.
# 5 * 3600 * 16000 * 2 * 1.1 = 633,600,000 bytes (~604 MB)
_5H_WAV_BYTES = 5 * 3600 * 16_000 * 2
MAX_UPLOAD_BYTES: int = int(
    int(os.environ.get("MAX_UPLOAD_BYTES", str(int(_5H_WAV_BYTES * 1.1))))
)

app = FastAPI(
    title="AI Meeting Assistant",
    description="Transcribe, translate and generate MoM for meetings.",
    version="1.0.0",
)

# Auto-migrate on startup so local dev works without running alembic manually.
# In Docker/ECS this is a no-op because the CMD already ran `alembic upgrade head`.
@app.on_event("startup")
def on_startup():
    from database.db import init_db
    init_db()

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS — restrict to explicit origins in production.
# Set ALLOWED_ORIGINS as a comma-separated list, e.g.:
#   ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
# Omitting it (or setting it to "*") falls back to wildcard — only acceptable in local dev.
_raw_origins = os.environ.get("ALLOWED_ORIGINS", "").strip()
if _raw_origins and _raw_origins != "*":
    _allow_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]
    _allow_origin_regex = None
else:
    _allow_origins = ["*"]
    _allow_origin_regex = None

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_origin_regex=_allow_origin_regex,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
    allow_credentials=_allow_origins != ["*"],
)
app.add_middleware(ApiKeyMiddleware)


@app.middleware("http")
async def limit_upload_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > MAX_UPLOAD_BYTES:
        mb = MAX_UPLOAD_BYTES / 1024 / 1024
        return JSONResponse(
            status_code=413,
            content={"detail": f"File too large. Maximum upload size is {mb:.0f} MB (5 hours of audio)."},
        )
    return await call_next(request)

_auth_required = [Depends(get_current_user)]

app.include_router(auth_router)
app.include_router(transcription_router, dependencies=_auth_required)
app.include_router(translation_router, dependencies=_auth_required)
app.include_router(summary_router, dependencies=_auth_required)


@app.get("/")
def root():
    return {"message": "AI Meeting Assistant API is running."}


@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    storage_status, storage_detail = check_s3_storage()
    payload = {
        "status": "ok",
        "database": "ok",
        "storage_backend": storage_backend_name(),
        "storage": storage_status,
    }
    if storage_detail:
        payload["storage_detail"] = storage_detail
    if storage_status == "error":
        payload["status"] = "degraded"
    return payload
