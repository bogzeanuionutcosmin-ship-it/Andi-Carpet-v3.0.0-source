"""HomePage CRUD extraction guards: location, schedule and centralizer records.

Static contracts intentionally supplement, rather than replace, the Flutter
unit/widget suite and Firestore emulator authorization tests.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "lib/home/home_operational_write_actions.dart"
HOME = ROOT / "lib/home/home_page.dart"


class HomeOperationalWriteActionsContracts(unittest.TestCase):
    def test_exactly_four_operational_actions_in_separate_part(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = HOME.read_text(encoding="utf-8")
        module = MODULE.read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'home/home_operational_write_actions.dart';"), 1)
        self.assertTrue(module.startswith("part of '../main.dart';"))
        self.assertIn("extension _HomeOperationalWriteActions on _HomePageState {", module)
        for name in (
            "_deleteLocationDirect", "_saveLocationDirect",
            "_saveScheduleDirect", "_saveRecordDirect",
        ):
            with self.subTest(name=name):
                signature = f"  Future<void> {name}("
                self.assertEqual(module.count(signature), 1)
                self.assertNotIn(signature, home)

    def test_permissions_and_firestore_operations_remain_unchanged(self):
        module = MODULE.read_text(encoding="utf-8")
        expected = (
            "Doar Adminul poate șterge locații.",
            "Doar Adminul poate modifica locații.",
            "!canEditTeam(schedule.teamId) || !hasPermission(FunctionPermission.editProgram)",
            "hasPermission(FunctionPermission.editProgram) || hasPermission(FunctionPermission.editCentralizer)",
            "!canEditTeam(record.teamId) || !canWriteRecord",
            "collection('locations').doc(id).delete()",
            "collection('locations').doc(l.id).set(data, SetOptions(merge: true))",
            "collection('schedules').doc(schedule.id).set(data, SetOptions(merge: true))",
            "collection('records').doc(record.id).set(data, SetOptions(merge: true))",
        )
        for item in expected:
            with self.subTest(contract=item):
                self.assertIn(item, module)

    def test_learning_cache_and_ui_updates_are_not_lost(self):
        module = MODULE.read_text(encoding="utf-8")
        for item in (
            "event: 'location_deleted'", "event: 'location_saved'",
            "event: 'schedule_saved'", "event: 'execution_${record.status.name}'",
            "_locationCache.remove(id)", "_locationCache[l.id] = _encoded(data)",
            "_scheduleCache[schedule.id] = _encoded(data)",
            "_recordCache[record.id] = _encoded(data)",
            "setState(() => locations.removeWhere((x) => x.id == id));",
            "setState(() {", "locations.sort((a, b) => a.id.compareTo(b.id));",
        ):
            with self.subTest(contract=item):
                self.assertIn(item, module)
