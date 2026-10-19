"""Regression checks for fail-closed Android restart screen diagnostics."""
import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts/test_xix_operational_restart.py"
spec = importlib.util.spec_from_file_location("xix_restart", SCRIPT)
restart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restart)


class RestartDiagnosticsTests(unittest.TestCase):
    def test_expected_screen_is_not_inferred_from_unrelated_labels(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(
            '<hierarchy><node package="com.example.andi_carpeta" '
            'text="Autentificare" content-desc="Acas\u0103"/></hierarchy>'
        )
        self.assertFalse(restart.app_screen_matches(
            root, "Echipe acum", ("Acas\u0103",), ("Craiova XIX",)
        ))

    def test_other_package_cannot_impersonate_expected_screen(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(
            '<hierarchy><node package="com.example.other" text="Echipe acum" '
            'content-desc="Craiova XIX\nAcasă" /></hierarchy>'
        )
        self.assertFalse(restart.app_screen_matches(
            root, "Echipe acum", ("Acasă",), ("Craiova XIX",)
        ))

    def test_wrong_selected_tab_is_rejected(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring(
            '<hierarchy><node package="com.example.andi_carpeta" '
            'text="Echipe acum" content-desc="Craiova XIX\nAcasă" />'
            '<node package="com.example.andi_carpeta" selected="true" '
            'text="Grafic" /></hierarchy>'
        )
        self.assertFalse(restart.app_screen_matches(
            root, "Echipe acum", ("Acasă",), ("Craiova XIX",)
        ))

    def test_crash_filter_only_matches_target_application(self):
        other = "FATAL EXCEPTION: main\nProcess: com.example.other, PID: 1\n"
        own = "FATAL EXCEPTION: main\nProcess: com.example.andi_carpeta, PID: 2\n"
        self.assertFalse(restart.own_crash(other))
        self.assertTrue(restart.own_crash(own))

    def test_missing_screen_still_fails_and_writes_evidence(self):
        import xml.etree.ElementTree as ET
        xml = (b'<hierarchy><node package="com.example.andi_carpeta" '
               b'text="Intrati in cont" content-desc="" /></hierarchy>')
        root = ET.fromstring(xml)
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(restart, "OUT", pathlib.Path(tmp)), \
                 patch.object(restart, "state", return_value=(root, xml)), \
                 patch.object(restart, "adb", side_effect=lambda *args: (
                     b"PNG" if args[0] == "exec-out" else b"mCurrentFocus=Login"
                 )), \
                 patch.object(restart.time, "sleep"):
                with self.assertRaisesRegex(AssertionError, "Expected loaded main-entry screen absent"):
                    restart.wait_screen("missing", "Echipe acum", ("Acas\u0103",),
                                        required=("Craiova XIX",), attempts=1)
            self.assertTrue((pathlib.Path(tmp) / "missing-failure.xml").exists())
            self.assertTrue((pathlib.Path(tmp) / "missing.png").exists())
            self.assertIn("Login", (pathlib.Path(tmp) / "missing-window-focus.txt").read_text())


if __name__ == "__main__":
    unittest.main()
