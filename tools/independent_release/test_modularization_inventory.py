import unittest
from modularization_inventory import analyze


class ModularizationInventoryTests(unittest.TestCase):
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

    def test_invalid_sources(self):
        with self.assertRaises(ValueError):
            analyze({"a.dart": None})


if __name__ == "__main__":
    unittest.main()
