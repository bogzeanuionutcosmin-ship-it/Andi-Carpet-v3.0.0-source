from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AdminSecurityIntegrationContractTest(unittest.TestCase):
    def test_private_profiles_restricted_to_owner_and_admin(self):
        rules = (ROOT / 'firestore.rules').read_text()
        block = rules.split('match /users/{userId} {', 1)[1].split('match /memberDirectory/', 1)[0]
        self.assertIn('allow get: if signedIn() && (request.auth.uid == userId || isAdmin());', block)
        self.assertIn('allow list: if isAdmin();', block)

    def test_directory_is_backend_write_only(self):
        rules = (ROOT / 'firestore.rules').read_text()
        block = rules.split('match /memberDirectory/{userId} {', 1)[1].split('}', 1)[0]
        self.assertIn('allow get, list: if isActive();', block)
        self.assertIn('allow create, update, delete: if false;', block)

    def test_trigger_uses_current_profile_transactionally(self):
        js = (ROOT / 'functions/index.js').read_text()
        block = js.split('exports.syncMemberDirectory = onDocumentWritten(', 1)[1].split('\n);', 1)[0]
        self.assertIn('db.runTransaction(', block)
        self.assertIn('transaction.get(userRef)', block)
        self.assertIn('transaction.delete(directoryRef)', block)
        self.assertIn('transaction.set(directoryRef, projection)', block)
        self.assertNotIn('event.data.after.data()', block)

    def test_member_profile_uses_public_directory_for_non_admin(self):
        dart = (ROOT / 'lib/members/member_profile_page.dart').read_text()
        self.assertIn("currentUser.role == UserRole.director || memberId == currentUser.id ? 'users' : 'memberDirectory'", dart)

    def test_migration_is_explicit_and_removes_stale_entries(self):
        script = (ROOT / 'scripts/backfill_member_directory.js').read_text()
        self.assertIn("process.argv.includes('--apply')", script)
        self.assertIn('if (!apply) return;', script)
        self.assertIn('db.runTransaction(async tx =>', script)
        self.assertIn('tx.get(userRef)', script)
        self.assertIn('tx.delete(directoryRef)', script)
        self.assertIn('tx.set(directoryRef, value)', script)

if __name__ == '__main__':
    unittest.main()
