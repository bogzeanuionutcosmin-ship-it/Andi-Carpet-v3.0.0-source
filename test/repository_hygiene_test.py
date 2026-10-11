"""Static guardrails for repository hygiene and previously broken features.

Runs with Python stdlib only; deliberately does not delete unreferenced assets.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepositoryHygieneTests(unittest.TestCase):
    def test_all_json_files_are_valid(self):
        for path in ROOT.rglob("*.json"):
            if any(part in {"build", ".dart_tool", "node_modules", ".git"} for part in path.parts):
                continue
            with self.subTest(path=str(path.relative_to(ROOT))):
                json.loads(path.read_text(encoding="utf-8"))

    def test_main_has_no_accidentally_appended_duplicate(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertEqual(source.count("class _Empty extends StatelessWidget"), 1)
        self.assertEqual(source.count("const Map<String,String> _andiStickerAssets"), 1)
        self.assertEqual(source.count("class PrivateChatPage extends StatefulWidget"), 1)
        self.assertNotIn("\n).hasMatch(normalized)) return null;", source)

    def test_sticker_asset_manifest_is_complete(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        self.assertIn("- assets/stickers/", pubspec)
        paths = re.findall(r"'brc_\d+':'(assets/stickers/sticker_\d+\.png)'", source)
        self.assertEqual(len(paths), 32)
        self.assertEqual(len(set(paths)), 32)
        for relative in paths:
            with self.subTest(asset=relative):
                asset = ROOT / relative
                self.assertTrue(asset.is_file())
                self.assertEqual(asset.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")

    def test_sticker_picker_and_both_chat_surfaces_render_images(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("final keys = <String>[..._andiStickerAssets.keys, ..._andiCustomEmojis.keys];", source)
        self.assertIn("Image.asset(asset, width: size, height: size, fit: BoxFit.contain)", source)
        self.assertGreaterEqual(source.count("_andiReactionWidget("), 4)
        self.assertGreaterEqual(source.count("if (_andiHasReaction("), 1)
        self.assertIn("if(_andiHasReaction(", source)
        self.assertIn("'customEmoji'", source)

    def test_web_right_side_category_drawer_is_wired(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("endDrawer: kIsWeb ? Drawer(", source)
        self.assertIn("Scaffold.of(menuContext).openEndDrawer()", source)
        self.assertIn("endDrawerEnableOpenDragGesture: true", source)
        self.assertIn("title: const Text('Categorii'", source)

    def test_extracted_dashboard_map_widgets_are_linked_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        component = (ROOT / "lib/ui/dashboard_map_components.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/dashboard_map_components.dart';", main)
        self.assertIn("part of '../main.dart';", component)
        for widget in ("_StatMini", "_MapStatusLegend"):
            self.assertEqual(main.count("class " + widget + " "), 0)
            self.assertEqual(component.count("class " + widget + " "), 1)

    def test_quick_accounts_auth_module_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/auth/quick_accounts.dart").read_text(encoding="utf-8")
        self.assertIn("part 'auth/quick_accounts.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class _QuickAccount ", "Future<List<_QuickAccount>> _loadQuickAccounts()",
                       "Future<void> _saveQuickAccounts(", "const FlutterSecureStorage _quickAccountStorage"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("_quickAccountStorage.read(", module)
        self.assertIn("_quickAccountStorage.write(", module)
        self.assertIn("_quickAccountStorage.delete(", module)

    def test_branding_and_font_helpers_are_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/branding_theme_helpers.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/branding_theme_helpers.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("String _normalizeFontChoice(", "String? _resolvedFontFamily(",
                       "String _activeLogoAsset(", "Widget appBrandLogo("):
            self.assertNotIn(symbol, main)
            self.assertIn(symbol, module)
        for symbol in ("_bundledBackgroundAssets", "_bundledBackgroundLabels",
                       "_bundledLogoAssets", "_bundledLogoLabels"):
            self.assertIn("const Map<String, String> " + symbol + " =", module)
            self.assertNotIn("const Map<String, String> " + symbol + " =", main)
        self.assertIn("Image.asset(_activeLogoAsset(settings)", module)

    def test_install_buttons_are_extracted_without_behavior_loss(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/install_app_buttons.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/install_app_buttons.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("Future<void> _showAndroidInstallFlow(",
                       "Future<void> _showAppleInstallFlow(",
                       "class _InstallAppButtons extends StatelessWidget"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("launchUrl(uri,mode:LaunchMode.externalApplication)", module)
        self.assertIn("Auto Blocker", module)
        self.assertIn("Adaugă pe ecranul principal", module)

    def test_firebase_bootstrap_is_extracted_and_entrypoint_stays_in_main(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/bootstrap/firebase_initialization.dart").read_text(encoding="utf-8")
        self.assertIn("part 'bootstrap/firebase_initialization.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("const String _webPushVapidKey =",
                       "Future<void> _initializeFirebaseForPlatform()",
                       "Future<void> _firebaseMessagingBackgroundHandler("):
            self.assertEqual(module.count(symbol), 1)
            self.assertNotIn(symbol, main)
        self.assertIn("@pragma('vm:entry-point')", module)
        self.assertIn("Future<void> main() async", main)
        self.assertNotIn("Future<void> main() async", module)

    def test_auth_status_and_verified_location_modules_are_linked(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        parts = {
            "ui/auth_status_components.dart": ("_FirebaseLoading", "_FirebaseError"),
            "map/verified_location_fix.dart": ("_VerifiedLocationFix",),
        }
        for relative, classes in parts.items():
            with self.subTest(module=relative):
                source = (ROOT / "lib" / relative).read_text(encoding="utf-8")
                self.assertIn("part '" + relative + "';", main)
                self.assertIn("part of '../main.dart';", source)
                for name in classes:
                    self.assertEqual(main.count("class " + name + " "), 0)
                    self.assertEqual(source.count("class " + name + " "), 1)

    def test_graph_route_calculations_extracted_and_linked(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/map/graph_route_calculations.dart").read_text(encoding="utf-8")
        self.assertIn("part 'map/graph_route_calculations.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for name in ("GraphRoutePoints", "graphRoutePoints",
                     "estimateGraphDistanceKm", "estimateGraphRoadDistanceKm"):
            self.assertNotIn("class " + name + " ", main)
            self.assertNotIn("\\n" + name + "(", main)
            self.assertIn(name, module)

    def test_pdf_report_generators_are_extracted_without_duplication(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        reports = (ROOT / "lib/reports/pdf_reports.dart").read_text(encoding="utf-8")
        self.assertIn("part 'reports/pdf_reports.dart';", main)
        self.assertIn("part of '../main.dart';", reports)
        for name in ("downloadWorkGraphPdf", "downloadCentralizerPdf",
                     "downloadDecontPdf", "downloadAuditPdf",
                     "downloadFinancialSummaryPdf"):
            self.assertNotIn("Future<void> " + name + "(", main)
            self.assertEqual(reports.count("Future<void> " + name + "("), 1)

    def test_core_models_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        models = (ROOT / "lib/models/app_data_models.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/app_data_models.dart';", main)
        self.assertIn("part of '../main.dart';", models)
        names = ("AppUser", "Team", "Car", "LocationContact", "Location",
                 "ScheduleItem", "WorkSchedule", "CentralizerRecord", "Expense",
                 "PerDiemEntry", "ReceivedMoneyEntry", "TravelSettlement",
                 "TeamFinance", "AppNotification", "AuditEntry",
                 "LearningSetting", "AppSettings")
        for name in names:
            with self.subTest(model=name):
                self.assertNotIn("class " + name + " ", main)
                self.assertEqual(models.count("class " + name + " "), 1)

    def test_enums_and_permissions_extracted_without_duplicates(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        enums = (ROOT / "lib/models/app_enums_permissions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/app_enums_permissions.dart';", main)
        self.assertIn("part of '../main.dart';", enums)
        for name in ("LocationType", "LocationStatus", "UserRole",
                     "UserFunction", "FunctionPermission", "PerDiemStatus",
                     "PerDiemPaymentMethod", "ExpenseDocumentType",
                     "WorkAttemptStatus", "LearningMode", "AppThemeChoice"):
            self.assertEqual(main.count("enum " + name + " "), 0)
            self.assertEqual(enums.count("enum " + name + " "), 1)
        for name in ("LocationTypeX", "UserRoleX", "UserFunctionX",
                     "FunctionPermissionX"):
            self.assertEqual(main.count("extension " + name + " "), 0)
            self.assertEqual(enums.count("extension " + name + " "), 1)

    def test_manual_amount_and_map_route_regressions(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("RegExp(r'^\\d{1,9}(?:\\.\\d{1,2})?$').hasMatch(normalized)", source)
        self.assertIn("Schematic fallback when Mapbox cannot provide road geometry.", source)
        self.assertNotIn("for (final c in [number, amount, supplier, desc, litersC, priceC]) { c.dispose(); }", source)


if __name__ == "__main__":
    unittest.main()
