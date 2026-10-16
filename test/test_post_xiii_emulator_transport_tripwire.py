"""Review-only source tripwire: XIII transport must stay emulator-scoped.

This is a source contract, not a proof that emulator data is isolated.
"""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1]
          / "lib/finance/session_xiii/session_fence_firestore_xiii.dart")


class EmulatorTransportTripwireTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_constructor_remains_emulator_only(self):
        self.assertIn("SessionXiiiFirestorePort.emulator(", self.source)
        self.assertIn("projectId.startsWith('demo-')", self.source)
        self.assertIn("session_xiii_emulator_required", self.source)
        self.assertIn("useFirestoreEmulator('127.0.0.1', 8080)", self.source)

    def test_authority_document_write_is_forbidden(self):
        self.assertIn("session_xiii_authority_write_forbidden", self.source)

    def test_server_read_is_explicit(self):
        self.assertIn("GetOptions(source: Source.server)", self.source)


if __name__ == "__main__":
    unittest.main()
