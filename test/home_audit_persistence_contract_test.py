"""Structural regression tests for extracted HomePage audit and batch persistence.

No Firebase calls; the normal CI suite additionally compiles Flutter and runs
the isolated Firestore authorization emulator.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "lib/home/home_page.dart"
MODULE = ROOT / "lib/home/home_audit_persistence.dart"


class HomeAuditPersistenceContracts(unittest.TestCase):
    def test_two_methods_moved_once_and_lifecycle_stays_in_home_page(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = HOME.read_text(encoding="utf-8")
        module = MODULE.read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_audit_persistence.dart';"), 1)
        self.assertTrue(module.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeAuditPersistence on _HomePageState {", module)
        for name in ("_writeAuditRemote", "_persistCoreData"):
            with self.subTest(name=name):
                signature = f"  Future<void> {name}("
                self.assertEqual(module.count(signature), 1)
                self.assertNotIn(signature, home)
        self.assertIn("  @override\n  void dispose()", home)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }", home)
        self.assertIn("for (final sub in _financialSubscriptions) { sub.cancel(); }", home)
        self.assertIn("  void log(String action, String target)", home)
        self.assertIn("_writeAuditRemote(action, target)", home)

    def test_audit_firestore_and_learning_behavior_retained(self):
        module = MODULE.read_text(encoding="utf-8")
        for item in (
            "AuditEntry(id: idNow()", "if (isAdmin && mounted)",
            "setState(() => audit.insert(0, entry));",
            "collection('audit').doc(entry.id).set(",
            "'actorUid': currentUserId",
            "'at': Timestamp.fromDate(entry.at)",
            "_writeLearningEvent(category: 'operations', event: 'audit_action'",
            "} catch (_) {",
        ):
            with self.subTest(contract=item):
                self.assertIn(item, module)

    def test_admin_only_batch_and_commit_before_cache_update(self):
        module = MODULE.read_text(encoding="utf-8")
        self.assertIn("if (!isAdmin) return;", module)
        self.assertEqual(module.count("await batch.commit();"), 1)
        self.assertIn("if (writes == 0) return;", module)
        self.assertIn("final batch = db.batch();", module)
        for name in ("locations", "teams", "cars", "users"):
            with self.subTest(collection=name):
                self.assertIn(f"db.collection('{name}')", module)
        for cache, pending in (
            ("_locationCache", "pendingLocations"),
            ("_teamCache", "pendingTeams"),
            ("_carCache", "pendingCars"),
            ("_userTeamCache", "pendingUsers"),
        ):
            with self.subTest(cache=cache):
                statement = f"{cache}.addAll({pending});"
                self.assertEqual(module.count(statement), 1)
                self.assertLess(module.index("await batch.commit();"), module.index(statement))
        self.assertEqual(module.count("SetOptions(merge: true)"), 4)
