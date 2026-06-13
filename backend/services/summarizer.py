import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../utils/.env"))

_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

MOM_SYSTEM_PROMPT = """You are a professional meeting assistant. 
Generate structured Meeting Minutes (MoM) from the transcript provided.

Use exactly these headings:

Meeting Date
Meeting Topic
Attendees
Summary
Decisions
Action Items
Deadlines
Important Notes

If a detail is not mentioned in the transcript, write "Not mentioned".
Be concise, clear, and professional."""

SUMMARY_SYSTEM_PROMPT = """You are a helpful assistant. 
Summarize the conversation below in clear, natural English covering:
- What the conversation is about
- Key points discussed
- Any decisions or conclusions reached

Skip anything not mentioned. Keep it concise and readable."""


def generate_mom(transcript: str) -> str:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Transcript is empty.")

    response = _client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": MOM_SYSTEM_PROMPT},
            {"role": "user", "content": f"Transcript:\n{transcript}"},
        ],
        temperature=0.3,
    )
    return response.choices[0].message.content.strip()


def generate_summary(transcript: str) -> str:
    transcript = transcript.strip()
    if not transcript:
        raise ValueError("Transcript is empty.")

    response = _client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": SUMMARY_SYSTEM_PROMPT},
            {"role": "user", "content": f"Transcript:\n{transcript}"},
        ],
        temperature=0.3,
    )
    return response.choices[0].message.content.strip()
