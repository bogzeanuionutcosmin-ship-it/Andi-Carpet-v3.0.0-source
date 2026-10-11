"""Static guardrails for repository hygiene and previously broken features.

Runs with Python stdlib only; deliberately does not delete unreferenced assets.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepositoryHygieneTests(unittest.TestCase):
    def test_all_json_files_are_valid(self):
        for path in ROOT.rglob("*.json"):
            if any(part in {"build", ".dart_tool", "node_modules", ".git"} for part in path.parts):
                continue
            with self.subTest(path=str(path.relative_to(ROOT))):
                json.loads(path.read_text(encoding="utf-8"))

    def test_main_has_no_accidentally_appended_duplicate(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertEqual(source.count("class _Empty extends StatelessWidget"), 1)
        self.assertEqual(source.count("const Map<String,String> _andiStickerAssets"), 1)
        self.assertEqual(source.count("class PrivateChatPage extends StatefulWidget"), 1)
        self.assertNotIn("\n).hasMatch(normalized)) return null;", source)

    def test_sticker_asset_manifest_is_complete(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        self.assertIn("- assets/stickers/", pubspec)
        paths = re.findall(r"'brc_\\d+':'(assets/stickers/sticker_\\d+\\.png)'", source)
        self.assertEqual(len(paths), 32)
        self.assertEqual(len(set(paths)), 32)
        for relative in paths:
            with self.subTest(asset=relative):
                asset = ROOT / relative
                self.assertTrue(asset.is_file())
                self.assertEqual(asset.read_bytes()[:8], b"\\x89PNG\\r\\n\\x1a\\n")

    def test_manual_amount_and_map_route_regressions(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("RegExp(r'^\\d{1,9}(?:\\.\\d{1,2})?\\$').hasMatch(normalized)", source)
        self.assertIn("Schematic fallback when Mapbox cannot provide road geometry.", source)
        self.assertNotIn("for (final c in [number, amount, supplier, desc, litersC, priceC]) { c.dispose(); }", source)


if __name__ == "__main__":
    unittest.main()
