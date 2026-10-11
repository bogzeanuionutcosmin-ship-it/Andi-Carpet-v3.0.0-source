from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AdminPrivacyContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules=(ROOT/'firestore.rules').read_text()
        cls.dart=(ROOT/'lib/main.dart').read_text() + '\n' + (ROOT/'lib/home/home_page.dart').read_text()
        cls.js=(ROOT/'functions/index.js').read_text()
    def test_private_profiles_no_member_read(self):
        block=self.rules.split('match /users/{userId} {')[1].split('match /memberDirectory/')[0]
        self.assertIn('allow get: if signedIn() && (request.auth.uid == userId || isAdmin());',block)
        self.assertIn('allow list: if isAdmin();',block)
    def test_public_directory_read_only(self):
        block=self.rules.split('match /memberDirectory/{userId} {')[1].split('match /locations/')[0]
        self.assertIn('allow create, update, delete: if false;',block)
    def test_member_queries_migrated(self):
        self.assertIn("isAdmin ? db.collection('users') : db.collection('memberDirectory')",self.dart)
        self.assertIn("widget.currentUser.role == UserRole.director ? FirebaseFirestore.instance.collection('users') : FirebaseFirestore.instance.collection('memberDirectory')",self.dart)
    def test_hidden_admin_excluded_from_projection(self):
        self.assertIn("data.hiddenFromMembers === true || data.role === 'admin'",(ROOT/'functions/member_directory_projection.js').read_text())
        self.assertIn("exports.syncMemberDirectory",self.js)
    def test_backfill_is_opt_in(self):
        script=(ROOT/'scripts/backfill_member_directory.js').read_text()
        self.assertIn("process.argv.includes('--apply')",script)
        self.assertIn("if (!apply) return",script)
if __name__=='__main__':unittest.main()
