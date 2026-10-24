"""Active zombie bank: performed CC0 recordings, safe PCM and full provenance."""
import hashlib
import json
from pathlib import Path
import unittest
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "assets/audio/voices"

class CharacterVoiceAssets(unittest.TestCase):
    def test_active_bank_is_zombie_only(self):
        manifest = json.loads((DIRECTORY / "manifest.json").read_text())
        expected = {f"zombie_{kind}_{n:02}.wav" for kind in ("walker", "runner", "brute") for n in range(1, 4)}
        self.assertEqual(set(manifest), expected)
        self.assertEqual(len({clip["sha256"] for clip in manifest.values()}), 9)
        for name, info in manifest.items():
            with self.subTest(name=name):
                path = DIRECTORY / name
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), info["sha256"])
                self.assertEqual(info["license"], "CC0-1.0")
                self.assertTrue(info["source_url"].startswith("https://opengameart.org/content/"))
                self.assertIn("CC0", info["source"])
                with wave.open(str(path), "rb") as wav:
                    self.assertEqual((wav.getnchannels(), wav.getsampwidth(), wav.getframerate()), (1, 2, 44100))
                    x = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2") / 32768.
                self.assertGreater(len(x) / 44100, .30)
                self.assertLess(len(x) / 44100, 2.5)
                self.assertAlmostEqual(len(x) / 44100, info["duration_seconds"], delta=.0001)
                self.assertLess(np.max(np.abs(x)), .60)
                self.assertGreater(np.sqrt(np.mean(x ** 2)), .025)
                self.assertLess(abs(float(np.mean(x))), .003)
                self.assertLess(abs(float(x[0])), .0001)
                self.assertLess(abs(float(x[-1])), .0001)

    def test_source_downloads_have_auditable_hashes(self):
        sources = json.loads((ROOT / "assets/audio/revision-sources.json").read_text())
        self.assertEqual(len(sources), 7)
        for name, info in sources.items():
            with self.subTest(name=name):
                self.assertTrue(info["download_url"].startswith("https://opengameart.org/sites/default/files/"))
                self.assertEqual(len(info["sha256"]), 64)
        self.assertTrue((DIRECTORY / "LICENSE-CC0.txt").read_text().startswith("Creative Commons Legal Code"))

if __name__ == "__main__":
    unittest.main(verbosity=2)
