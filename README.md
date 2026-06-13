# AI Memory Assistant

AI Memory Assistant with a Flutter mobile frontend and Python backend.

## Project Structure

- `lib/` — Flutter app (login, home, record, search, settings, MoM)
- `html/` — HTML prototype of the UI
- `backend/` — Python API (transcription, summarization, translation)

## Flutter App

```bash
flutter pub get
flutter run -d macos   # or chrome / ios
```

## HTML Prototype

Open `html/index.html` in a browser, or run:

```bash
cd html && python3 -m http.server 8080
```

## Backend

```bash
cd backend
pip install -r requirements.txt
python app.py
```
