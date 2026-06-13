from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database.db import init_db
from api.transcription import router as transcription_router
from api.translation import router as translation_router
from api.summary import router as summary_router

app = FastAPI(
    title="AI Meeting Assistant",
    description="Transcribe, translate and generate MoM for meetings.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transcription_router)
app.include_router(translation_router)
app.include_router(summary_router)


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/")
def root():
    return {"message": "AI Meeting Assistant API is running."}


@app.get("/health")
def health():
    return {"status": "ok"}
