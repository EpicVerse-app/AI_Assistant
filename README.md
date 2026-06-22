# AI Memory Assistant

Record meetings, transcribe audio, translate to English, and generate structured meeting minutes (MoM) — powered by a Flutter mobile app and a FastAPI backend.

## Features

- Record or upload audio (mp3, m4a, wav, aac, ogg, flac, and more)
- Speech-to-text via [Sarvam AI](https://www.sarvam.ai/)
- Translation to English
- AI-generated meeting minutes (OpenAI or local Ollama fallback)
- Offline queue — recordings saved locally and synced when back online
- HTML UI prototype for quick browser testing

## Project structure

```
AI_Assistant/
├── frontend/          # Flutter app (iOS, Android, macOS, web, etc.)
│   ├── lib/           # App screens and services
│   └── html/          # Static HTML prototype
└── backend/           # FastAPI API
    ├── api/           # REST routes (transcription, translation, summary)
    ├── services/      # STT, translation, MoM pipeline
    ├── database/      # SQLite models and DB
    └── utils/         # Config (.env)
```

## Prerequisites

- **Flutter** 3.x ([install guide](https://docs.flutter.dev/get-started/install))
- **Python** 3.10+
- **ffmpeg** (required by pydub for audio conversion)
- API keys:
  - `SARVAM_API_KEY` — Sarvam STT & translation
  - `OPENAI_API_KEY` — MoM generation (optional if using Ollama locally)

## Backend setup

```bash
cd backend

# Create and activate a virtual environment (recommended)
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install -r requirements.txt

# Configure environment
cp utils/.env.example utils/.env
# Edit utils/.env and add your API keys

# Start the API server
uvicorn app:app --reload --host 127.0.0.1 --port 8000
```

- API docs: http://127.0.0.1:8000/docs
- Health check: http://127.0.0.1:8000/health

## Frontend setup

```bash
cd frontend

flutter pub get

# Run on a device or simulator
flutter run -d macos    # macOS
flutter run -d chrome   # Web
flutter run -d ios      # iOS simulator
flutter run -d android  # Android emulator
```

The app expects the backend at `http://localhost:8000` (see `frontend/lib/services/api_service.dart`).

> **Physical device:** use your Mac's LAN IP instead of `localhost`, e.g. `http://192.168.1.42:8000`.

## HTML prototype

```bash
cd frontend/html
python3 -m http.server 8080
# Open http://localhost:8080
```

## Pipeline overview

1. **Upload** — audio saved and converted to 16 kHz mono WAV
2. **Transcribe** — Sarvam STT (`saarika:v2.5`)
3. **Translate** — Sarvam translate to English
4. **Summarize** — structured MoM via OpenAI (`gpt-4o-mini`) or Ollama (`gemma3:1b`)

Outputs are stored under `backend/outputs/meetings/{meeting_id}/`.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SARVAM_API_KEY` | Yes | Sarvam speech-to-text and translation |
| `OPENAI_API_KEY` | No* | Meeting minutes generation (*Ollama fallback if unset) |

Copy `backend/utils/.env.example` → `backend/utils/.env`. Never commit `.env`.

## Real-time CLI transcriber (optional)

For terminal-based live transcription:

```bash
cd backend
python -m services.realtime_transcriber
```

Requires microphone access and `SARVAM_API_KEY` in `.env`.

## Development notes

- Login/signup in the Flutter app is **UI-only** (no backend auth yet).
- The API currently has **no authentication** — intended for local development only.
- `backend/database/ai_assistant.db` is local SQLite state; do not commit production data.

## License

Private project — EpicVerse-app.
