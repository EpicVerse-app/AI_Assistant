import argparse
from pathlib import Path

from services.summarizer import generate_mom, generate_summary
from services.transcriber import transcribe_audio


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
    args = parser.parse_args()

    result = transcribe_audio(Path(args.audio).expanduser())

    if args.type == "meeting":
        print("\nGenerated MoM:")
        print(generate_mom(result.transcript))
    else:
        print("\nConversation Summary:")
        print(generate_summary(result.transcript))


if __name__ == "__main__":
    main()
