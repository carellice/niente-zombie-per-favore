"""Validate supplied-source integrity and the shipped event/stream audio.

Run: python -m unittest discover -s tests -p test_user_audio_assets.py -v
Requires the same NumPy and FFmpeg runtime used by tools/prepare_user_audio.py.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import unittest
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/user"
RATE = 44100


class UserAudioAssets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
        cls.audio = {}
        ffmpeg = shutil.which("ffmpeg")
        if not ffmpeg:
            raise RuntimeError("FFmpeg is required to validate the shipped Ogg stream")
        for name in cls.manifest["assets"]:
            path = OUT / name
            if path.suffix == ".wav":
                with wave.open(str(path), "rb") as stream:
                    if (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) != (1, 2, RATE):
                        raise AssertionError(f"Wrong PCM format: {name}")
                    x = np.frombuffer(stream.readframes(stream.getnframes()), "<i2").astype(float) / 32768
            else:
                x = np.frombuffer(subprocess.check_output([
                    ffmpeg, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-",
                ]), "<f4").astype(float)
            cls.audio[name] = x

    def test_every_supplied_original_is_preserved_byte_for_byte(self):
        sources = self.manifest["sources"]
        actual = {path.name for path in (ROOT / "suoni").glob("*.mp3")}
        self.assertEqual(actual, {Path(source["path"]).name for source in sources.values()})
        self.assertEqual(len(sources), 6)
        for key, source in sources.items():
            with self.subTest(source=key):
                path = ROOT / source["path"]
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), source["sha256"])
                self.assertEqual(path.stat().st_size, source["bytes"])

    def test_no_unverified_license_or_authorship_is_invented(self):
        self.assertIsNone(self.manifest["license_identifier"])
        self.assertIn("Owner states", self.manifest["permission"])
        self.assertIn("do not label", self.manifest["license_note"])
        for source in self.manifest["sources"].values():
            self.assertIn("probe", source)
            self.assertNotIn("CC0", source.get("license", ""))

    def test_shipped_assets_match_manifest_checksums_and_formats(self):
        self.assertEqual(len(self.manifest["assets"]), 9)
        for name, entry in self.manifest["assets"].items():
            with self.subTest(asset=name):
                self.assertEqual(hashlib.sha256((OUT / name).read_bytes()).hexdigest(), entry["sha256"])
                self.assertAlmostEqual(len(self.audio[name]) / RATE, entry["duration_seconds"], places=5)
                self.assertEqual(entry["sample_rate"], RATE)
                self.assertEqual(entry["channels"], 1)
                self.assertIn(entry["source_key"], self.manifest["sources"])

    def test_no_output_clips_or_becomes_silent(self):
        for name, x in self.audio.items():
            with self.subTest(asset=name):
                self.assertTrue(np.all(np.isfinite(x)))
                self.assertLess(np.max(np.abs(x)), .8)
                self.assertGreater(np.max(np.abs(x)), .15)
                rms = float(np.sqrt(np.mean(x * x)))
                self.assertGreater(rms, .006)
                self.assertLess(rms, .25)

    def test_overshooting_mp3_sources_are_decoded_as_float_before_mastering(self):
        for key in ("shotgun", "sniper", "smg", "reload", "zombie"):
            with self.subTest(source=key):
                source = self.manifest["sources"][key]
                self.assertGreater(source["decoded_samples_above_full_scale"], 0)
                self.assertGreater(source["decoded_mono"]["peak_dbfs"], 0)
                for name, entry in self.manifest["assets"].items():
                    if entry["source_key"] == key:
                        self.assertLess(np.max(np.abs(self.audio[name])), .8)

    def test_weapon_reports_start_immediately_and_never_loop(self):
        for weapon in ("pistol", "shotgun", "sniper", "smg"):
            name = f"shot_{weapon}.wav"
            x = self.audio[name]
            active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .02)
            with self.subTest(weapon=weapon):
                self.assertLess(active[0] / RATE, .035)
                self.assertFalse(self.manifest["assets"][name]["loop"])
                self.assertEqual(self.manifest["assets"][name]["kind"], "event")

    def test_short_smg_cycle_does_not_replay_three_reports_for_one_bullet(self):
        duration = len(self.audio["shot_smg.wav"]) / RATE
        self.assertGreater(duration, .07)
        self.assertLess(duration, .10)
        original_duration = self.manifest["sources"]["smg"]["decoded_mono"]["duration_seconds"]
        self.assertGreater(original_duration / duration, 2.8)

    def test_reload_cues_fit_actual_cooldowns_after_the_shot(self):
        for weapon, delay, cooldown in (("shotgun", .25, .85), ("sniper", .35, 1.15), ("smg", .04, .12)):
            with self.subTest(weapon=weapon):
                cue = self.audio[f"reload_{weapon}.wav"]
                self.assertLessEqual(delay + len(cue) / RATE, cooldown)
        self.assertGreater(len(self.audio["reload.wav"]) / RATE, 1.2)

    def test_zombie_stream_retains_full_performance_and_removes_only_terminal_silence(self):
        entry = self.manifest["assets"]["zombie.ogg"]
        original = self.manifest["sources"]["zombie"]["decoded_mono"]["duration_seconds"]
        duration = len(self.audio["zombie.ogg"]) / RATE
        self.assertGreater(duration, 92.6)
        self.assertLess(duration, 92.85)
        self.assertGreater(original - duration, 3.1)
        self.assertLess(original - duration, 3.5)
        self.assertEqual(entry["kind"], "streaming_soundscape")
        self.assertFalse(entry["loop"])
        self.assertEqual(entry["runtime_crossfade_seconds"], 2.5)
        self.assertEqual(entry["processing"]["source_region_seconds"][0], 0)

    def test_pcm_event_boundaries_are_declicked(self):
        for name, x in self.audio.items():
            if name.endswith(".wav"):
                with self.subTest(asset=name):
                    self.assertLessEqual(abs(x[0]), 1 / 32768)
                    self.assertLessEqual(abs(x[-1]), 1 / 32768)
                    self.assertLess(abs(x[1] - x[0]), .02)
                    self.assertLess(abs(x[-1] - x[-2]), .02)


if __name__ == "__main__":
    unittest.main(verbosity=2)
