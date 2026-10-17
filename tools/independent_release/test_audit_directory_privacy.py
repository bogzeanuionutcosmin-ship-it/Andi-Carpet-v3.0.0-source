import unittest
from audit_directory_privacy import audit


class DirectoryPrivacyAuditTests(unittest.TestCase):
    def test_sensitive_fields_require_human_approval(self):
        result = audit("const FIELDS = Object.freeze(['name', 'phone', 'photoBase64']);")
        self.assertEqual(result["privacy_review_fields"], ["phone", "photoBase64"])
        self.assertTrue(result["privacy_owner_approval_required"])
        self.assertFalse(result["privacy_approved"])
        self.assertFalse(result["production_safe"])

    def test_nonsensitive_projection_still_not_approved(self):
        result = audit("const FIELDS = Object.freeze(['name', 'teamId']);")
        self.assertEqual(result["privacy_review_fields"], [])
        self.assertFalse(result["privacy_owner_approval_required"])
        self.assertFalse(result["production_safe"])

    def test_unknown_structure_fails_closed(self):
        with self.assertRaises(ValueError):
            audit("const FIELDS = getFields();")

    def test_duplicate_fields_rejected(self):
        with self.assertRaises(ValueError):
            audit("const FIELDS = Object.freeze(['name', 'name']);")


if __name__ == "__main__":
    unittest.main()
