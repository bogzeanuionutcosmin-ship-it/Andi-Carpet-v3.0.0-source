import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from verify_apk_manifest import verify


class VerifyApkManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "candidate.apk"
        self.apk.write_bytes(b"synthetic apk fixture; not an executable package")
        self.manifest = self.root / "manifest.json"
        self.expected = hashlib.sha256(self.apk.read_bytes()).hexdigest()

    def write_manifest(self, digest):
        self.manifest.write_text(json.dumps({"sha256": digest}), encoding="utf-8")

    def test_matching_hash_does_not_approve_release(self):
        self.write_manifest(self.expected)
        result = verify(self.apk, self.manifest)
        self.assertTrue(result["hash_matches"])
        self.assertFalse(result["signature_verified"])
        self.assertFalse(result["release_approved"])

    def test_mismatched_hash(self):
        self.write_manifest("0" * 64)
        self.assertFalse(verify(self.apk, self.manifest)["hash_matches"])

    def test_invalid_manifest_hash(self):
        self.write_manifest("invalid")
        with self.assertRaises(ValueError):
            verify(self.apk, self.manifest)

    def test_manifest_must_be_object(self):
        self.manifest.write_text("[]", encoding="utf-8")
        with self.assertRaises(ValueError):
            verify(self.apk, self.manifest)

    def test_missing_apk(self):
        self.write_manifest(self.expected)
        self.apk.unlink()
        with self.assertRaises(ValueError):
            verify(self.apk, self.manifest)


    def test_duplicate_manifest_keys_rejected(self):
        self.manifest.write_text('{"sha256":"' + self.expected + '","sha256":"' + self.expected + '"}', encoding="utf-8")
        with self.assertRaises(ValueError):
            verify(self.apk, self.manifest)

    def test_uppercase_digest_is_accepted(self):
        self.write_manifest(self.expected.upper())
        result = verify(self.apk, self.manifest)
        self.assertTrue(result["hash_matches"])
        self.assertEqual(result["expected_sha256"], self.expected)

    def test_manifest_without_sha256_is_rejected(self):
        self.manifest.write_text("{}", encoding="utf-8")
        with self.assertRaises(ValueError):
            verify(self.apk, self.manifest)

if __name__ == "__main__":
    unittest.main()
