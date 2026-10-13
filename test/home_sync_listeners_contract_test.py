"""Structural regression for HomePage Firestore listener extraction.

Does not connect to Firebase; the Flutter tests and web build compile the Dart library.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
GROUP_NAMES = (
    "_startOwnProfileSync",
    "_startOperationsSync",
    "_startNotificationSync",
    "_startChatSync",
    "_startSettingsSync",
)


class HomeSyncListenersContracts(unittest.TestCase):
    def test_listeners_are_a_single_dart_part_with_no_duplicate_methods(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        listeners = (ROOT / "lib/home/home_sync_listeners.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_sync_listeners.dart';"), 1)
        self.assertTrue(listeners.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeSyncListeners on _HomePageState {", listeners)
        for name in GROUP_NAMES:
            signature = f"  void {name}(FirebaseFirestore db) {{"
            with self.subTest(name=name):
                self.assertEqual(listeners.count(signature), 1)
                self.assertNotIn(signature, home)
                self.assertEqual(home.count(name + "(db);"), 1)

    def test_original_firestore_listener_count_and_order_are_unchanged(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        listeners = (ROOT / "lib/home/home_sync_listeners.dart").read_text(encoding="utf-8")
        self.assertEqual(listeners.count("_coreSubscriptions.add("), 10)
        self.assertEqual(listeners.count(".snapshots().listen("), 10)
        # The other 5 core subscriptions live in the catalog/directory/audit part.
        managed = (ROOT / "lib/home/home_catalog_sync.dart").read_text(encoding="utf-8")
        self.assertEqual(managed.count("_coreSubscriptions.add("), 5)
        order = [name for name in GROUP_NAMES if (
            f"  void {name}(FirebaseFirestore db) {{" in listeners
        )]
        self.assertEqual(order, list(GROUP_NAMES))
        offsets = [listeners.index(f"  void {name}(FirebaseFirestore db) {{")
                   for name in GROUP_NAMES]
        self.assertEqual(offsets, sorted(offsets))
        core = home.split("  void _startCoreSync() {", 1)[1].split(
            "  Future<void> _writeLearningEvent(", 1
        )[0]
        calls = re.findall(r"^    (_start\w+Sync)\(db\);$", core, re.MULTILINE)
        self.assertEqual(calls, [
            "_startDefinitionsSync", "_startDirectorySync", *GROUP_NAMES,
        ])
        self.assertNotIn(".snapshots()", core)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }", home)

    def test_listener_payloads_still_use_original_collections_and_errors(self):
        listeners = (ROOT / "lib/home/home_sync_listeners.dart").read_text(encoding="utf-8")
        for expected in (
            "collection('users').doc(currentUserId)",
            "collection('teams')", "collection('cars')", "collection('locations')",
            "collection('schedules')", "collection('records')",
            "collection('notifications')", "collection('chatMessages')",
            "collection('groupChatMessages')",
            "collection('meta').doc('uiSettings')",
            "Profil propriu: $e", "Echipe: $e", "Mașini: $e",
            "Locații: $e", "Grafice de lucru: $e", "Execuții: $e",
            "Notificări: $e", "Mesaje: $e", "Chat comun: $e", "Setări UI: $e",
            "orderBy('createdAt', descending: true).limit(20)",
            "_maybeAutoCloseResolvedSchedules(",
            "_startFinancialSync();",
            "_runAutomaticMaintenance()",
        ):
            with self.subTest(contract=expected):
                self.assertIn(expected, listeners)


if __name__ == "__main__":
    unittest.main()
