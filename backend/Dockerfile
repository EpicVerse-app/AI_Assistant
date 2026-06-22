FROM python:3.11-slim

# pydub audio conversion
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements-prod.txt .
RUN pip install --no-cache-dir -r requirements-prod.txt

COPY . .

# Render sets PORT; default 8000 for local docker run
ENV PORT=8000
EXPOSE 8000

CMD uvicorn app:app --host 0.0.0.0 --port ${PORT}
