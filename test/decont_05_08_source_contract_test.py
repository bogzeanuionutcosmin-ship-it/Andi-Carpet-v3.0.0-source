"""Static source contracts; run with python3 -m unittest discover -s test -p '*source_contract_test.py'."""
import pathlib
import unittest

LIB = pathlib.Path(__file__).resolve().parents[1] / 'lib'
SRC = LIB / 'main.dart'
REPORTS = LIB / 'reports' / 'pdf_reports.dart'
EXPENSES = LIB / 'expenses' / 'expense_page.dart'

class DecontSourceContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SRC.read_text(encoding='utf-8') + '\n' + REPORTS.read_text(encoding='utf-8') + '\n' + EXPENSES.read_text(encoding='utf-8')

    def test_pdf_deduplicates_expenses_and_payments(self):
        self.assertIn('expenseIds.add(e.id)', self.source)
        self.assertIn('paymentIds.add(d.id)', self.source)

    def test_pdf_received_totals_derive_from_unique_entries(self):
        self.assertIn('uniqueReceiptIds.add(e.id)', self.source)
        self.assertIn('final receivedDeparture = rawReceipts.isEmpty', self.source)

    def test_annual_only_confirmed_actual_receipts(self):
        self.assertIn('d.actualReceivedAmount!.isFinite', self.source)
        self.assertIn('dateOk(d.confirmedAt??d.date)', self.source)

    def test_pdf_sections(self):
        for label in ('1. BONURI COMBUSTIBIL','2. FACTURI','3. DIURNE', '4. ALTE CHELTUIELI','REZUMAT','DESFĂȘURĂTOR SUME PRIMITE'):
            self.assertIn(label, self.source)

if __name__ == '__main__':
    unittest.main()
