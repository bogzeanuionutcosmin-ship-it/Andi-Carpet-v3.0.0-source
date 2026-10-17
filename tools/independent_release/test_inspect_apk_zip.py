import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from inspect_apk_zip import inspect


class ApkZipStructureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.apk = Path(self.tmp.name) / "synthetic.apk"

    def write(self, entries):
        with zipfile.ZipFile(self.apk, "w") as archive:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                for name, content in entries:
                    archive.writestr(name, content)

    def test_minimal_synthetic_structure_never_approves_release(self):
        self.write([("AndroidManifest.xml", b"fake"), ("classes.dex", b"fake")])
        result = inspect(self.apk)
        self.assertTrue(result["zip_structure_pass"])
        self.assertFalse(result["signature_verified"])
        self.assertFalse(result["installability_verified"])
        self.assertFalse(result["release_approved"])

    def test_missing_manifest_and_dex(self):
        self.write([("assets/a.txt", b"x")])
        self.assertEqual(inspect(self.apk)["findings"],
                         ["missing_android_manifest", "missing_primary_dex"])

    def test_duplicate_zip_member(self):
        self.write([("AndroidManifest.xml", b"a"), ("classes.dex", b"b"),
                    ("classes.dex", b"c")])
        self.assertIn("duplicate_entry_name", inspect(self.apk)["findings"])

    def test_path_traversal(self):
        self.write([("AndroidManifest.xml", b"a"), ("classes.dex", b"b"),
                    ("../escape", b"c")])
        self.assertIn("unsafe_entry_path", inspect(self.apk)["findings"])

    def test_backslash_entry_path_rejected(self):
        self.write([("AndroidManifest.xml", b"a"), ("classes.dex", b"b"),
                    (r"assets\\..\\escape", b"c")])
        self.assertIn("unsafe_entry_path", inspect(self.apk)["findings"])

    def test_encrypted_flag_detected_without_decompression(self):
        self.write([("AndroidManifest.xml", b"a"), ("classes.dex", b"b")])
        payload = bytearray(self.apk.read_bytes())
        offset = payload.index(b"PK\x01\x02")
        payload[offset + 8] |= 1
        self.apk.write_bytes(payload)
        self.assertIn("encrypted_zip_entry", inspect(self.apk)["findings"])

    def test_non_zip_rejected(self):
        self.apk.write_bytes(b"not an apk")
        with self.assertRaises(ValueError):
            inspect(self.apk)


if __name__ == "__main__":
    unittest.main()
