"""Prepare the six recordings supplied in suoni/ without modifying originals.

Requires Python + NumPy, FFmpeg and ffprobe. Run from any directory:
    python tools/prepare_user_audio.py

WAV effects are individual game events, never an automatic-fire loop. The
complete zombie performance is an Ogg Vorbis stream with runtime crossfading;
only the unused terminal silence is removed, not individual vocalizations.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "suoni"
OUT = ROOT / "assets/audio/user"
RATE = 44100
FFMPEG = shutil.which("ffmpeg")
FFPROBE = shutil.which("ffprobe")
FILES = {
    "pistol": "pistola.mp3",
    "shotgun": "fucile a pompa.mp3",
    "sniper": "fucile di precisione.mp3",
    "smg": "mitragliatore.mp3",
    "reload": "ricarica arma.mp3",
    "zombie": "zombie.mp3",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def probe(path: Path) -> dict:
    result = json.loads(subprocess.check_output([
        FFPROBE, "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path),
    ]))
    result["format"].pop("filename", None)
    return result


def decode(path: Path, filters: str = "") -> np.ndarray:
    args = [FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE)]
    if filters:
        args += ["-af", filters]
    return np.frombuffer(subprocess.check_output(args + ["-f", "f32le", "-"]), dtype="<f4").astype(np.float64)


def stats(x: np.ndarray) -> dict:
    return {
        "duration_seconds": round(len(x) / RATE, 6),
        "peak_dbfs": round(float(20 * np.log10(max(np.max(np.abs(x)), 1e-12))), 3),
        "rms_dbfs": round(float(10 * np.log10(max(np.mean(x * x), 1e-24))), 3),
    }


def finish(x: np.ndarray, peak: float, fade_in: float = .0005, fade_out: float = .025) -> np.ndarray:
    x = x.copy()
    x -= x.mean()
    a = min(len(x), max(2, round(fade_in * RATE)))
    b = min(len(x), max(2, round(fade_out * RATE)))
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b) ** 2
    source_peak = float(np.max(np.abs(x)))
    if source_peak < .00001:
        raise ValueError("Unexpected silent source")
    return x * (peak / source_peak)


def trim(x: np.ndarray, threshold: float = .007, before: float = .002, after: float = .05) -> tuple[np.ndarray, list[float]]:
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * threshold)
    if not len(active):
        raise ValueError("Unexpected silent source")
    first = max(0, int(active[0]) - round(before * RATE))
    last = min(len(x), int(active[-1]) + round(after * RATE))
    return x[first:last], [round(first / RATE, 6), round(last / RATE, 6)]


def tempo(x: np.ndarray, factor: float) -> np.ndarray:
    data = subprocess.check_output([
        FFMPEG, "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
        "-af", f"atempo={factor}", "-f", "f32le", "-",
    ], input=x.astype("<f4").tobytes())
    return np.frombuffer(data, dtype="<f4").astype(np.float64)


def write_wav(path: Path, x: np.ndarray) -> None:
    if np.max(np.abs(x)) >= 1:
        raise ValueError("Refusing to quantize clipped audio")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(np.round(x * 32767).astype("<i2").tobytes())


def main() -> None:
    if not FFMPEG or not FFPROBE:
        raise SystemExit("FFmpeg and ffprobe must be on PATH")
    for name in FILES.values():
        if not (SOURCES / name).is_file():
            raise SystemExit("Missing supplied recording: " + name)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "recordings_supplied_by": "Project owner",
        "permission": "Owner states recordings are freely distributable and authorizes use in this game.",
        "license_identifier": None,
        "license_note": "No license identifier, creator name or source URL was supplied or embedded; do not label these recordings CC0.",
        "generator": "tools/prepare_user_audio.py",
        "sample_rate": RATE,
        "sources": {},
        "assets": {},
    }
    decoded = {}
    for key, filename in FILES.items():
        path = SOURCES / filename
        x = decode(path)
        decoded[key] = x
        metadata = probe(path)
        manifest["sources"][key] = {
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": sha256(path),
            "bytes": path.stat().st_size,
            "probe": metadata,
            "decoded_mono": stats(x),
            "decoded_samples_above_full_scale": int(np.count_nonzero(np.abs(x) > 1)),
        }

    def save(name: str, x: np.ndarray, key: str, recipe: dict, kind: str = "event") -> None:
        path = OUT / name
        write_wav(path, x)
        manifest["assets"][name] = {
            "source_key": key,
            "sha256": sha256(path),
            "format": "PCM signed 16-bit WAV",
            "sample_rate": RATE,
            "channels": 1,
            "kind": kind,
            "loop": False,
            "processing": recipe,
            **stats(x),
        }

    for key in ("pistol", "shotgun", "sniper"):
        x, region = trim(decoded[key], after=.055)
        # Decode to float before gain: supplied shotgun/sniper MP3s overshoot
        # full scale, so clamping to integer PCM first would flatten transients.
        x = finish(x, .72, .0003, .035)
        save(f"shot_{key}.wav", x, key, {
            "source_region_seconds": region,
            "operation": "Mono mix; remove leading/trailing near silence only; DC removal; 0.3ms attack and 35ms tail fades; normalize floating-point peak to 0.72 before PCM quantization.",
        })

    # The supplied 244ms SMG file already contains a short burst, with three
    # attacks about 80ms apart. Keep a single complete cycle so one actual
    # projectile never produces three audible reports or autonomous gunfire.
    smg_start, smg_end = .074, .154
    smg = decoded["smg"][round(smg_start * RATE):round(smg_end * RATE)]
    smg = finish(smg, .65, .001, .013)
    save("shot_smg.wav", smg, "smg", {
        "source_region_seconds": [smg_start, smg_end],
        "operation": "One complete recorded firing cycle from middle of supplied burst; mono; DC removal; 1ms attack and 13ms release; floating-point peak 0.65.",
    })

    full_reload, reload_region = trim(decoded["reload"], after=.035)
    save("reload.wav", finish(full_reload, .48, .001, .025), "reload", {
        "source_region_seconds": reload_region,
        "operation": "Full original mechanical sequence, mono, silence trim, DC removal, edge fades and floating-point peak 0.48.",
    })
    # Both mechanism groups are retained, but the long silent gap between them
    # is removed for the current per-shot cooldown; pitch remains unchanged.
    group_a = decoded["reload"][round(.265 * RATE):round(.45 * RATE)]
    group_b = decoded["reload"][round(.89 * RATE):round(1.235 * RATE)]
    groups = np.concatenate([finish(group_a, .40, .001, .012), np.zeros(round(.045 * RATE)),
                             finish(group_b, .40, .001, .025)])
    save("reload_sniper.wav", finish(groups, .42, .001, .025), "reload", {
        "source_regions_seconds": [[.265, .45], [.89, 1.235]],
        "gap_seconds": .045,
        "operation": "Two original mechanism groups, long internal pause shortened to 45ms, pitch and event speed preserved; edge fades; floating-point peak 0.42.",
    })
    pump = tempo(groups, 1.50)
    save("reload_shotgun.wav", finish(pump, .40, .001, .025), "reload", {
        "source_regions_seconds": [[.265, .45], [.89, 1.235]],
        "gap_seconds": .045,
        "tempo_factor": 1.50,
        "operation": "Same two mechanism groups, pause shortened and atempo 1.50 without changing pitch; fades; floating-point peak 0.40.",
    })
    # A whole magazine reload cannot fit a 120ms automatic firing cycle.
    # Use a tiny quiet mechanical latch, rather than a new reload per bullet.
    latch_start, latch_end = .943, 1.008
    latch = decoded["reload"][round(latch_start * RATE):round(latch_end * RATE)]
    save("reload_smg.wav", finish(latch, .18, .001, .014), "reload", {
        "source_region_seconds": [latch_start, latch_end],
        "operation": "65ms recorded latch excerpt; DC removal; edge fades; quieter 0.18 floating-point peak for automatic mechanism.",
    })

    # Keep the mixed zombie performance in its original order and at its
    # original pitch/speed. The final 3.35 seconds contain only digital silence.
    zombie = decoded["zombie"]
    sounding = np.flatnonzero(np.abs(zombie) > .0001)
    end = min(len(zombie), int(sounding[-1]) + round(.10 * RATE))
    zombie = finish(zombie[:end], .62, .018, .065)
    zombie_path = OUT / "zombie.ogg"
    subprocess.run([
        FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
        "-c:a", "libvorbis", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact",
        "-map_metadata", "-1", str(zombie_path),
    ], input=zombie.astype("<f4").tobytes(), check=True)
    # Lossy encoding can produce intersample/sample peak overshoot: record and
    # validate the decoded shipped output, not just the pre-encode waveform.
    shipped_zombie = decode(zombie_path)
    manifest["assets"]["zombie.ogg"] = {
        "source_key": "zombie",
        "sha256": sha256(zombie_path),
        "format": "Ogg Vorbis q5",
        "sample_rate": RATE,
        "channels": 1,
        "kind": "streaming_soundscape",
        "loop": False,
        "runtime_crossfade_seconds": 2.5,
        "processing": {
            "source_region_seconds": [0, round(end / RATE, 6)],
            "operation": "Entire original performance in order; remove terminal digital silence only; mono; DC removal; tiny boundary fades; floating-point peak 0.62; Vorbis q5. No pitch, speed or vocalization changes.",
        },
        **stats(shipped_zombie),
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, entry in manifest["assets"].items():
        print(f"{name}: {entry['duration_seconds']:.3f}s; {entry['peak_dbfs']:.2f}dBFS; {entry['sha256'][:12]}")


if __name__ == "__main__":
    main()
