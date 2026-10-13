"""Contract tests for extracted catalog, directory and audit subscriptions.

These static checks do not connect to production; Flutter compilation and tests
are required to validate the shared Dart library after moving the methods.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "lib/home/home_catalog_sync.dart"
HOME = ROOT / "lib/home/home_page.dart"
NAMES = ("_startAuditSync", "_startDefinitionsSync", "_startDirectorySync")


class HomeCatalogSyncTests(unittest.TestCase):
    def test_part_and_method_ownership_without_duplication(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = HOME.read_text(encoding="utf-8")
        catalog = CATALOG.read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_catalog_sync.dart';"), 1)
        self.assertTrue(catalog.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeCatalogSync on _HomePageState {", catalog)
        for name in NAMES:
            with self.subTest(name=name):
                signature = f"  void {name}(FirebaseFirestore db) {{"
                self.assertEqual(catalog.count(signature), 1)
                self.assertNotIn(signature, home)
                self.assertEqual(home.count(name + "(db);"), 1)
        positions = [catalog.index(f"  void {name}(FirebaseFirestore db) {{") for name in NAMES]
        self.assertEqual(positions, sorted(positions))

    def test_core_subscription_count_order_and_disposal(self):
        home = HOME.read_text(encoding="utf-8")
        catalog = CATALOG.read_text(encoding="utf-8")
        listeners = (ROOT / "lib/home/home_sync_listeners.dart").read_text(
            encoding="utf-8"
        )
        self.assertEqual(catalog.count("_coreSubscriptions.add("), 5)
        self.assertEqual(catalog.count(".snapshots().listen("), 5)
        self.assertEqual(listeners.count("_coreSubscriptions.add("), 10)
        self.assertEqual(
            catalog.count("_coreSubscriptions.add(")
            + listeners.count("_coreSubscriptions.add("),
            15,
        )
        core = home.split("  void _startCoreSync() {", 1)[1].split(
            "  Future<void> _writeLearningEvent(", 1
        )[0]
        self.assertEqual(
            re.findall(r"^    (_start\w+Sync)\(db\);$", core, re.MULTILINE),
            [
                "_startDefinitionsSync", "_startDirectorySync",
                "_startOwnProfileSync", "_startOperationsSync",
                "_startNotificationSync", "_startChatSync", "_startSettingsSync",
            ],
        )
        self.assertIn("if (isAdmin) {\n      _startAuditSync(db);", core)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }", home)

    def test_authorization_scope_and_critical_side_effects(self):
        src = CATALOG.read_text(encoding="utf-8")
        audit = src.split("  void _startAuditSync(", 1)[1].split(
            "  void _startDefinitionsSync(", 1
        )[0]
        definitions = src.split("  void _startDefinitionsSync(", 1)[1].split(
            "  void _startDirectorySync(", 1
        )[0]
        directory = src.split("  void _startDirectorySync(", 1)[1]
        self.assertIn("if (!isAdmin) return;", audit)
        self.assertIn("db.collection('audit').orderBy('at', descending: true).limit(500)", audit)
        for name in ("locationCategories", "backgrounds", "functions"):
            self.assertIn("db.collection('" + name + "')", definitions)
        self.assertIn("_syncUserPermissionSnapshots()", definitions)
        self.assertIn("_seedDefinitionsIfNeeded()", definitions)
        self.assertIn("_startFinancialSync()", definitions)
        self.assertIn(
            "isAdmin ? db.collection('users') : db.collection('memberDirectory')",
            directory,
        )
        for contract in (
            "hiddenFromMembers", "_hiddenUserIds",
            "_userTeamCache", "_applyTeamMembership()",
            "_personalNotificationPreferences", "_lastGroupChatSeenAt",
            "_startFinancialSync()", "coreSyncError = 'Conturi: $e'",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, directory)


if __name__ == "__main__":
    unittest.main()
