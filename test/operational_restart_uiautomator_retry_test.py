"""Focused contract tests for the operational restart UI hierarchy retry."""
import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts' / 'test_xix_operational_restart.py'
SPEC = importlib.util.spec_from_file_location('test_xix_operational_restart', SCRIPT)
RESTART = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RESTART)


class UiHierarchyRetryTests(unittest.TestCase):
    def test_retries_empty_xml_then_returns_valid_hierarchy(self):
        replies = iter([
            (b'ERROR: null root node returned by UiTestAutomationBridge.', b''),
            (b'UI hierchary dumped to: /sdcard/xix-window.xml', b'<hierarchy><node /></hierarchy>'),
        ])
        sleeps = []
        diagnostics = []

        root, raw = RESTART.parse_ui_hierarchy_with_retry(
            lambda: next(replies),
            max_attempts=3,
            retry_delay=0.25,
            sleep=sleeps.append,
            diagnostic=diagnostics.append,
        )

        self.assertEqual(root.tag, 'hierarchy')
        self.assertEqual(raw, b'<hierarchy><node /></hierarchy>')
        self.assertEqual(len(sleeps), 1)
        self.assertEqual(sleeps, [0.25])
        self.assertIn('empty hierarchy XML (attempt 1/3)', diagnostics[0])

    def test_retries_malformed_xml_and_hard_fails_at_limit(self):
        replies = iter([
            (b'dump failed', b'<hierarchy'),
            (b'dump failed again', b'not XML'),
            (b'null root', b''),
            (b'unused', b'<hierarchy />'),
        ])
        sleeps = []
        diagnostics = []

        with self.assertRaisesRegex(
                RESTART.UIHierarchyReadError, 'unavailable after 3 attempts'):
            RESTART.parse_ui_hierarchy_with_retry(
                lambda: next(replies),
                max_attempts=3,
                retry_delay=0.1,
                sleep=sleeps.append,
                diagnostic=diagnostics.append,
            )

        self.assertEqual(len(sleeps), 2)
        self.assertEqual(len(diagnostics), 3)
        self.assertTrue(any('malformed hierarchy XML' in line for line in diagnostics))
        self.assertTrue(any('empty hierarchy XML' in line for line in diagnostics))


if __name__ == '__main__':
    unittest.main()
