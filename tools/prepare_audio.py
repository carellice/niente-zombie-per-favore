"""Prepare the game's audio from verified CC0 sources plus an original bed.

Requires Python + NumPy and ffmpeg. Originals are kept in the ignored
.runtime/audio_sources folder. Download/provenance links: docs/AUDIO_LICENSES.md.
Run from the repository root after downloading/extracting those archives.
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
SOURCES = ROOT / ".runtime/audio_sources"
OUT = ROOT / "assets/audio"
RATE = 44100
FFMPEG = shutil.which("ffmpeg")
if not FFMPEG:
    raise SystemExit("ffmpeg is required")
OUT.mkdir(parents=True, exist_ok=True)
manifest: dict[str, dict] = {}


def decode(path: Path, filters: str = "") -> np.ndarray:
    command = [FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE)]
    if filters:
        command += ["-af", filters]
    command += ["-f", "f32le", "-"]
    return np.frombuffer(subprocess.check_output(command), dtype="<f4").astype(np.float64)


def finish(x: np.ndarray, peak: float, fade_in: float = .001, fade_out: float = .04) -> np.ndarray:
    x = np.array(x, dtype=np.float64, copy=True)
    x -= x.mean()
    a, b = min(len(x), int(RATE * fade_in)), min(len(x), int(RATE * fade_out))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    maximum = float(np.max(np.abs(x)))
    return x * peak / max(maximum, 1e-12)


def write_wav(name: str, x: np.ndarray, source: str, processing: str) -> None:
    path = OUT / (name + ".wav")
    pcm = np.round(np.clip(x, -.999, .999) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    manifest[path.name] = {
        "source": source, "processing": processing,
        "duration_seconds": round(len(pcm) / RATE, 4),
        "sample_rate": RATE,
        "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(x))), 1e-12)), 2),
        "rms_dbfs": round(20 * math.log10(max(float(np.sqrt(np.mean(x*x))), 1e-12)), 2),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def shot(name: str, relative: str, window: tuple[float, float], duration: float, peak: float) -> None:
    source = SOURCES / "Prepared SFX Library" / relative
    x = decode(source, "highpass=f=65,lowpass=f=10500")
    x = x[int(window[0] * RATE):int(window[1] * RATE)]
    # Retain the actual pressure transient with only a millisecond of preroll.
    onset = int(np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .035)[0])
    x = x[max(0, onset - 45):max(0, onset - 45) + int(duration * RATE)]
    # Dampen distant outdoor echoes while keeping a genuine recorded report.
    t = np.arange(len(x)) / RATE
    x *= np.exp(-np.maximum(t - .12, 0) * 1.4)
    x = finish(x, peak, .00015, .12)
    write_wav(name, x, "The Free Firearm Sound Library / " + relative,
              "First isolated report; mono 44.1 kHz; 65 Hz–10.5 kHz; echo-tail attenuation; "
              "start aligned, end faded, DC removed and peak gain adjusted. No synthetic gun tone.")


def foley(relative: str, length: float | None = None, rate: float = 1.0, cutoff: int = 6000) -> np.ndarray:
    path = SOURCES / "kenney_impact/Audio" / relative
    x = decode(path, f"highpass=f=90,lowpass=f={cutoff}")
    onset = int(np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .03)[0])
    x = x[max(0, onset - 40):]
    if rate != 1.0:
        x = np.interp(np.arange(0, len(x), rate), np.arange(len(x)), x)
    if length is not None:
        x = x[:int(length * RATE)]
    return x


def sequence(events: list[tuple[float, np.ndarray, float]]) -> np.ndarray:
    length = max(int(start * RATE) + len(x) for start, x, gain in events)
    output = np.zeros(length)
    for start, x, gain in events:
        offset = int(start * RATE)
        output[offset:offset + len(x)] += x * gain
    return output


def ui_audio() -> None:
    wood = foley("impactWood_light_001.ogg", .16, cutoff=3700)
    metal = foley("impactMetal_light_000.ogg", .18, cutoff=4800)
    bell = foley("impactBell_heavy_000.ogg", .65, .82, cutoff=4500)
    soft = foley("impactSoft_medium_000.ogg", .18, cutoff=3500)
    plank = foley("impactPlank_medium_000.ogg", .35, cutoff=4200)
    warning = foley("impactBell_heavy_001.ogg", .6, .58, cutoff=1800)
    effects = {
        "ui_tap": (wood, .18, "impactWood_light_001.ogg"),
        "cash": (sequence([(0, metal, 1), (.072, metal, .5)]), .20, "impactMetal_light_000.ogg"),
        "build": (sequence([(0, plank, 1), (.16, wood, .65)]), .26,
                  "impactPlank_medium_000.ogg + impactWood_light_001.ogg"),
        "ready": (bell, .17, "impactBell_heavy_000.ogg"),
        "reward": (sequence([(0, bell, .75), (.10, metal, .4)]), .20,
                   "impactBell_heavy_000.ogg + impactMetal_light_000.ogg"),
        "visitor": (sequence([(0, wood, 1), (.16, wood, .8)]), .23, "impactWood_light_001.ogg"),
        "alarm": (sequence([(0, warning, 1), (.42, warning, .7)]), .24, "impactBell_heavy_001.ogg"),
        "breach": (plank, .31, "impactPlank_medium_000.ogg"),
        "impact": (soft, .13, "impactSoft_medium_000.ogg"),
        "reject": (foley("impactWood_light_003.ogg", .17, .7, cutoff=2400), .18,
                   "impactWood_light_003.ogg"),
        "expedition": (sequence([(0, soft, 1), (.14, wood, .6)]), .21,
                       "impactSoft_medium_000.ogg + impactWood_light_001.ogg"),
    }
    for name, (x, peak, source) in effects.items():
        write_wav(name, finish(x, peak, .0006, .035), "Kenney Impact Sounds / " + source,
                  "Trimmed, high-pass/low-pass EQ, mono, soft fades, gain reduction; "
                  "some events layer two quiet foley hits. Warning/bell pitch lowered.")


def ambience() -> None:
    """A continuous, quiet C6/9 pad with cyclical filtered wind; no beep melody."""
    duration = 40.0
    count = int(duration * RATE)
    t = np.arange(count) / RATE
    left, right = np.zeros(count), np.zeros(count)
    # Every oscillator and LFO completes whole cycles for a seamless 40 s loop.
    for i, (freq, amp) in enumerate([(130.8128, .030), (164.8138, .018), (195.9977, .024),
                                    (220.0, .010), (293.6648, .011)]):
        base = round(freq * duration) / duration
        phase = .8 + i * 1.37
        swell = .76 + .24 * np.sin(2 * np.pi * (i % 3 + 1) * t / duration + phase)
        for side, detune in [(left, -1), (right, 1)]:
            carrier = 2 * np.pi * (base + detune * .025) * t + phase
            carrier += .08 * np.sin(2 * np.pi * (i + 1) * t / duration)
            side += amp * swell * (np.sin(carrier) + .14 * np.sin(2 * carrier) + .025 * np.sin(3 * carrier))
    rng = np.random.default_rng(70916)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    curve = (1 - np.exp(-(frequencies / 180) ** 2)) / (1 + (frequencies / 1150) ** 3)
    curve[0] = 0
    for side in [left, right]:
        wind = np.fft.irfft(np.fft.rfft(rng.normal(size=count)) * curve, n=count)
        wind *= .009 / max(float(np.sqrt(np.mean(wind * wind))), 1e-12)
        side += wind * (.8 + .2 * np.sin(2 * np.pi * 3 * t / duration))
    stereo = np.column_stack([left, right])
    stereo *= .25 / float(np.max(np.abs(stereo)))
    temp = SOURCES / "shelter_ambience_pcm.wav"
    pcm = np.round(stereo * 32767).astype("<i2")
    with wave.open(str(temp), "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    target = OUT / "shelter_ambience.ogg"
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(temp), "-c:a", "libvorbis", "-q:a", "4",
                    "-metadata", "title=Shelter - original warm ambience",
                    "-metadata", "comment=Original project audio, generated by tools/prepare_audio.py", str(target)], check=True)
    manifest[target.name] = {
        "source": "Original project synthesis: tools/prepare_audio.py",
        "processing": "40-second periodic, gently evolving warm C6/9 pad with filtered cyclical wind; stereo Vorbis; seamless loop.",
        "duration_seconds": duration, "sample_rate": RATE,
        "peak_dbfs": round(20 * math.log10(float(np.max(np.abs(stereo)))), 2),
        "rms_dbfs": round(20 * math.log10(float(np.sqrt(np.mean(stereo*stereo)))), 2),
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    }


if __name__ == "__main__":
    shot("shot_pistol", "1911/A_42P.wav", (.85, 2.5), .68, .72)
    shot("shot_shotgun", "Model 12/K_17P.wav", (.80, 2.8), .95, .80)
    shot("shot_sniper", "Mosin Nagant/M_21P.wav", (.95, 3.0), 1.15, .79)
    ui_audio()
    ambience()
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for name, info in manifest.items():
        print(f"{name:24s} {info['duration_seconds']:6.3f} s | peak {info['peak_dbfs']:6.2f} dBFS | RMS {info['rms_dbfs']:6.2f} dBFS")
