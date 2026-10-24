import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('pdf_text', Path(__file__).resolve().parents[1] / 'scripts/verify_xix_pdf_text.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PdfTextTest(unittest.TestCase):
    def setUp(self):
        self.markers = [f'Craiova {i:02}' for i in range(1, 12)]
        self.scenario = {'pdfMarkers': self.markers, 'plannedRowName': 'Craiova planificată'}
        self.rows = [f'{m}    15.10.2026    23:55    00:20    —    X\n{m}' for m in self.markers]
        self.tail = '\nCraiova planificată    16.10.2026\nNeexecutată'

    def test_address_can_repeat_location_name(self):
        module.verify('\n'.join(self.rows) + self.tail, self.scenario)

    def test_duplicate_intervention_row_is_rejected(self):
        with self.assertRaises(AssertionError):
            module.verify('\n'.join(self.rows + [self.rows[1]]) + self.tail, self.scenario)

    def test_address_does_not_substitute_for_missing_intervention(self):
        self.rows[1] = self.markers[1]
        with self.assertRaises(AssertionError):
            module.verify('\n'.join(self.rows) + self.tail, self.scenario)


if __name__ == '__main__':
    unittest.main()
