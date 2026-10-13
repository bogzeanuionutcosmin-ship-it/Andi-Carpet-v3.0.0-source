"""Document library regressions: Android PDF download must NOT be share-only."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = (ROOT / 'lib/documents/documents_page.dart').read_text(encoding='utf-8')
NATIVE = (ROOT / 'lib/download_file_stub.dart').read_text(encoding='utf-8')
WEB = (ROOT / 'lib/download_file_web.dart').read_text(encoding='utf-8')
CATEGORIES = (ROOT / 'lib/documents/document_categories.dart').read_text(encoding='utf-8')

class DocumentsDownloadContract(unittest.TestCase):
    def test_real_file_save_and_separate_sharing(self):
        self.assertIn("FilePicker.saveFile(", NATIVE)
        self.assertIn("bytes: bytes", NATIVE)
        self.assertIn("mimeType: mimeType", NATIVE)
        self.assertIn("return destination != null;", NATIVE)
        self.assertNotIn("Printing.sharePdf", NATIVE)
        self.assertIn("Printing.sharePdf(", DOCUMENTS)
        self.assertIn("'Descarcă PDF'", DOCUMENTS)
        self.assertIn("'Partajează PDF'", DOCUMENTS)
        self.assertIn("if (!mounted || !saved) return;", DOCUMENTS)
        self.assertIn("anchor.click()", WEB)

    def test_pv_metadata_is_not_fake_attachment(self):
        self.assertIn("Fișă informativă — PDF neatașat", DOCUMENTS)
        self.assertIn("Această funcție NU încarcă un fișier PDF", DOCUMENTS)
        self.assertIn("isProtocolDocument(", DOCUMENTS)
        self.assertIn("c == 'proces verbal'", CATEGORIES)
        self.assertNotIn("FirebaseStorage", DOCUMENTS)
        self.assertNotIn("documentImageBase64", DOCUMENTS)

    def test_magic_asset_cannot_be_deleted_and_admin_hide_is_confirmed(self):
        self.assertIn("_magicVisibilityId", DOCUMENTS)
        self.assertIn("if (!widget.isAdmin) return;", DOCUMENTS)
        self.assertIn("if (approved != true) return;", DOCUMENTS)
        self.assertIn("'visible': visible", DOCUMENTS)
        self.assertIn("Fișierul PDF inclus în aplicație NU va fi șters", DOCUMENTS)
        self.assertIn("document.id == _magicVisibilityId", DOCUMENTS)

    def test_metadata_delete_requires_admin_and_confirmation(self):
        self.assertIn("_deleteDocument(", DOCUMENTS)
        self.assertIn("document.reference.delete()", DOCUMENTS)
        self.assertIn("Șterge fișa documentului?", DOCUMENTS)
        self.assertIn("if (!widget.isAdmin || document.id == _magicVisibilityId) return;", DOCUMENTS)

if __name__ == '__main__':
    unittest.main()
