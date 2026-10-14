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
        self.assertEqual(module.count(".snapshots().listen("),2)
        for source in ("categories", "backgrounds", "functions"):
            self.assertEqual(module.count(f"sources.{source}().listen("), 1)
        core=home.split("  void _startCoreSync() {",1)[1].split("  Future<void> _writeLearningEvent(",1)[0]
        self.assertLess(core.index("_startDefinitionsSync(db);"),core.index("_startDirectorySync(db);"))
        self.assertIn("if (isAdmin) {\n      _startAuditSync(db);",core)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }",home)

    def test_safety_boundaries_and_side_effects_remain(self):
        module=(ROOT/"lib/home/home_directory_definitions_audit_sync.dart").read_text()
        for fragment in ("if (!isAdmin) return;", "collection('audit').orderBy('at', descending: true).limit(500)",
                         "sources.categories().listen(","sources.backgrounds().listen(",
                         "sources.functions().listen(", "sources.directory(isAdmin: isAdmin)",
                         "_syncUserPermissionSnapshots()", "_applyTeamMembership()",
                         "_startFinancialSync()", "coreSyncError = 'Audit: $e'",
                         "coreSyncError = 'Conturi: $e'"):
            with self.subTest(fragment=fragment): self.assertIn(fragment,module)

    def test_directory_visibility_and_seed_side_effects_survive_alternate_pr(self):
        module = (ROOT / "lib/home/home_directory_definitions_audit_sync.dart").read_text(encoding="utf-8")
        audit = module.split("  void _startAuditSync(", 1)[1].split("  void _startDefinitionsSync(", 1)[0]
        definitions = module.split("  void _startDefinitionsSync(", 1)[1].split("  void _startDirectorySync(", 1)[0]
        directory = module.split("  void _startDirectorySync(", 1)[1]
        self.assertIn("if (!isAdmin) return;", audit)
        self.assertIn("_seedDefinitionsIfNeeded()", definitions)
        self.assertIn("sources.directory(isAdmin: isAdmin)", directory)
        adapter = (ROOT / "lib/home/home_identity_queries.dart").read_text(encoding="utf-8")
        self.assertIn("isAdmin ? db.collection('users') : db.collection('memberDirectory')", adapter)
        self.assertIn("db.collection('users').doc(uid)", adapter)
        for symbol in ("hiddenFromMembers", "_hiddenUserIds", "_userTeamCache",
                       "_personalNotificationPreferences", "_lastGroupChatSeenAt"):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, directory)
