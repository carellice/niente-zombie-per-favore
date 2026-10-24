"""Compatibility entry point for the current, zombie-only CC0 audio pass.

Survivor speech is intentionally disabled. This command no longer runs Windows
TTS or regenerates development-only civilian clips.
"""
from prepare_audio_revision import main

if __name__ == "__main__":
    main()
