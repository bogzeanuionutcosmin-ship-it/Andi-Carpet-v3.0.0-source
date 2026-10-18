"""Synthetic accessibility/log fixtures; no adb or Firebase is executed."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('restart', Path(__file__).parents[1] / 'scripts/test_xix_operational_restart.py')
restart = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restart)


def fixture(*entries):
    root = ET.Element('hierarchy')
    for text, selected in entries:
        ET.SubElement(root, 'node', {'content-desc': text, 'selected': selected,
                                  'clickable': 'true', 'bounds': '[0,0][100,50]'})
    return root


class RestartEvidenceParserTest(unittest.TestCase):
    def test_navigation_label_and_warning_do_not_prove_loaded_screen(self):
        root = fixture(('Acasă', 'true'), ('Grafic', 'false'),
                       ('În Grafic de lucru poți recalcula traseul rămas.', 'false'))
        self.assertFalse(restart.screen_matches(root, 'Echipe acum', ('Acasă',), ('Craiova XIX',)))
        self.assertFalse(restart.screen_matches(root, 'Grafic de lucru', ('Grafic',)))

    def test_exact_headings_require_loaded_team_and_matching_selected_tab(self):
        home = fixture(('Acasă', 'true'), ('Echipe acum', 'false'), ('Craiova XIX', 'false'))
        self.assertTrue(restart.screen_matches(home, 'Echipe acum', ('Acasă',), ('Craiova XIX',)))
        self.assertFalse(restart.screen_matches(fixture(('Echipe acum', 'false')), 'Echipe acum', ('Acasă',), ('Craiova XIX',)))
        wrong_tab = fixture(('Acasă', 'true'), ('Grafic', 'false'), ('Grafic de lucru', 'false'))
        self.assertFalse(restart.screen_matches(wrong_tab, 'Grafic de lucru', ('Grafic',)))

    def test_centralizer_aliases_and_absent_selection_semantics(self):
        for label in ('Central.', 'Centralizator'):
            root = fixture((label, 'true'), ('Centralizator', 'false'),
                           ('Comun tuturor echipelor · MAGIC / Million', 'false'))
            self.assertTrue(restart.screen_matches(root, 'Centralizator', ('Central.', 'Centralizator'),
                                                  ('Comun tuturor echipelor · MAGIC / Million',)))
        self.assertTrue(restart.screen_matches(fixture(('Grafic de lucru', 'false')), 'Grafic de lucru', ('Grafic',)))

    def test_foreground_and_crash_checks_are_package_specific(self):
        self.assertTrue(restart.foreground_is_package('mCurrentFocus=Window{abc u0 com.example.andi_carpeta/.MainActivity}'))
        self.assertFalse(restart.foreground_is_package('mCurrentFocus=Window{abc u0 com.android.launcher/.Launcher}\nbackground com.example.andi_carpeta/.MainActivity'))
        self.assertTrue(restart.own_crash('E AndroidRuntime: FATAL EXCEPTION: main\nE AndroidRuntime: Process: com.example.andi_carpeta, PID: 45'))
        self.assertFalse(restart.own_crash('E AndroidRuntime: FATAL EXCEPTION: main\nE AndroidRuntime: Process: another.package, PID: 45'))

    def test_initial_navigation_lookup_retries_invalid_accessibility_dump(self):
        root = fixture(('Centralizator\nTab 4 of 8', 'false'))
        with patch.object(restart, 'state', side_effect=[ET.ParseError('null root'), (root, b'')]), \
                patch.object(restart.time, 'sleep'), patch.object(restart, 'adb', return_value=b'') as adb:
            restart.tap_label(('Central.', 'Centralizator'))
        adb.assert_called_once_with('shell', 'input', 'tap', '50', '25')


if __name__ == '__main__':
    unittest.main()
