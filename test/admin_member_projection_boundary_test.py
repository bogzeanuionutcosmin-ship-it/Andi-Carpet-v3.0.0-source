"""The extracted admin recipient projection must remain a pure Dart leaf."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("admin_boundary_audit", ROOT / "scripts/audit_dart_dependencies.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AdminMemberProjectionBoundaryTests(unittest.TestCase):
    def test_complete_dependency_closure_has_no_sdk_flutter_main_or_part_owner(self):
        report = audit.inventory()
        rows = {row["path"]: row for row in report["files"]}
        pending = ["lib/admin/admin_member_projections.dart"]
        seen = set()
        while pending:
            path = pending.pop()
            if path in seen:
                continue
            seen.add(path)
            self.assertNotEqual(path, "lib/main.dart")
            self.assertEqual(rows[path]["owner"], path)
            for directive in rows[path]["directives"]:
                for uri in directive["uris"]:
                    self.assertFalse(uri.startswith("package:"), (path, uri))
                    self.assertNotEqual(uri, "dart:ui")
            pending.extend(report["library_edges"][path])
        self.assertIn("lib/models/app_data_models.dart", seen)


if __name__ == "__main__":
    unittest.main()
