"""Master the 2026-10-23 CC0 zombie/weapon revision, without any speech synthesis.

Download the original files listed in docs/AUDIO_LICENSES.md into
.runtime/audio_sources/revision. Extract undead-moans.zip into undead/ and
arcadeparty-voices.zip into arcadeparty/. Carl Gustav M45/G_20P.wav comes from
the existing Prepared SFX Library.7z. Requires NumPy and FFmpeg with Rubber Band.
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
RAW = ROOT / ".runtime/audio_sources/revision"
OUT = ROOT / "assets/audio"
VOICES = OUT / "voices"
RATE = 44100
FFMPEG = shutil.which("ffmpeg")
VOICE_MANIFEST = {}
MANIFEST = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
ARCHIVES = {
    "undead-moans.zip": "https://opengameart.org/sites/default/files/undead-moans.zip",
    "arcadeparty-voices.zip": "https://opengameart.org/sites/default/files/Voice%20Effects%20Zombie-Skeleton-Monster%20Human%20Male.zip",
    "assaultriflereload1.wav": "https://opengameart.org/sites/default/files/assaultriflereload1_0.wav",
    "shotguncock.wav": "https://opengameart.org/sites/default/files/shotguncock_0.wav",
    "clipload2.wav": "https://opengameart.org/sites/default/files/clipload2.wav",
    "singlebullet1.wav": "https://opengameart.org/sites/default/files/singlebullet1.wav",
}


def decode(path: Path, filters: str = "") -> np.ndarray:
    args = [FFMPEG, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE)]
    if filters:
        args += ["-af", filters]
    return np.frombuffer(subprocess.check_output(args + ["-f", "f32le", "-"]), dtype="<f4").astype(np.float64)


def trim(x: np.ndarray, threshold: float = .018) -> np.ndarray:
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * threshold)
    if not len(active):
        raise ValueError("Silent source")
    return x[max(0, active[0] - 180):min(len(x), active[-1] + 800)]


def finish(x: np.ndarray, peak: float, fade_in: float = .003, fade_out: float = .03) -> np.ndarray:
    x = x.copy()
    x -= x.mean()
    a, b = min(len(x), int(fade_in * RATE)), min(len(x), int(fade_out * RATE))
    x[:a] *= np.linspace(0, 1, a) ** 2
    x[-b:] *= np.linspace(1, 0, b) ** 2
    return x * peak / max(np.max(np.abs(x)), 1e-12)


def write(path: Path, x: np.ndarray, source: str, url: str, processing: str, bank: dict) -> None:
    pcm = np.round(x * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    bank[path.name] = {
        "source": source + " (CC0-1.0)", "source_url": url,
        "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "processing": processing, "duration_seconds": round(len(x) / RATE, 4),
        "sample_rate": RATE, "peak_dbfs": round(20 * np.log10(np.max(np.abs(x))), 2),
        "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(x * x))), 2),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    print(f"{path.name}: {len(x) / RATE:.3f}s, {bank[path.name]['peak_dbfs']:.2f} dBFS")


def main() -> None:
    for filename in ARCHIVES:
        if not (RAW / filename).is_file():
            raise SystemExit("Download source first: " + filename)
    archive_hashes = {name: {"download_url": url, "sha256": hashlib.sha256((RAW / name).read_bytes()).hexdigest()}
                      for name, url in ARCHIVES.items()}
    archive_hashes["Prepared SFX Library.7z"] = {
        "download_url": "https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z",
        "sha256": hashlib.sha256((ROOT / ".runtime/audio_sources/prepared_sfx.7z").read_bytes()).hexdigest(),
    }
    (OUT / "revision-sources.json").write_text(json.dumps(archive_hashes, indent=2) + "\n", encoding="utf-8")

    undead_url = "https://opengameart.org/content/undead-moans"
    arcade_url = "https://opengameart.org/content/zombie-skeleton-monster-voice-effects"
    arcade = RAW / "arcadeparty/Voice Effects Zombie-Skeleton-Monster Human Male"
    # Long, breathy groans for walkers; short snarls for runners; lower, rough
    # roars for brutes. Every voice is a recording by the credited performer.
    voices = {
        "walker": [(RAW / "undead/undead-1.ogg", "AntumDeluge / Undead Moans / undead-1.ogg", undead_url, .98, 1.12),
                   (RAW / "undead/undead-2.ogg", "AntumDeluge / Undead Moans / undead-2.ogg", undead_url, 1.0, 1.08),
                   (RAW / "undead/undead-4.ogg", "AntumDeluge / Undead Moans / undead-4.ogg", undead_url, .97, 1.0)],
        "runner": [(arcade / f"zombieYell{n}.wav", f"ArcadeParty / Zombie Voice Effects / zombieYell{n}.wav", arcade_url, 1.05, 1.0) for n in [3, 5, 7]],
        "brute": [(arcade / f"zombieYell{n}.wav", f"ArcadeParty / Zombie Voice Effects / zombieYell{n}.wav", arcade_url, .77, .86) for n in [4, 8, 10]],
    }
    showcase = []
    for family, sources in voices.items():
        cutoff = 3600 if family == "brute" else 5700
        for index, (path, source, url, pitch, tempo) in enumerate(sources, 1):
            filters = (f"highpass=f=75,lowpass=f={cutoff},"
                       f"rubberband=tempo={tempo}:pitch={pitch}:formant=shifted:pitchq=quality,"
                       "acompressor=threshold=0.18:ratio=2:attack=8:release=75")
            x = finish(trim(decode(path, filters), .009), .56, .006, .04)
            write(VOICES / f"zombie_{family}_{index:02}.wav", x, source, url,
                  f"Recorded performance; mono PCM 44.1kHz; 75-{cutoff}Hz EQ; pitch {pitch}; tempo {tempo}; moderate compression, silence trim, DC removal, fades, peak gain.", VOICE_MANIFEST)
            if index == 1:
                showcase.extend([x, np.zeros(int(.25 * RATE))])
    (VOICES / "manifest.json").write_text(json.dumps(VOICE_MANIFEST, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(RAW / "undead/LICENSE.txt", VOICES / "LICENSE-CC0.txt")

    source = ROOT / ".runtime/audio_sources/Prepared SFX Library/Carl Gustav M45/G_20P.wav"
    x = decode(source, "highpass=f=65,lowpass=f=10000")
    # Isolate the first gun report before the later outdoor reflection. The
    # short tail supports sustained fire without a stack of long rifle echoes.
    onset = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .035)[0]
    start = max(0, onset - 35)
    x = finish(x[start:start + int(.15 * RATE)], .72, .00015, .055)
    write(OUT / "shot_smg.wav", x, "Ben Jaszczak et al. / The Free Firearm Sound Library / Carl Gustav M45/G_20P.wav",
          "https://opengameart.org/content/the-free-firearm-sound-library", "First isolated submachine gun report; mono 44.1kHz; 65Hz-10kHz EQ; 150ms tail for rapid fire; fades and gain.", MANIFEST)

    pump = trim(decode(RAW / "shotguncock.wav", "highpass=f=120,lowpass=f=7900"))
    pump = finish(pump, .32, .001, .025)
    write(OUT / "reload_shotgun.wav", pump, "SpringySpringo / Gun reload sounds / shotguncock_0.wav",
          "https://opengameart.org/content/gun-reload-sounds", "Recorded airsoft pump action; trim, EQ, mono, DC removal and fades.", MANIFEST)

    insert = trim(decode(RAW / "singlebullet1.wav", "highpass=f=130,lowpass=f=7500"))
    latch = trim(decode(RAW / "clipload2.wav", "highpass=f=130,lowpass=f=7500"))
    # The raw cartridge transients are much louder than the mechanism body.
    # Soft saturation reduces that crest factor so the loading remains audible
    # under the fading report without increasing the final output peak.
    insert = np.tanh(insert * 7.0) / 7.0
    latch = np.tanh(latch * 7.0) / 7.0
    bolt = np.zeros(int(.60 * RATE))
    bolt[:len(insert)] += insert * .8
    offset = int(.36 * RATE)
    bolt[offset:offset + min(len(latch), len(bolt) - offset)] += latch[:len(bolt) - offset]
    bolt = finish(bolt, .34, .001, .035)
    write(OUT / "reload_sniper.wav", bolt, "Brian MacIntosh (BMacZero) / Gun Reload Sound Effects / singlebullet1.wav + clipload2.wav",
          "https://opengameart.org/content/gun-reload-sound-effects", "Recorded cartridge and metal latch sequence; spaced at 0/360ms; crest-factor reduction, mono, EQ, DC removal, fades and gain.", MANIFEST)

    action = decode(RAW / "assaultriflereload1.wav", "highpass=f=180,lowpass=f=7000")
    # A tiny actual mechanism movement, rather than changing a whole magazine
    # after each automatic bullet. The shared shot cooldown is only 120ms.
    peak = int(np.argmax(np.abs(action)))
    start = max(0, peak - int(.008 * RATE))
    cycle = finish(action[start:start + int(.065 * RATE)], .20, .001, .012)
    write(OUT / "reload_smg.wav", cycle, "SpringySpringo / Gun reload sounds / assaultriflereload1_0.wav",
          "https://opengameart.org/content/gun-reload-sounds", "65ms recorded mechanism excerpt; mono, EQ, DC removal, soft edges and lower gain for automatic cycling.", MANIFEST)

    (OUT / "manifest.json").write_text(json.dumps(MANIFEST, indent=2) + "\n", encoding="utf-8")
    montage = np.concatenate(showcase)
    with wave.open(str(ROOT / "docs/ZOMBIE-CC0-ANTEPRIMA.wav"), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(np.round(montage * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    main()
