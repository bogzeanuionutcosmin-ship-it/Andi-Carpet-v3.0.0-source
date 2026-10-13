"""Read-only structural guarantees for three extracted HomePage sync groups."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class HomeDirectorySyncContracts(unittest.TestCase):
    def test_three_methods_exactly_once_and_called_in_same_order(self):
        main=(ROOT/"lib/main.dart").read_text()
        home=(ROOT/"lib/home/home_page.dart").read_text()
        module=(ROOT/"lib/home/home_directory_definitions_audit_sync.dart").read_text()
        self.assertEqual(main.count("part 'home/home_directory_definitions_audit_sync.dart';"),1)
        self.assertTrue(module.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeDirectoryDefinitionsAuditSync on _HomePageState {",module)
        for name in ("_startAuditSync","_startDefinitionsSync","_startDirectorySync"):
            sig=f"  void {name}(FirebaseFirestore db) {{"
            self.assertEqual(module.count(sig),1)
            self.assertNotIn(sig,home)
            self.assertIn(name+"(db);",home)
        self.assertEqual(module.count("_coreSubscriptions.add("),5)
        self.assertEqual(module.count(".snapshots().listen("),5)
        core=home.split("  void _startCoreSync() {",1)[1].split("  Future<void> _writeLearningEvent(",1)[0]
        self.assertLess(core.index("_startDefinitionsSync(db);"),core.index("_startDirectorySync(db);"))
        self.assertIn("if (isAdmin) {\n      _startAuditSync(db);",core)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }",home)

    def test_safety_boundaries_and_side_effects_remain(self):
        module=(ROOT/"lib/home/home_directory_definitions_audit_sync.dart").read_text()
        for fragment in ("if (!isAdmin) return;", "collection('audit').orderBy('at', descending: true).limit(500)",
                         "db.collection('locationCategories')","db.collection('backgrounds')",
                         "db.collection('functions')", "db.collection('users') : db.collection('memberDirectory')",
                         "_syncUserPermissionSnapshots()", "_applyTeamMembership()",
                         "_startFinancialSync()", "coreSyncError = 'Audit: $e'",
                         "coreSyncError = 'Conturi: $e'"):
            with self.subTest(fragment=fragment): self.assertIn(fragment,module)
