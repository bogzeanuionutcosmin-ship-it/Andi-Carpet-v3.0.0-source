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

    def test_inbound_dependencies_deduplicate_importers(self):
        result = analyze({
            "models/item.dart": "class Item {}",
            "schedule/a.dart": "import '../models/item.dart';\nexport '../models/item.dart';",
            "reports/b.dart": "import '../models/item.dart';"
        })
        self.assertEqual(result["inbound_dependencies"], [{
            "file": "models/item.dart",
            "imported_by": ["reports/b.dart", "schedule/a.dart"]
        }])

    def test_external_packages_do_not_create_inbound_edges(self):
        result = analyze({"schedule/a.dart": "import 'package:flutter/widgets.dart';"},
                         package_name="andi_carpeta")
        self.assertEqual(result["inbound_dependencies"], [])

    def test_non_main_part_is_not_mislabeled(self):
        result = analyze({"features/owner.dart": "part 'detail.dart';",
                          "features/detail.dart": "part of 'owner.dart';"})
        self.assertEqual(result["migration_candidates"], [])
        self.assertEqual(result["invalid_part_owners"], [])

    def test_main_part_declared_without_owner_link_still_needs_review(self):
        result = analyze({"main.dart": "",
                          "reports/helper.dart": "part of '../main.dart';"})
        self.assertEqual(len(result["migration_candidates"]), 1)
        self.assertEqual(result["migration_candidates"][0]["file"], "reports/helper.dart")
        self.assertEqual(len(result["orphan_parts"]), 1)

    def test_multiple_owners_of_same_part_are_reported(self):
        result = analyze({
            "first.dart": "part 'shared.dart';",
            "second.dart": "part 'shared.dart';",
            "shared.dart": "part of 'first.dart';"
        })
        self.assertEqual(result["multiple_part_owners"], [{
            "part": "shared.dart", "owners": ["first.dart", "second.dart"]
        }])
        self.assertEqual(result["invalid_part_owners"], [{
            "owner": "second.dart", "part": "shared.dart"
        }])

    def test_single_part_owner_is_not_reported_as_conflict(self):
        result = analyze({
            "first.dart": "part 'shared.dart';",
            "shared.dart": "part of 'first.dart';"
        })
        self.assertEqual(result["multiple_part_owners"], [])

    def test_part_escaping_lib_is_unresolved_not_owned(self):
        result = analyze({"main.dart": "part '../outside.dart';"})
        self.assertEqual(result["unresolved_imports"],
                         [{"file": "main.dart", "uri": "../outside.dart"}])
        self.assertEqual(result["part_links"], [])

    def test_part_of_escaping_lib_is_unresolved_not_orphaned(self):
        result = analyze({"features/a.dart": "part of '../../outside.dart';"})
        self.assertEqual(result["unresolved_imports"],
                         [{"file": "features/a.dart", "uri": "../../outside.dart"}])
        self.assertEqual(result["orphan_parts"], [])

    def test_two_file_import_cycle(self):
        result = analyze({
            "models/a.dart": "import 'b.dart';",
            "models/b.dart": "import 'a.dart';"
        })
        self.assertEqual(result["local_import_cycles"],
                         [["models/a.dart", "models/b.dart"]])

    def test_transitive_import_cycle(self):
        result = analyze({
            "a.dart": "import 'b.dart';",
            "b.dart": "export 'c.dart';",
            "c.dart": "import 'a.dart';"
        })
        self.assertEqual(result["local_import_cycles"],
                         [["a.dart", "b.dart", "c.dart"]])

    def test_acyclic_imports_do_not_report_cycle(self):
        result = analyze({
            "a.dart": "import 'b.dart';",
            "b.dart": "import 'c.dart';",
            "c.dart": ""
        })
        self.assertEqual(result["local_import_cycles"], [])

    def test_self_import_is_reported(self):
        result = analyze({"a.dart": "import 'a.dart';"})
        self.assertEqual(result["local_import_cycles"], [["a.dart"]])

    def test_legacy_named_part_of_matches_library_owner(self):
        result = analyze({
            "owner.dart": "library legacy.core;\npart 'detail.dart';",
            "detail.dart": "part of legacy.core;"
        })
        self.assertEqual(result["named_part_of"],
                         [{"part": "detail.dart", "library": "legacy.core"}])
        self.assertEqual(result["invalid_part_owners"], [])

    def test_legacy_named_part_of_mismatched_library_is_flagged(self):
        result = analyze({
            "owner.dart": "library other.core;\npart 'detail.dart';",
            "detail.dart": "part of legacy.core;"
        })
        self.assertEqual(result["invalid_part_owners"],
                         [{"owner": "owner.dart", "part": "detail.dart"}])

    def test_uri_part_of_not_misidentified_as_named(self):
        result = analyze({
            "owner.dart": "part 'detail.dart';",
            "detail.dart": "part of 'owner.dart';"
        })
        self.assertEqual(result["named_part_of"], [])

    def test_named_part_without_matching_owner_is_ambiguous(self):
        result = analyze({"detail.dart": "part of legacy.core;"})
        self.assertEqual(result["ambiguous_named_part_owners"], [{
            "part": "detail.dart", "library": "legacy.core",
            "matching_owners": []
        }])

    def test_named_part_with_two_matching_owners_is_ambiguous(self):
        result = analyze({
            "one.dart": "library legacy.core;\npart 'detail.dart';",
            "two.dart": "library legacy.core;\npart 'detail.dart';",
            "detail.dart": "part of legacy.core;"
        })
        self.assertEqual(result["ambiguous_named_part_owners"], [{
            "part": "detail.dart", "library": "legacy.core",
            "matching_owners": ["one.dart", "two.dart"]
        }])

    def test_named_part_with_one_matching_owner_is_unambiguous(self):
        result = analyze({
            "one.dart": "library legacy.core;\npart 'detail.dart';",
            "detail.dart": "part of legacy.core;"
        })
        self.assertEqual(result["ambiguous_named_part_owners"], [])

    def test_hotspots_rank_by_total_then_inbound_then_path(self):
        result = analyze({
            "a.dart": "import 'shared.dart';",
            "b.dart": "import 'shared.dart';",
            "shared.dart": "import 'leaf.dart';",
            "leaf.dart": ""
        })
        self.assertEqual(result["dependency_hotspots"], [
            {"file": "shared.dart", "inbound_count": 2, "outbound_count": 1},
            {"file": "leaf.dart", "inbound_count": 1, "outbound_count": 0},
            {"file": "a.dart", "inbound_count": 0, "outbound_count": 1},
            {"file": "b.dart", "inbound_count": 0, "outbound_count": 1}
        ])

    def test_hotspots_ignore_unresolved_and_external_imports(self):
        result = analyze({
            "a.dart": "import 'missing.dart';\\nimport 'package:flutter/widgets.dart';"
        }, package_name="andi_carpet")
        self.assertEqual(result["dependency_hotspots"], [])

    def test_invalid_sources(self):
        with self.assertRaises(ValueError):
            analyze({"a.dart": None})


if __name__ == "__main__":
    unittest.main()
