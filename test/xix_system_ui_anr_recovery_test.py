"""Fail-closed recovery tests for transient Android System UI ANR dialogs."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location(
    "restart", Path(__file__).parents[1] / "scripts/test_xix_operational_restart.py")
restart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restart)


def dialog(*nodes):
    root = ET.Element("hierarchy")
    for text, package, bounds in nodes:
        ET.SubElement(root, "node", {
            "text": text, "package": package, "bounds": bounds,
            "class": "android.widget.Button" if text == "Wait" else "android.widget.TextView",
            "clickable": "true" if text == "Wait" else "false",
        })
    return root


class SystemUiAnrRecoveryTest(unittest.TestCase):
    def test_wait_is_tapped_only_for_android_system_ui_anr(self):
        root = dialog(("System UI isn't responding", "android", "[30,40][100,80]"),
                      ("Wait", "android", "[20,100][80,140]"))
        with patch.object(restart, "adb", return_value=b"") as adb:
            recovered = restart.dismiss_system_ui_anr(root)
        self.assertTrue(recovered)
        adb.assert_called_once_with("shell", "input", "tap", "50", "120")

    def test_app_text_cannot_trigger_anr_recovery(self):
        root = dialog(("System UI isn't responding", restart.PACKAGE, "[30,40][100,80]"),
                      ("Wait", restart.PACKAGE, "[20,100][80,140]"))
        with patch.object(restart, "adb") as adb:
            self.assertFalse(restart.dismiss_system_ui_anr(root))
        adb.assert_not_called()

    def test_incomplete_system_dialog_fails_closed_without_tap(self):
        root = dialog(("System UI isn't responding", "android", "[30,40][100,80]"),)
        with patch.object(restart, "adb") as adb:
            self.assertFalse(restart.dismiss_system_ui_anr(root))
        adb.assert_not_called()

    def test_wait_screen_recovers_dialog_then_requires_real_app_screen(self):
        modal = dialog(("System UI isn't responding", "android", "[30,40][100,80]"),
                       ("Wait", "android", "[20,100][80,140]"))
        home = ET.Element("hierarchy")
        for text, selected in (("Acasă", "true"), ("Echipe acum", "false"),
                               ("Craiova XIX", "false")):
            ET.SubElement(home, "node", {
                "text": text, "package": restart.PACKAGE, "selected": selected,
            })
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(restart, "OUT", Path(directory)), \
                    patch.object(restart, "state", side_effect=[(modal, b"modal"), (home, b"home")]), \
                    patch.object(restart, "adb", return_value=b"screenshot") as adb, \
                    patch.object(restart.time, "sleep"):
                restart.wait_screen("restart", "Echipe acum", ("Acasă",),
                                   required=("Craiova XIX",), attempts=2)
                evidence = (restart.OUT / "restart-system-ui-anr.txt").read_text()
                self.assertIn("app screen must still pass validation", evidence)
                self.assertTrue((restart.OUT / "restart.png").is_file())
        self.assertTrue(any(call.args == ("shell", "input", "tap", "50", "120")
                            for call in adb.call_args_list))
        self.assertTrue(any(call.args == ("exec-out", "screencap", "-p")
                            for call in adb.call_args_list))


if __name__ == "__main__":
    unittest.main()
