"""The file contract must remain usable by the plain Dart VM smoke runner."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('backup_port_audit', ROOT / 'scripts/audit_dart_dependencies.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AdminBackupPortBoundaryTests(unittest.TestCase):
    def test_file_contract_complete_closure_excludes_flutter_sdk_and_main(self):
        report = audit.inventory()
        rows = {row['path']: row for row in report['files']}
        root = 'lib/admin/admin_backup_files.dart'
        pending, seen = [root], set()
        while pending:
            path = pending.pop()
            if path in seen:
                continue
            seen.add(path)
            self.assertEqual(rows[path]['owner'], path)
            self.assertNotEqual(path, 'lib/main.dart')
            for directive in rows[path]['directives']:
                for uri in directive['uris']:
                    self.assertFalse(uri.startswith('package:'), (path, uri))
                    self.assertNotEqual(uri, 'dart:ui')
            pending.extend(report['library_edges'][path])
        self.assertEqual(seen, {root})
        self.assertIn(root, report['library_edges']['lib/admin/file_picker_admin_backup_files.dart'])
        self.assertIn(root, report['library_edges']['scripts/verify_pure_models.dart'])


if __name__ == '__main__':
    unittest.main()
