"""Guard library boundaries; part-of ownership is not an import cycle."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("dart_dependency_audit", ROOT / "scripts/audit_dart_dependencies.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class DartLibraryDependenciesTests(unittest.TestCase):
    def test_all_directives_resolve_and_parts_have_owners(self):
        report = audit.inventory()
        self.assertEqual(report["missing_targets"], [])
        self.assertEqual(report["orphan_parts"], [])
        self.assertEqual(report["duplicate_declarations_in_library"], [])

    def test_local_library_import_export_graph_has_no_cycles(self):
        self.assertEqual(audit.inventory()["import_export_cycles"], [])

    def test_independent_model_foundation_never_imports_main(self):
        report = audit.inventory()
        paths = {"lib/models/" + name for name in (
            "app_enums_permissions.dart", "location_status_and_functions.dart",
            "default_categories_functions.dart", "location_category_helpers.dart",
            "permission_status_labels.dart")}
        rows = {row["path"]: row for row in report["files"]}
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(rows[path]["owner"], path)
                self.assertNotIn("lib/main.dart", report["library_edges"][path])
                self.assertTrue(set(report["library_edges"][path]) <= paths)

    def test_core_models_dates_and_learning_have_explicit_one_way_dependencies(self):
        report = audit.inventory()
        edges = report["library_edges"]
        expected = {
            "lib/utils/graph_names.dart": [],
            "lib/models/app_data_models.dart": ["lib/models/app_enums_permissions.dart", "lib/models/location_category_helpers.dart", "lib/utils/graph_names.dart"],
            "lib/utils/operational_dates.dart": ["lib/models/app_data_models.dart"],
            "lib/learning/duration_estimates.dart": ["lib/models/app_data_models.dart", "lib/models/app_enums_permissions.dart", "lib/utils/operational_dates.dart"],
        }
        rows = {row["path"]: row for row in report["files"]}
        for path, dependencies in expected.items():
            with self.subTest(path=path):
                self.assertEqual(rows[path]["owner"], path)
                self.assertEqual(edges[path], dependencies)

    def test_conditional_platform_implementations_are_all_inventoried(self):
        rows = {row["path"]: row for row in audit.inventory()["files"]}
        for source, targets in (
            ("lib/ocr_service.dart", {"lib/ocr_service_mobile.dart", "lib/ocr_service_web.dart", "lib/ocr_service_stub.dart"}),
            ("lib/download_file.dart", {"lib/download_file_web.dart", "lib/download_file_stub.dart"}),
        ):
            with self.subTest(source=source):
                exported = {t for d in rows[source]["directives"] if d["kind"] == "export" for t in d["local_targets"]}
                self.assertEqual(exported, targets)


if __name__ == "__main__":
    unittest.main()
