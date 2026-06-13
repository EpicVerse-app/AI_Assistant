import argparse
from pathlib import Path

from summarizer import DEFAULT_MODEL, DEFAULT_OLLAMA_URL, generate_mom, generate_summary
from transcriber import transcribe_audio


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Transcribe an audio file using Sarvam AI and generate a summary."
    )
    parser.add_argument("audio", help="Path to the audio file to transcribe")
    parser.add_argument(
        "--type",
        choices=["meeting", "conversation"],
        default="meeting",
        help="Type of audio: 'meeting' generates MoM, 'conversation' generates a plain summary. Default: meeting",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Ollama model for summary generation. Default: {DEFAULT_MODEL}",
    )
    parser.add_argument(
        "--ollama-url",
        default=DEFAULT_OLLAMA_URL,
        help=f"Ollama server URL. Default: {DEFAULT_OLLAMA_URL}",
    )
    args = parser.parse_args()

    result = transcribe_audio(Path(args.audio).expanduser())

    if args.type == "meeting":
        print("\nGenerated MoM:")
        print(generate_mom(result.transcript, model=args.model, ollama_url=args.ollama_url))
    else:
        print("\nConversation Summary:")
        print(generate_summary(result.transcript, model=args.model, ollama_url=args.ollama_url))


if __name__ == "__main__":
    main()
