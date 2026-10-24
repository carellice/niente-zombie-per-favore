"""Signal-level checks independent of the game and audio hardware."""
import hashlib
import json
from pathlib import Path
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / "assets/audio"
manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
checks = 0


def check(condition, message):
    global checks
    checks += 1
    assert condition, message


for name, info in manifest.items():
    file = folder / name
    check(hashlib.sha256(file.read_bytes()).hexdigest() == info["sha256"], name + " hash differs")
    if file.suffix != ".wav":
        continue
    with wave.open(str(file), "rb") as stream:
        check(stream.getsampwidth() == 2 and stream.getframerate() == 44100, name + " PCM format")
        x = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").astype(np.float64) / 32768
    check(0.02 < len(x)/44100 < 1.2, name + " duration")
    check(np.max(np.abs(x)) < .9, name + " clipping/headroom")
    check(abs(x[0]) < .005 and abs(x[-1]) < .005, name + " click-free endpoints")
    if name.startswith("shot_"):
        attack = np.flatnonzero(np.abs(x) > .1)[0] / 44100
        check(attack < .006, name + " must fire immediately after click")
        check(np.sqrt(np.mean(x[:1323]**2)) > .1, name + " audible initial report")
        check(np.max(np.abs(x)) > .65, name + " weapon transient must dominate UI")
    elif name.startswith("reload_"):
        check(np.max(np.abs(x)) < .36, name + " mechanical action must sit under the shot")
        check(np.sqrt(np.mean(x ** 2)) > .015, name + " mechanical action must remain audible")
    else:
        check(np.max(np.abs(x)) < .35, name + " UI must remain soft")

# Check the encoded stream itself: codec changes must not add a click at the
# playback wrap or silently collapse the wide, quiet bed into a mono tone.
decoded = subprocess.check_output([
    "ffmpeg", "-v", "error", "-i", str(folder / "shelter_ambience.ogg"),
    "-f", "f32le", "-ac", "2", "-",
])
bed = np.frombuffer(decoded, dtype="<f4").reshape(-1, 2)
check(abs(len(bed)/44100 - 40) < .01, "encoded ambient duration")
check(np.max(np.abs(bed)) < .28, "encoded ambient headroom")
check(np.sqrt(np.mean((bed[:, 0] - bed[:, 1]) ** 2)) > .01, "ambient must retain stereo movement")
check(np.max(np.abs(bed[-1] - bed[0])) < .01, "ambient loop boundary click")
check(np.all(np.abs(bed[-1] - bed[0]) < np.percentile(np.abs(np.diff(bed, axis=0)), 99, axis=0)),
      "loop wrap must be smaller than ordinary waveform steps")
print(f"Audio assets: {checks} checks passed")
