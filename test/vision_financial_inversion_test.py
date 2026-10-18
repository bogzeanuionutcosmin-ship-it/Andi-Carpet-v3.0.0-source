"""Diagnostic-only insertions must preserve every financial/OCR statement."""
from pathlib import Path
import hashlib
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
BASE_SHA = "b2b13147cb62ec2904a0bbab4f014fc83130c4c5"
EXPECTED = {'lib/expenses/expense_document_actions.dart': 'eba7347c721d6577bcfa172506e2363c67df8b82852b26fa88af01d8b4c9e46d', 'lib/expenses/expense_per_diem_actions.dart': '4bbb599d5defef4438fdc5f16d38553402b00d9fd23262077f91325e625ff3c4', 'lib/expenses/expense_settlement_actions.dart': '4401122236c1e2e448104959824d3a9142f711c48ed50aae197e6a680df3af90'}

class VisionFinancialInversion(unittest.TestCase):
    def test_expense_actions_reconstruct_byte_exact_after_removing_hooks(self):
        for path, expected in EXPECTED.items():
            with self.subTest(path=path):
                source = (ROOT / path).read_text()
                # Whole-line and inline insertions, no business code removed.
                source = re.sub(r"^ +if \(_visionSessionActive\) VisionErrorTelemetry\.report\([^;]+;\n", "", source, flags=re.M)
                source = re.sub(r"if \(_visionSessionActive\) VisionErrorTelemetry\.report\([^;]+; ", "", source)
                self.assertEqual(hashlib.sha256(source.encode()).hexdigest(), expected)
