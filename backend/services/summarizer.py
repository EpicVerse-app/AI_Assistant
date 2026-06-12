import json
from urllib.error import URLError
from urllib.request import Request, urlopen


DEFAULT_OLLAMA_URL = "http://localhost:11434"
DEFAULT_MODEL = "gemma3:1b"


def build_mom_prompt(transcript: str) -> str:
    return f"""Create meeting minutes from the transcript below.

Return the output with these exact headings:

Meeting Date
Meeting Topic
Attendees
Summary
Decisions
Action Items
Deadlines
Important Notes

If any detail is not mentioned in the transcript, write "Not mentioned".
Keep the response clear and concise.

Transcript:
{transcript}
"""


def generate_mom(
    transcript: str,
    model: str = DEFAULT_MODEL,
    ollama_url: str = DEFAULT_OLLAMA_URL,
) -> str:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Cannot generate MoM because the transcript is empty.")

    payload = {
        "model": model,
        "prompt": build_mom_prompt(transcript),
        "stream": False,
    }
    request = Request(
        f"{ollama_url.rstrip('/')}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(request, timeout=300) as response:
            result = json.loads(response.read().decode("utf-8"))
    except URLError as exc:
        raise RuntimeError(
            "Could not connect to Gemma 3 through Ollama. "
            "Make sure Ollama is running and the gemma3 model is available."
        ) from exc

    return result.get("response", "").strip()


def build_conversation_prompt(transcript: str) -> str:
    return f"""Below is a conversation transcript. Write a concise summary in English covering:
- What the conversation is about
- Key points discussed
- Any decisions or conclusions reached

If something is not mentioned, skip it. Keep it natural and readable.

Transcript:
{transcript}

Summary:"""


def generate_summary(
    transcript: str,
    model: str = DEFAULT_MODEL,
    ollama_url: str = DEFAULT_OLLAMA_URL,
) -> str:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Cannot generate summary because the transcript is empty.")

    payload = {
        "model": model,
        "prompt": build_conversation_prompt(transcript),
        "stream": False,
    }
    request = Request(
        f"{ollama_url.rstrip('/')}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(request, timeout=300) as response:
            result = json.loads(response.read().decode("utf-8"))
    except URLError as exc:
        raise RuntimeError(
            "Could not connect to Gemma 3 through Ollama. "
            "Make sure Ollama is running and the gemma3:1b model is available."
        ) from exc

    return result.get("response", "").strip()
