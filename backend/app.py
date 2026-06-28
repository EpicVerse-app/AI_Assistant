from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi import _rate_limit_exceeded_handler
from sqlalchemy import text
from sqlalchemy.orm import Session

from database.db import get_db, init_db
from api.auth import router as auth_router
from api.transcription import router as transcription_router
from api.translation import router as translation_router
from api.summary import router as summary_router
from services.storage import storage_backend_name
from utils.api_auth import ApiKeyMiddleware
from utils.jwt_auth import get_current_user
from utils.rate_limit import limiter

app = FastAPI(
    title="AI Meeting Assistant",
    description="Transcribe, translate and generate MoM for meetings.",
    version="1.0.0",
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(ApiKeyMiddleware)

_auth_required = [Depends(get_current_user)]

app.include_router(auth_router)
app.include_router(transcription_router, dependencies=_auth_required)
app.include_router(translation_router, dependencies=_auth_required)
app.include_router(summary_router, dependencies=_auth_required)


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/")
def root():
    return {"message": "AI Meeting Assistant API is running."}


@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {
        "status": "ok",
        "database": "ok",
        "storage_backend": storage_backend_name(),
    }
