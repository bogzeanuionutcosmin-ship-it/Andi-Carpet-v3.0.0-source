import unittest
from modularization_inventory import analyze
import re


class ModularizationInventoryTests(unittest.TestCase):
    def test_pubspec_package_name_regex(self):
        pattern = r"^name:\s*([\w-]+)\s*$"
        match = re.search(pattern, "name: andi_carpeta\ndescription: Synthetic", re.MULTILINE)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), "andi_carpeta")

    def test_cross_domain_relative_import(self):
        result = analyze({"schedule/editor.dart": "import '../centralizer/model.dart';",
                          "centralizer/model.dart": ""})
        self.assertEqual(result["cross_domain_edges"], [{"from": "schedule", "to": "centralizer"}])
        self.assertEqual(result["unresolved_imports"], [])

    def test_package_local_import(self):
        result = analyze({"reports/report.dart": "import 'package:andi_carpet/models/a.dart';",
                          "models/a.dart": ""})
        self.assertEqual(result["cross_domain_edges"], [{"from": "reports", "to": "models"}])

    def test_external_package_not_marked_unresolved(self):
        result = analyze({"schedule/a.dart": "import 'package:flutter/widgets.dart';"},
                         package_name="andi_carpet")
        self.assertEqual(result["unresolved_imports"], [])

    def test_local_package_missing_import_detected(self):
        result = analyze({"schedule/a.dart": "import 'package:andi_carpet/models/missing.dart';"},
                         package_name="andi_carpet")
        self.assertEqual(len(result["unresolved_imports"]), 1)

    def test_external_import_ignored(self):
        result = analyze({"schedule/a.dart": "import 'dart:async';\nimport 'package:flutter/widgets.dart';"})
        self.assertEqual(result["cross_domain_edges"], [])

    def test_unresolved_import_reported(self):
        result = analyze({"schedule/a.dart": "import '../centralizer/missing.dart';"})
        self.assertEqual(len(result["unresolved_imports"]), 1)

    def test_never_certifies_modularization(self):
        self.assertFalse(analyze({})["modularization_complete"])

    def test_import_escaping_lib_is_unresolved(self):
        result = analyze({"schedule/a.dart": "import '../../outside.dart';"})
        self.assertEqual(result["unresolved_imports"], [{"file": "schedule/a.dart", "uri": "../../outside.dart"}])

    def test_part_of_main_is_matched_regardless_of_order(self):
        sources = {"reports/helper.dart": "part of '../main.dart';",
                   "main.dart": "part 'reports/helper.dart';"}
        result = analyze(sources)
        self.assertEqual(result["part_links"], [{"owner": "main.dart", "part": "reports/helper.dart"}])
        self.assertEqual(result["orphan_parts"], [])

    def test_orphan_part_of_is_detected(self):
        result = analyze({"reports/helper.dart": "part of '../main.dart';",
                          "main.dart": ""})
        self.assertEqual(result["orphan_parts"], [{"part": "reports/helper.dart", "owner": "main.dart"}])

    def test_missing_part_file_is_unresolved(self):
        result = analyze({"main.dart": "part 'reports/missing.dart';"})
        self.assertEqual(result["unresolved_imports"], [{"file": "main.dart", "uri": "reports/missing.dart"}])

    def test_part_without_part_of_is_flagged(self):
        result = analyze({"main.dart": "part 'reports/helper.dart';",
                          "reports/helper.dart": "class Helper {}"})
        self.assertEqual(result["invalid_part_owners"],
                         [{"owner": "main.dart", "part": "reports/helper.dart"}])

    def test_part_with_wrong_owner_is_flagged(self):
        result = analyze({"main.dart": "part 'reports/helper.dart';",
                          "reports/helper.dart": "part of '../other.dart';",
                          "other.dart": ""})
        self.assertEqual(result["invalid_part_owners"],
                         [{"owner": "main.dart", "part": "reports/helper.dart"}])
        self.assertEqual(result["orphan_parts"],
                         [{"part": "reports/helper.dart", "owner": "other.dart"}])

    def test_valid_part_owner_is_not_flagged(self):
        result = analyze({"main.dart": "part 'reports/helper.dart';",
                          "reports/helper.dart": "part of '../main.dart';"})
        self.assertEqual(result["invalid_part_owners"], [])

    def test_main_part_requires_manual_dependency_review(self):
        result = analyze({"main.dart": "part 'reports/helper.dart';",
                          "reports/helper.dart": "part of '../main.dart';"})
        self.assertEqual(result["migration_candidates"], [{
            "file": "reports/helper.dart",
            "classification": "main_part_requires_dependency_review",
            "safe_to_extract_automatically": False
        }])

    def test_standalone_library_not_marked_as_part_candidate(self):
        result = analyze({"main.dart": "", "models/standalone.dart": "class Standalone {}"})
        self.assertEqual(result["migration_candidates"], [])

    def test_invalid_sources(self):
        with self.assertRaises(ValueError):
            analyze({"a.dart": None})


if __name__ == "__main__":
    unittest.main()
