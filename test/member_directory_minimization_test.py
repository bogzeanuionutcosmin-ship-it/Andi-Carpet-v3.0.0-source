from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
class DirectoryMinimizationTest(unittest.TestCase):
    def test_directory_does_not_project_private_fields(self):
        source = (ROOT / 'functions/member_directory_projection.js').read_text()
        fields = re.search(r'const FIELDS = Object.freeze\(\[([^\]]+)\]\)', source, re.S)
        self.assertIsNotNone(fields)
        for private in ('profileFields', 'hireDate', 'address', 'email', 'notificationPreferences', 'effectivePermissions'):
            self.assertNotIn("'" + private + "'", fields.group(1))
        for required in ('name', 'phone', 'teamId', 'active'):
            self.assertIn("'" + required + "'", fields.group(1))
    def test_backfill_matches_backend_public_fields(self):
        backend = (ROOT / 'functions/index.js').read_text()
        migration = (ROOT / 'scripts/backfill_member_directory.js').read_text()
        self.assertIn("require('./member_directory_projection')", backend)
        self.assertIn("require('../functions/member_directory_projection')", migration)
        self.assertIn('projectMember(', backend)
        self.assertIn('projectMember(', migration)
    def test_hidden_admin_excluded(self):
        source = (ROOT / 'functions/member_directory_projection.js').read_text()
        self.assertIn("data.hiddenFromMembers === true || data.role === 'admin'", source)
    def test_member_directory_is_read_only(self):
        rules = (ROOT / 'firestore.rules').read_text()
        block = rules.split('match /memberDirectory/{userId} {')[1].split('}',1)[0]
        self.assertIn('allow create, update, delete: if false;', block)
if __name__ == '__main__': unittest.main()
