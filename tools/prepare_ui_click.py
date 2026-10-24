"""Prepare the short, warm interface click from local Kenney CC0 recordings.

Requires NumPy and FFmpeg. No downloads or generated oscillator tones are used.
The source cache must contain kenney_ui/Audio/click2.ogg and
kenney_impact/Audio/impactSoft_medium_000.ogg with their original licenses.
Only ui_click.wav, its manifest entry and the UI source license are written.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".runtime/audio_sources"
OUT = ROOT / "assets/audio"
RATE = 44100
DURATION = .110
PEAK_DBFS = -12.0
FFMPEG = shutil.which("ffmpeg")


def decode(path: Path, lowpass: int) -> np.ndarray:
    data = subprocess.check_output([
        FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
        "-af", f"highpass=f=110,lowpass=f={lowpass}:p=2", "-f", "f32le", "-",
    ])
    result = np.frombuffer(data, dtype="<f4").astype(np.float64)
    onset = np.flatnonzero(np.abs(result) > np.max(np.abs(result)) * .025)[0]
    return result[max(0, onset - 22):]


def normalized(signal: np.ndarray) -> np.ndarray:
    return signal / max(float(np.max(np.abs(signal))), 1e-12)


def main() -> None:
    if not FFMPEG:
        raise SystemExit("FFmpeg is required")
    ui_source = CACHE / "kenney_ui/Audio/click2.ogg"
    soft_source = CACHE / "kenney_impact/Audio/impactSoft_medium_000.ogg"
    for source in (ui_source, soft_source):
        if not source.is_file():
            raise SystemExit(f"Missing original CC0 source: {source}")

    click = decode(ui_source, 2800)
    # A small pitch reduction removes the sharp edge while retaining a real
    # tactile click. The quiet soft impact supplies the rounded 'toy' body.
    click = np.interp(np.arange(0, len(click), .86), np.arange(len(click)), click)
    soft = decode(soft_source, 1400)
    signal = np.zeros(round(RATE * DURATION))
    for recording, gain, delay in ((click, .72, 0), (soft, .36, .003)):
        offset = round(delay * RATE)
        count = min(len(recording), len(signal) - offset)
        signal[offset:offset + count] += normalized(recording[:count]) * gain
    signal -= np.mean(signal)
    # Gentle saturation reduces the crest factor so the cue is clear at a low
    # playback volume. It introduces no hard clipping or metallic echo.
    signal = np.tanh(signal * 2.8)
    attack, release = round(RATE * .0008), round(RATE * .025)
    signal[:attack] *= np.linspace(0, 1, attack)
    signal[-release:] *= np.linspace(1, 0, release)
    signal = normalized(signal) * 10 ** (PEAK_DBFS / 20)
    pcm = np.rint(signal * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / "ui_click.wav"
    with wave.open(str(destination), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())

    measured = pcm.astype(np.float64) / 32768
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest[destination.name] = {
        "source": "Kenney UI SFX Set / click2.ogg + Kenney Impact Sounds / impactSoft_medium_000.ogg",
        "source_url": "https://kenney.nl/assets/ui-audio",
        "additional_source_url": "https://kenney.nl/assets/impact-sounds",
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source_sha256": {
            str(path.relative_to(CACHE)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (ui_source, soft_source)
        },
        "processing": "Mono 44.1 kHz; 110 Hz high-pass; UI/soft layers low-passed at 2.8/1.4 kHz; UI speed 0.86; layers 0.72/0.36 at 0/3 ms; gentle tanh crest reduction; 0.8/25 ms fades; -12 dBFS peak. No beep or echo.",
        "duration_seconds": len(pcm) / RATE,
        "sample_rate": RATE,
        "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(measured)))), 2),
        "rms_dbfs": round(20 * math.log10(float(np.sqrt(np.mean(measured ** 2)))), 2),
        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(CACHE / "kenney_ui/License.txt", OUT / "LICENSE-Kenney-UI.txt")
    print(json.dumps(manifest[destination.name], indent=2))


if __name__ == "__main__":
    main()
