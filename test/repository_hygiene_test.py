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

    def test_all_declared_dart_parts_exist_and_belong_to_main(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        paths = re.findall(r"^part '([^']+)';$", main, flags=re.MULTILINE)
        self.assertGreaterEqual(len(paths), 50)
        self.assertEqual(len(paths), len(set(paths)), "Duplicate Dart part directives")
        for relative in paths:
            with self.subTest(part=relative):
                self.assertNotIn("..", Path(relative).parts)
                module = ROOT / "lib" / relative
                self.assertTrue(module.is_file(), "Missing Dart part: " + relative)
                content = module.read_text(encoding="utf-8")
                self.assertIn("part of '../main.dart';", content)

    def test_main_has_no_accidentally_appended_duplicate(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        modules = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "lib").rglob("*.dart"))
        self.assertEqual(modules.count("class _Empty extends StatelessWidget"), 1)
        self.assertEqual(modules.count("const Map<String,String> _andiStickerAssets"), 1)
        self.assertEqual(modules.count("class PrivateChatPage extends StatefulWidget"), 1)
        self.assertNotIn("\n).hasMatch(normalized)) return null;", source)

    def test_sticker_asset_manifest_is_complete(self):
        source = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "lib").rglob("*.dart"))
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
        source = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "lib").rglob("*.dart"))
        self.assertIn("final keys = <String>[..._andiStickerAssets.keys, ..._andiCustomEmojis.keys];", source)
        self.assertIn("Image.asset(asset, width: size, height: size, fit: BoxFit.contain)", source)
        self.assertGreaterEqual(source.count("_andiReactionWidget("), 4)
        self.assertGreaterEqual(source.count("if (_andiHasReaction("), 1)
        self.assertIn("if(_andiHasReaction(", source)
        self.assertIn("'customEmoji'", source)

    def test_web_right_side_category_drawer_is_wired(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_page.dart';", main)
        source = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
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


    def test_firebase_bootstrap_error_screen_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/bootstrap/firebase_bootstrap_error_app.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'bootstrap/firebase_bootstrap_error_app.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _FirebaseBootstrapErrorApp extends StatelessWidget", main)
        self.assertEqual(module.count("class _FirebaseBootstrapErrorApp extends StatelessWidget"), 1)
        self.assertIn("runApp(_FirebaseBootstrapErrorApp(message: e.toString()));", main)
        self.assertIn("Firebase nu este configurat pentru această platformă", module)
        self.assertIn("SelectableText(message", module)

    def test_location_adjust_screen_is_extracted_without_behavior_change(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/map/location_adjust_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'map/location_adjust_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class LocationAdjustPage extends StatefulWidget",
                       "class _LocationAdjustPageState extends State<LocationAdjustPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("onPositionChanged: (position, _)", module)
        self.assertIn("Navigator.pop(context, _center)", module)
        self.assertIn("initialZoom: 17", module)
        self.assertIn("TileLayer(", module)

    def test_documents_library_extracted_without_behavior_change(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/documents/documents_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'documents/documents_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class ManualAppDocument {", "class DocumentsPage extends StatefulWidget",
                       "class _DocumentsPageState extends State<DocumentsPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("assets/pv_magic.pdf", "PV_MAGIC.pdf",
                         "collection('documents').doc(result.id).set(",
                         "collection('documents').orderBy('date',descending:true).snapshots()",
                         "if(widget.isAdmin)FilledButton.icon(",
                         "trailing:widget.isAdmin?IconButton(",
                         "await doc.reference.delete();"):
            self.assertIn(contract, module)

    def test_location_phone_contacts_screen_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/contacts/location_contacts_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'contacts/location_contacts_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class MessagesContactsPage extends StatefulWidget",
                       "class _MessagesContactsPageState extends State<MessagesContactsPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("Uri(scheme:'tel',path:clean)", module)
        self.assertIn("Future<LocationContact?> _contactDialog(", module)
        self.assertIn("canEditContacts", module)
        self.assertIn("canManageTemplates", module)
        self.assertIn("smsEnabled", module)

    def test_about_app_page_extracted_once_with_history(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/app_information_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'ui/app_information_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class AppInformationPage extends StatelessWidget", main)
        self.assertEqual(module.count("class AppInformationPage extends StatelessWidget"), 1)
        self.assertIn("_builtInHistory", module)
        self.assertIn("Capacități", module)
        self.assertIn("Istoric update", module)
        self.assertIn("_appVersionLabel", module)

    def test_sms_gateway_management_ui_extracted_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/notifications/sms_gateway_card.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'notifications/sms_gateway_card.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class SmsManagerGatewayCard extends StatefulWidget",
                       "class _SmsManagerGatewayCardState extends State<SmsManagerGatewayCard>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("_smsGatewayChannel.invokeMapMethod<String,dynamic>('gatewayStatus')", module)
        self.assertIn("FirebaseAuth.instance.currentUser", module)
        self.assertIn("getIdToken(true)", module)
        self.assertIn("TargetPlatform.android", module)

    def test_push_diagnostics_page_extracted_with_fcm_checks(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/notifications/push_diagnostics_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'notifications/push_diagnostics_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class PushDiagnosticsPage extends StatefulWidget",
                       "class _PushDiagnosticsPageState extends State<PushDiagnosticsPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("FirebaseMessaging.instance.getNotificationSettings()",
                         "_webPushVapidKey", "AuthorizationStatus.denied",
                         "getToken(", "_tokenDocId("):
            self.assertIn(contract, module)

    def test_private_chat_extracted_preserving_message_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/chat/private_chat_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'chat/private_chat_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class PrivateChatPage extends StatefulWidget",
                       "class _PrivateChatPageState extends State<PrivateChatPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("collection('chatMessages')",
                         "where('senderId', isEqualTo: widget.currentUser.id)",
                         "where('recipientId', isEqualTo: widget.currentUser.id)",
                         "_sentSubscription", "_receivedSubscription",
                         "cancel()", "_visibleDocs", "_clearChatForMe",
                         "_openEmojiPicker", "'customEmoji'"):
            self.assertIn(contract, module)

    def test_group_chat_extracted_preserving_history_and_retention(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/chat/group_chat_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'chat/group_chat_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class GroupChatPage extends StatefulWidget",
                       "class _GroupChatPageState extends State<GroupChatPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("_historyLimit = 50", "_retentionDays = 7",
                         "collection('groupChatMessages')", "orderBy('createdAt', descending: true)",
                         ".limit(_historyLimit)", "_send(", "_andiReactionWidget",
                         "dispose()"):
            self.assertIn(contract, module)

    def test_member_profile_extracted_preserving_contact_actions(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/members/member_profile_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'members/member_profile_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class MemberProfilePage extends StatelessWidget", main)
        self.assertEqual(module.count("class MemberProfilePage extends StatelessWidget"), 1)
        for contract in ("StreamBuilder", "FirebaseFirestore.instance",
                         "launchUrl(", "_call(", "memberId", "functionDefinitions"):
            self.assertIn(contract, module)

    def test_members_directory_extracted_preserving_chat_navigation(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/members/members_directory_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'members/members_directory_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class MembersDirectoryPage extends StatefulWidget",
                       "class _MembersDirectoryPageState extends State<MembersDirectoryPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("chatMode", "PrivateChatPage", "GroupChatPage",
                         "MemberProfilePage", "_selected", "collection('users')",
                         "StreamBuilder", "mark_chat_unread"):
            self.assertIn(contract, module)

    def test_feedback_page_extracted_preserving_form_contract(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/feedback/feedback_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'feedback/feedback_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class FeedbackPage extends StatefulWidget",
                       "class _FeedbackPageState extends State<FeedbackPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for contract in ("TabController", "initialTab", "details.dispose()",
                         "expected.dispose()", "FirebaseFirestore.instance"):
            self.assertIn(contract, module)

    def test_full_schedule_card_extracted_preserving_reorder_controls(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/schedule/schedule_card_full.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'schedule/schedule_card_full.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _ScheduleCardFull extends StatelessWidget", main)
        self.assertEqual(module.count("class _ScheduleCardFull extends StatelessWidget"), 1)
        for contract in ("ReorderableListView.builder", "onReorder", "onRemove",
                         "onAdd", "autoProposed", "learningConfidence",
                         "categoryBrandWidget", "schedule.closed"):
            self.assertIn(contract, module)

    def test_team_selector_extracted_preserving_selection_callback(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/teams/team_selector.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'teams/team_selector.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _TeamSelector extends StatelessWidget", main)
        self.assertEqual(module.count("class _TeamSelector extends StatelessWidget"), 1)
        for contract in ("List<Team> teams", "ValueChanged<int> onChanged",
                         "required this.selected", "onChanged(v)"):
            self.assertIn(contract, module)

    def test_responsive_page_shell_extracted_preserving_branding(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/page_shell.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'ui/page_shell.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _Page extends StatelessWidget", main)
        self.assertEqual(module.count("class _Page extends StatelessWidget"), 1)
        for contract in ("LayoutBuilder", "box.maxWidth < 600",
                         "sectionAccent(title)", "appBrandLogo(",
                         "assets/logos/standard.jpg", "SingleChildScrollView",
                         "this.actions = const []"):
            self.assertIn(contract, module)

    def test_summary_cards_extracted_preserving_values_and_actions(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/summary_cards.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'ui/summary_cards.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("_StatCard", "_MoneyCard", "_InfoCard"):
            declaration = "class " + name + " extends StatelessWidget"
            self.assertNotIn(declaration, main)
            self.assertEqual(module.count(declaration), 1)
        for contract in ("assert(icon != null || asset != null)",
                         "appAssetIcon(", "sectionAccent(title)",
                         "onTap:onTap", "value.toStringAsFixed(2)",
                         "ListTile("):
            self.assertIn(contract, module)

    def test_empty_state_extracted_preserving_content(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/empty_state.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'ui/empty_state.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _Empty extends StatelessWidget", main)
        self.assertEqual(module.count("class _Empty extends StatelessWidget"), 1)
        for contract in ("required this.icon", "required this.text",
                         "Icon(icon,size:30)", "Text(text)", "EdgeInsets.all(28)"):
            self.assertIn(contract, module)

    def test_settings_page_extracted_preserving_account_actions(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/settings/settings_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'settings/settings_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("SettingsPage", "_SettingsPageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.onLogout", "Icons.logout", "Ieșire din cont"):
            self.assertIn(contract, module)

    def test_profile_page_extracted_preserving_records_and_per_diem(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/profile/profile_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'profile/profile_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("ProfilePage", "_ProfilePageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.user", "widget.records", "widget.perDiems",
                         "widget.functionDefinitions"):
            self.assertIn(contract, module)

    def test_centralizer_page_extracted_preserving_records_and_export(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/centralizer/centralizer_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'centralizer/centralizer_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("CentralizerPage", "_CentralizerPageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.records", "widget.saveRecord",
                         "widget.canEditCentralizer", "widget.locations", "exporting"):
            self.assertIn(contract, module)

    def test_dashboard_page_extracted_preserving_operational_workflows(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/dashboard/dashboard_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'dashboard/dashboard_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("DashboardPage", "_DashboardPageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.teams", "widget.records", "widget.schedules",
                         "showSuccessMessage", "showErrorMessage"):
            self.assertIn(contract, module)

    def test_program_page_extracted_preserving_schedule_and_map_data(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/schedule/program_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'schedule/program_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("ProgramPage", "_ProgramPageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.schedules", "widget.locations", "widget.saveSchedule",
                         "widget.canEditTeam", "_roadRouteFuture"):
            self.assertIn(contract, module)
        self.assertIn("const List<_VerifiedLocationFix> _verifiedLocationFixes", main)
        self.assertNotIn("const List<_VerifiedLocationFix> _verifiedLocationFixes", module)

    def test_map_page_extracted_preserving_locations_and_navigation(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/map/map_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'map/map_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("MapPage", "_MapPageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("widget.locations", "widget.saveLocation",
                         "widget.hiddenUserIds", "widget.schedules",
                         "FlutterMap", "MarkerLayer", "PolylineLayer"):
            self.assertIn(contract, module)

    def test_expense_page_extracted_preserving_per_diem_workflows(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/expenses/expense_page.dart").read_text(encoding="utf-8")
        self.assertEqual(main.count("part 'expenses/expense_page.dart';"), 1)
        self.assertIn("part of '../main.dart';", module)
        for name in ("ExpensePage", "_ExpensePageState"):
            self.assertNotIn("class " + name + " extends ", main)
            self.assertEqual(module.count("class " + name + " extends "), 1)
        for contract in ("visibleTeamMemberIds", "widget.perDiems",
                         "widget.settlements", "widget.expenses",
                         "widget.canEditOwnDecont", "exporting"):
            self.assertIn(contract, module)

    def test_operational_date_helpers_extracted_without_duplicates(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/utils/operational_dates.dart").read_text(encoding="utf-8")
        self.assertIn("part 'utils/operational_dates.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("String two(int n)", "String formatDate(DateTime d)",
                       "String formatMonth(DateTime d)", "String timeText(DateTime? d)",
                       "String durationText(Duration? d)", "bool sameDay(DateTime a, DateTime b)",
                       "DateTime operationalWorkDate(DateTime now)",
                       "DateTime workWindowStart(DateTime workDate)",
                       "DateTime workWindowEnd(DateTime workDate)",
                       "bool isInsideWorkWindow(", "bool recordBelongsToWorkDate(",
                       "DateTime recordEventTime("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("Duration(hours: 23, minutes: 30)", module)
        self.assertIn("DateTime(workDate.year, workDate.month, workDate.day, 9, 30)", module)

    def test_permission_groups_and_payment_labels_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/models/permission_status_labels.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/permission_status_labels.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("String functionPermissionGroup(FunctionPermission permission)",
                       "extension PerDiemStatusX on PerDiemStatus",
                       "extension PaymentMethodX on PerDiemPaymentMethod"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("return 'Decont / Financiar';", module)
        self.assertIn("PerDiemStatus.awaitingConfirmation => 'În așteptare confirmare'", module)

    def test_learning_duration_estimates_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/learning/duration_estimates.dart").read_text(encoding="utf-8")
        self.assertIn("part 'learning/duration_estimates.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class LearnedDurationEstimate {",
                       "LearnedDurationEstimate? learnedDurationEstimate(",
                       "Duration? learnedAverageDuration("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("r.keptForLearning", module)
        self.assertIn("history.length < 3", module)
        self.assertIn("Duration(hours: 24)", module)
        self.assertIn("LearningMode.automatic", module)

    def test_section_visual_helpers_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/section_visual_helpers.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/section_visual_helpers.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("Color sectionAccent(String label)",
                       "void showSuccessMessage(BuildContext context, String message)",
                       "void showErrorMessage(BuildContext context, String message)",
                       "Color _plainBackgroundColor(AppSettings settings, Brightness brightness)"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("Colors.white", module)

    def test_app_backdrop_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/app_backdrop.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/app_backdrop.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class _AppBackdrop extends StatelessWidget", main)
        self.assertEqual(module.count("class _AppBackdrop extends StatelessWidget"), 1)
        self.assertIn("_plainBackgroundColor(settings, brightness)", module)
        self.assertIn("settings.customBackgrounds[customId]", module)
        self.assertIn("settings.backgroundOpacity.clamp(0.0, 0.70)", module)

    def test_icon_badge_catalog_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/icon_badge_catalog.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/icon_badge_catalog.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("const Map<String, IconData> appIconChoices",
                       "const Map<String, String> badgeAssetChoices",
                       "const List<String> availableBadgeKeys",
                       "const Map<String, String> categoryBrandAssets",
                       "Widget _badgeGraphic(", "Widget categoryBrandWidget(",
                       "Widget sectionAssetWidget(", "String badgeLabel("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("'badge_machine': 'assets/badges/badge_worker.png'", module)

    def test_interactive_member_badges_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/interactive_member_badges.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/interactive_member_badges.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class _InteractiveBadgeIcon extends StatefulWidget",
                       "class _InteractiveBadgeIconState extends State<_InteractiveBadgeIcon>",
                       "Widget functionKeyWidget(",
                       "List<String> effectiveBadgeKeysForFunctionIds(",
                       "Widget badgeStripWidget(", "Widget memberBadgeStripWidget("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("if (widgets.length >= 3) break;", module)
        self.assertIn("badge == 'badge_machine' ? 'badge_worker' : badge", module)
        self.assertIn("if (_entry == null)", module)

    def test_location_category_helpers_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/models/location_category_helpers.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/location_category_helpers.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("String defaultCategoryIdForType(",
                       "LocationType legacyTypeForCategory(",
                       "Color categoryColor(", "String categoryName("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("if (categoryId == 'million') return Colors.red;", module)
        self.assertIn("if (categoryId == 'magic') return Colors.black87;", module)

    def test_default_categories_and_functions_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/models/default_categories_functions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/default_categories_functions.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("String functionPermissionId(",
                       "List<LocationCategory> defaultLocationCategories(",
                       "List<FunctionDefinition> defaultFunctionDefinitions(",
                       "FunctionDefinition? functionById("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("FunctionPermission.values.map((e) => e.name).toSet()", module)
        for category in ("million", "magic", "horeca", "cazari"):
            self.assertIn("id: '" + category + "'", module)

    def test_location_status_and_function_models_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/models/location_status_and_functions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'models/location_status_and_functions.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("extension LocationStatusX on LocationStatus",
                       "class LocationCategory {", "class FunctionDefinition {"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn(".take(3).toList()", module)
        self.assertIn("iconKey = this.badgeKeys.first;", module)
        self.assertIn("permissions = permissions ?? <String>{}", module)

    def test_pdf_format_helpers_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/reports/pdf_format_helpers.dart").read_text(encoding="utf-8")
        self.assertIn("part 'reports/pdf_format_helpers.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        normalizer = (ROOT / "lib/reports/pdf_filename_normalization.dart").read_text(encoding="utf-8")
        self.assertIn("import 'reports/pdf_filename_normalization.dart';", main)
        self.assertIn("export 'reports/pdf_filename_normalization.dart';", main)
        self.assertIn("String safePdfFilePart(String text)", normalizer)
        self.assertIn("String _safeFilePart(String text) => safePdfFilePart(text);", module)
        self.assertNotIn("String safePdfFilePart(String text)", module)
        for symbol in ("Future<pw.ThemeData> _buildPdfTheme(",
                       "String _safeFilePart(", "String _pdfDate("):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("PdfGoogleFonts.openSansRegular()", module)
        self.assertIn("PdfGoogleFonts.openSansBold()", module)
        self.assertIn("PdfGoogleFonts.openSansItalic()", module)

    def test_app_root_theme_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/ui/app_root_theme.dart").read_text(encoding="utf-8")
        self.assertIn("part 'ui/app_root_theme.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class AndiCarpetaApp extends StatefulWidget",
                       "class _AndiCarpetaAppState extends State<AndiCarpetaApp>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for feature in ("ThemeMode.light", "ThemeMode.dark", "ThemeMode.system",
                        "home: AuthGate(settings: settings", "NavigationBarThemeData(",
                        "SnackBarThemeData(", "InputDecorationTheme("):
            self.assertIn(feature, module)
        self.assertIn("runApp(const AndiCarpetaApp());", main)

    def test_firebase_user_profile_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/auth/firebase_user_profile.dart").read_text(encoding="utf-8")
        self.assertIn("part 'auth/firebase_user_profile.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        self.assertNotIn("class FirebaseUserProfile {", main)
        self.assertEqual(module.count("class FirebaseUserProfile {"), 1)
        self.assertIn("bool get isAdmin => role == 'admin';", module)
        self.assertIn("if (role == 'admin') return UserFunction.director;", module)
        self.assertIn("data['active'] == true", module)
        self.assertIn("data['functionIds'] is List", module)
        self.assertIn("if (useNickname && nickname.isNotEmpty) name = nickname;", module)

    def test_auth_gate_is_extracted_without_lifecycle_changes(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/auth/auth_gate.dart").read_text(encoding="utf-8")
        self.assertIn("part 'auth/auth_gate.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class AuthGate extends StatefulWidget",
                       "class _AuthGateState extends State<AuthGate>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for feature in ("authStateChanges().listen(",
                        "FirebaseAuth.instance.currentUser",
                        "collection('meta').doc('uiSettings')",
                        "MissingProfilePage(", "PendingApprovalPage(", "HomePage("):
            self.assertIn(feature, module)

    def test_login_registration_page_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/auth/login_registration_page.dart").read_text(encoding="utf-8")
        self.assertIn("part 'auth/login_registration_page.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class LoginPage extends StatefulWidget",
                       "class _LoginPageState extends State<LoginPage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for feature in ("TextEditingController()", "confirmPassword",
                        "createMode", "FirebaseAuth.instance"):
            self.assertIn(feature, module)

    def test_account_access_status_pages_are_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/auth/account_access_pages.dart").read_text(encoding="utf-8")
        self.assertIn("part 'auth/account_access_pages.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class PendingApprovalPage extends StatelessWidget",
                       "class MissingProfilePage extends StatelessWidget"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        self.assertIn("FirebaseAuth.instance.signOut()", module)
        self.assertIn("FirebaseUserProfile profile", module)

    def test_home_orchestration_is_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        module = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_page.dart';", main)
        self.assertIn("part of '../main.dart';", module)
        for symbol in ("class HomePage extends StatefulWidget",
                       "class _HomePageState extends State<HomePage>"):
            self.assertNotIn(symbol, main)
            self.assertEqual(module.count(symbol), 1)
        for feature in ("_startAdaptiveLiveLocation(",
                        "_initPushNotifications(", "_startCoreSync(",
                        "_savePerDiemDirect(", "_openAdmin(",
                        "NavigationBar("):
            self.assertIn(feature, module)

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

    def test_admin_panel_extracted_with_backup_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_panel_page.dart';", main)
        self.assertIn("part of '../main.dart';", admin)
        for declaration in ("class AdminPanelPage extends StatefulWidget", "class _AdminPanelPageState extends State<AdminPanelPage>"):
            self.assertNotIn(declaration, main)
            self.assertEqual(admin.count(declaration), 1)
        for contract in ("_exportBackup", "_restoreBackup"):
            self.assertIn(contract, (ROOT / "lib/admin/admin_backup_panel_actions.dart").read_text(encoding="utf-8"))
        for contract in ("saveLocation", "deleteLocation"):
            self.assertIn(contract, (ROOT / "lib/admin/admin_location_actions.dart").read_text(encoding="utf-8"))
        backup = (ROOT / "lib/admin/admin_backup_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_backup_actions.dart';", main)
        self.assertIn("with _AdminBackupActions", admin)
        for method in ("_exportBackup() async", "_restoreAutomaticBackup(String backupId) async", "_restoreBackup() async"):
            self.assertIn(method, backup)
            self.assertNotIn("Future<void> " + method, admin)

    def test_admin_settings_extracted_with_persistent_configuration(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        settings = (ROOT / "lib/admin/admin_settings_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_settings_actions.dart';", main)
        self.assertIn("_AdminSettingsActions", admin)
        self.assertIn("Future<void> _saveUiSettings()", settings)
        self.assertIn("Widget _settings()", settings)
        self.assertNotIn("Future<void> _saveUiSettings()", admin)
        for field in ("backupRetentionDays", "notificationHistoryDays", "androidDownloadUrl", "smsPreviousDayTime", "brandingBackgroundId", "defaultPerDiem"):
            self.assertIn(field, settings)

    def test_home_document_codecs_extracted_without_duplicate_implementations(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        codecs = (ROOT / "lib/home/home_document_codecs.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_document_codecs.dart';", main)
        self.assertIn("_HomeDocumentCodecs", home)
        self.assertIn("AppSettings get settings;", codecs)
        self.assertNotIn("FirebaseFirestore.instance", codecs)
        # Abstract mixin contracts are allowed; implementations must occur once.
        library = "\n".join((ROOT / "lib" / path).read_text(encoding="utf-8")
                            for path in re.findall(r"^part '([^']+)';$", main, re.MULTILINE))
        for model in ("location", "category", "function", "team", "car", "schedule",
                      "record", "notification", "expense", "perDiem", "settlement", "finance"):
            for suffix in ("Map", "FromDoc"):
                name = "_" + model + suffix
                pattern = r"^  [^\n]+ " + re.escape(name) + r"\([^\n]*\) (?:=>|\{)"
                with self.subTest(method=name):
                    self.assertEqual(len(re.findall(pattern, codecs, re.MULTILINE)), 1)
                    self.assertEqual(len(re.findall(pattern, library, re.MULTILINE)), 1)
                    self.assertEqual(len(re.findall(pattern, home, re.MULTILINE)), 0)
        for field in ("actualReceivedAmount", "receivedEntries", "facadeDone", "financialManagerId"):
            self.assertIn("'" + field + "'", codecs)
        self.assertEqual(codecs.count("_doubleFrom(d['perDiemRate'], settings.defaultPerDiem)"), 2)

    def test_home_seed_catalog_is_unique_and_local(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        seed = (ROOT / "lib/home/home_location_seed.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_location_seed.dart';", main)
        self.assertIn("_HomeLocationSeed", home)
        self.assertNotIn("List<Location> _seedLocations() {", home)
        self.assertEqual(seed.count("List<Location> _seedLocations() {"), 1)
        ids = re.findall(r"Location\(id:'([^']+)'", seed)
        self.assertEqual(len(ids), 103)
        self.assertEqual(len(ids), len(set(ids)))
        self.assertNotIn("FirebaseFirestore", seed)
        self.assertIn("locations = _seedLocations();", home)

    def test_home_core_sync_preserves_subscription_order_and_lifecycle(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        core = home.split("  void _startCoreSync() {", 1)[1].split("  Future<void> _writeLearningEvent(", 1)[0]
        calls = re.findall(r"^    (_start\w+Sync)\(db\);$", core, re.MULTILINE)
        self.assertEqual(calls, ["_startDefinitionsSync", "_startDirectorySync",
                                "_startOwnProfileSync", "_startOperationsSync",
                                "_startNotificationSync", "_startChatSync", "_startSettingsSync"])
        self.assertNotIn(".snapshots()", core)
        sync = home.split("  void _startAuditSync(", 1)[1].split("  Future<void> _writeLearningEvent(", 1)[0]
        self.assertEqual(sync.count("_coreSubscriptions.add("), 15)
        self.assertIn("for (final sub in _coreSubscriptions) { sub.cancel(); }", home)
        self.assertIn("if (isAdmin) {\n      _startAuditSync(db);", core)
        self.assertIn("_startFinancialSync();", core)

    def test_home_sync_groups_preserve_visibility_limits_and_errors(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        groups = [("_startOwnProfileSync", "_startOperationsSync", ["if (!isAdmin)", "doc(currentUserId)", "Profil propriu: $e"]),
                  ("_startOperationsSync", "_startNotificationSync", ["collection('teams')", "collection('cars')", "collection('locations')", "collection('schedules')", "collection('records')", "_applyTeamMembership();", "_startFinancialSync();", "_maybeAutoCloseResolvedSchedules"]),
                  ("_startNotificationSync", "_startChatSync", ["where('userId', isEqualTo: currentUserId)", "_notificationsPrimed", "_knownNotificationIds", "_allowPersonalAlert", "Notificări: $e"]),
                  ("_startChatSync", "_startSettingsSync", ["where('recipientId', isEqualTo: currentUserId)", "orderBy('createdAt', descending: true).limit(20)", "mandatoryChatAlert", "_hiddenUserIds", "_recomputeGroupUnread();", "Chat comun: $e"]),
                  ("_startSettingsSync", "_startCoreSync", ["doc('uiSettings')", "_runAutomaticMaintenance()", "Setări UI: $e"])]
        for name, following, contracts in groups:
            group = home.split("  void " + name + "(FirebaseFirestore db) {", 1)[1].split("  void " + following, 1)[0]
            for contract in contracts:
                with self.subTest(group=name, contract=contract):
                    self.assertIn(contract, group)

    def test_home_directory_sync_isolated(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("void _startDirectorySync(FirebaseFirestore db)", home)
        self.assertIn("_startDirectorySync(db);", home)
        directory = home.split("void _startDirectorySync(FirebaseFirestore db)", 1)[1].split("void _startCoreSync()", 1)[0]
        self.assertIn("db.collection('users') : db.collection('memberDirectory')", directory)
        self.assertIn("_applyTeamMembership()", directory)
        self.assertIn("_startFinancialSync()", directory)
        self.assertIn("coreSyncError = 'Conturi: $e'", directory)

    def test_home_definitions_sync_isolated(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("void _startDefinitionsSync(FirebaseFirestore db)", home)
        self.assertIn("_startDefinitionsSync(db);", home)
        definitions = home.split("void _startDefinitionsSync(FirebaseFirestore db)", 1)[1].split("void _startCoreSync()", 1)[0]
        for collection in ("locationCategories", "backgrounds", "functions"):
            self.assertIn("db.collection('" + collection + "')", definitions)
        self.assertIn("_syncUserPermissionSnapshots()", definitions)
        self.assertIn("_startFinancialSync()", definitions)

    def test_home_audit_sync_isolated_from_core_sync(self):
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        self.assertIn("void _startAuditSync(FirebaseFirestore db)", home)
        self.assertIn("_startAuditSync(db);", home)
        audit = home.split("void _startAuditSync(FirebaseFirestore db)", 1)[1].split("void _startCoreSync()", 1)[0]
        self.assertIn("if (!isAdmin) return;", audit)
        self.assertIn("db.collection('audit').orderBy('at', descending: true).limit(500)", audit)
        self.assertIn("_coreSubscriptions.add(", audit)
        self.assertIn("coreSyncError = 'Audit: $e'", audit)

    def test_home_permission_maintenance_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        permissions = (ROOT / "lib/home/home_permission_maintenance.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_permission_maintenance.dart';", main)
        self.assertIn("_HomePermissionMaintenance", home)
        for method in ("_syncUserPermissionSnapshots()", "_seedLocationsIfNeeded()", "_seedDefinitionsIfNeeded()", "_migrateFunctionBadgeSystemIfNeeded()"):
            self.assertIn(method, permissions)
        self.assertNotIn("Future<void> _migrateFunctionBadgeSystemIfNeeded()", home)
        self.assertIn("'effectivePermissions'", permissions)
        self.assertIn("'functionSystemVersion'", permissions)
        self.assertIn("Set<String> _effectivePermissionsForIds(Iterable<String> ids)", permissions)
        self.assertNotIn("Set<String> _effectivePermissionsForIds(", home)

    def test_home_automatic_backup_maintenance_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        home = (ROOT / "lib/home/home_page.dart").read_text(encoding="utf-8")
        backup = (ROOT / "lib/home/home_backup_maintenance.dart").read_text(encoding="utf-8")
        self.assertIn("part 'home/home_backup_maintenance.dart';", main)
        self.assertIn("with _HomeBackupMaintenance", home)
        self.assertIn("_createAutomaticBackup() async", backup)
        self.assertIn("_pruneAutomaticBackups() async", backup)
        self.assertNotIn("Future<void> _createAutomaticBackup()", home)
        self.assertIn("'uiSettings'", backup)
        self.assertIn("batch.commit()", backup)
        self.assertIn("backupRetentionDays", backup)
        self.assertIn("_pruneOldNotifications() async", backup)
        self.assertIn("notificationHistoryDays", backup)
        self.assertNotIn("Future<void> _pruneOldNotifications()", home)

    def test_admin_backup_panel_extracted_with_restore_warning(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        panel = (ROOT / "lib/admin/admin_backup_panel_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_backup_panel_actions.dart';", main)
        self.assertIn("_AdminBackupPanelActions", admin)
        self.assertIn("Widget _backup()", panel)
        self.assertNotIn("Widget _backup()", admin)
        self.assertIn("_restoreAutomaticBackup(", panel)
        self.assertIn("_exportBackup", panel)
        self.assertIn("_restoreBackup", panel)
        self.assertIn("Conturile de autentificare rămân intacte", panel)

    def test_admin_function_rights_extracted_and_admin_protected(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        rights = (ROOT / "lib/admin/admin_function_rights_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_function_rights_actions.dart';", main)
        self.assertIn("_AdminFunctionRightsActions", admin)
        self.assertIn("_deleteFunction(FunctionDefinition f)", rights)
        self.assertIn("Widget _functionRights()", rights)
        self.assertNotIn("Future<void> _deleteFunction(", admin)
        self.assertIn("f.id == 'admin'", rights)
        self.assertIn("functionIds", rights)
        self.assertIn("permissions", rights)
        self.assertIn("collection('functions')", rights)

    def test_admin_dashboard_extracted_with_local_usage_warning(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        dashboard = (ROOT / "lib/admin/admin_dashboard_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_dashboard_actions.dart';", main)
        self.assertIn("_AdminDashboardActions", admin)
        self.assertIn("Widget _dashboard()", dashboard)
        self.assertIn("Widget _mapboxUsagePanel()", dashboard)
        self.assertNotIn("Widget _dashboard()", admin)
        self.assertIn("requestsByService", dashboard)
        self.assertIn("NU reprezintă consumul lunar", dashboard)

    def test_admin_communications_extracted_with_report_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        communications = (ROOT / "lib/admin/admin_communications_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_communications_actions.dart';", main)
        self.assertIn("_AdminCommunicationsActions", admin)
        for method in ("_sendSystemNotification(", "_notifications()", "_reports()", "_audit()"):
            self.assertIn(method, communications)
        self.assertNotIn("Future<void> _sendSystemNotification(", admin)
        for export in ("downloadCentralizerPdf(", "downloadFinancialSummaryPdf(", "downloadAuditPdf("):
            self.assertIn(export, communications)
        self.assertIn("collection('notifications')", communications)

    def test_admin_learning_diagnostics_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        learning = (ROOT / "lib/admin/admin_learning_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_learning_actions.dart';", main)
        self.assertIn("_AdminLearningActions", admin)
        self.assertIn("Widget _learning(bool ocr)", learning)
        self.assertNotIn("Widget _learning(bool ocr)", admin)
        self.assertIn("learnedDurationEstimate(", learning)
        self.assertIn("_saveUiSettings()", learning)
        self.assertIn("LearningMode.manualApproval", learning)

    def test_admin_operations_extracted_with_history_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        operations = (ROOT / "lib/admin/admin_operations_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_operations_actions.dart';", main)
        self.assertIn("_AdminOperationsActions", admin)
        for method in ("_setScheduleClosed(", "_deleteSchedulePermanently(", "_deleteRecord(", "_deleteExpense(", "_programs()", "_records()", "_finance()"):
            self.assertIn(method, operations)
        self.assertNotIn("Future<void> _deleteSchedulePermanently(", admin)
        self.assertIn("Istoricul execuțiilor din Centralizator rămâne păstrat", operations)
        self.assertIn("collection('schedules')", operations)
        self.assertIn("collection('records')", operations)
        self.assertIn("collection('expenses')", operations)

    def test_admin_cars_and_locations_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        cars = (ROOT / "lib/admin/admin_car_actions.dart").read_text(encoding="utf-8")
        locations = (ROOT / "lib/admin/admin_location_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_car_actions.dart';", main)
        self.assertIn("part 'admin/admin_location_actions.dart';", main)
        self.assertIn("_AdminCarActions, _AdminLocationActions", admin)
        for method in ("_editCar(", "_removeCar(", "_cars()"):
            self.assertIn(method, cars)
        for method in ("_contactDialog(", "_editLocationAdmin(", "_deleteLocationPermanent(", "_changeLocationStatus(", "_locations()", "_editCategory(", "_deleteCategory(", "_categories()"):
            self.assertIn(method, locations)
        self.assertNotIn("Future<void> _editCar(", admin)
        self.assertNotIn("Future<void> _editLocationAdmin(", admin)
        self.assertIn("widget.saveLocation(", locations)
        self.assertIn("widget.deleteLocation(", locations)
        self.assertIn("collection('cars')", cars)

    def test_admin_member_actions_extracted_with_permission_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        members = (ROOT / "lib/admin/admin_member_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_member_actions.dart';", main)
        self.assertIn("_AdminMemberActions", admin)
        for method in ("_editFunctionDefinition(", "_setUserFunctions(", "_members()"):
            self.assertIn(method, members)
        self.assertNotIn("Future<void> _editFunctionDefinition(", admin)
        self.assertNotIn("Future<void> _setUserFunctions(", admin)
        self.assertIn("functionIds", members)
        self.assertIn("collection('users')", members)
        self.assertIn("collection('functions')", members)

    def test_admin_team_actions_extracted_with_membership_contracts(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        teams = (ROOT / "lib/admin/admin_team_actions.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_team_actions.dart';", main)
        self.assertIn("with _AdminBackupActions, _AdminTeamActions", admin)
        for name in ("_editTeam(", "_setTeamActive(", "_deleteTeam(", "_cleanupDuplicateTeams(", "_teams()"):
            self.assertIn(name, teams)
        self.assertNotIn("Future<void> _editTeam(", admin)
        self.assertNotIn("Future<void> _deleteTeam(", admin)
        self.assertIn("financialManagerId", teams)
        self.assertIn("teamId", teams)
        self.assertIn("perDiems", teams)

    def test_admin_navigation_catalog_extracted(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        catalog = (ROOT / "lib/admin/admin_navigation_catalog.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/admin_navigation_catalog.dart';", main)
        for symbol in ("_adminSectionIcon(", "_adminSectionGroup(", "_adminSectionAsset("):
            self.assertIn(symbol, catalog)
            self.assertIn(symbol, admin)
        self.assertNotIn("IconData _icon(int i)", admin)
        self.assertNotIn("String _groupFor(int i)", admin)
        self.assertNotIn("String? _adminSectionAsset(int i)", admin)
        self.assertIn("assets/ui/tab_dashboard.png", catalog)
        self.assertIn("assets/ui/security.png", catalog)

    def test_backup_codec_is_extracted_without_duplicate_implementations(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        admin = (ROOT / "lib/admin/admin_panel_page.dart").read_text(encoding="utf-8")
        codec = (ROOT / "lib/admin/backup_codec.dart").read_text(encoding="utf-8")
        self.assertIn("part 'admin/backup_codec.dart';", main)
        self.assertEqual(codec.count("dynamic _backupEncode(dynamic value)"), 1)
        self.assertEqual(codec.count("dynamic _backupDecode(dynamic value)"), 1)
        self.assertNotIn("dynamic _backupEncode(dynamic value)", admin)
        self.assertNotIn("dynamic _backupDecode(dynamic value)", admin)
        backup = (ROOT / "lib/admin/admin_backup_actions.dart").read_text(encoding="utf-8")
        self.assertIn("_backupEncode(", backup)
        self.assertIn("_backupDecode(", backup)
        self.assertIn("Timestamp.fromDate", codec)
        self.assertIn("GeoPoint(", codec)

    def test_automatic_backup_preflight_prevents_missing_collection_deletion(self):
        backup = (ROOT / "lib/admin/admin_backup_actions.dart").read_text(encoding="utf-8")
        restore = backup.split("Future<void> _restoreAutomaticBackup(String backupId) async {", 1)[1].split("Future<void> _restoreBackup() async {", 1)[0]
        self.assertLess(restore.index("for(final item in items.docs)"), restore.index("batch.delete(doc.reference)"))
        self.assertLess(restore.index("if(grouped.isEmpty)"), restore.index("batch.delete(doc.reference)"))
        self.assertIn("for(final collection in grouped.keys)", restore)
        self.assertNotIn("for(final collection in allowed){", restore)
        self.assertIn("if(documents.containsKey(documentId))", restore)
        self.assertIn("if(validatedSettings!=null)", restore)

    def test_backup_restore_preflights_all_documents_before_deletion(self):
        backup = (ROOT / "lib/admin/admin_backup_actions.dart").read_text(encoding="utf-8")
        restore = backup.split("Future<void> _restoreBackup() async {", 1)[1].split("\n  }\n", 1)[0]
        validation = restore.index("for(final entry in rawCollections.entries)")
        decoding = restore.index("final decoded=_backupDecode(rawEntry.value)")
        settings_validation = restore.index("final decodedSettings=_backupDecode(parsed['uiSettings'])")
        confirmation = restore.index("final ok=await showDialog<bool>")
        deletion = restore.index("batch.delete(doc.reference)")
        self.assertLess(validation, decoding)
        self.assertLess(decoding, settings_validation)
        self.assertLess(settings_validation, confirmation)
        self.assertLess(confirmation, deletion)
        self.assertIn("if(validatedSettings!=null)", restore)
        self.assertIn("if(decoded is! Map)throw FormatException", restore)
        self.assertIn("if(id.isEmpty||id.contains('/'))", restore)
        self.assertIn("Backup invalid. Nu s-au modificat date:", restore)

    def test_manual_amount_and_map_route_regressions(self):
        source = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        expense_source = (ROOT / "lib/expenses/expense_page.dart").read_text(encoding="utf-8")
        map_source = (ROOT / "lib/map/map_page.dart").read_text(encoding="utf-8")
        self.assertIn("hasMatch(normalized)", expense_source)
        self.assertIn("normalized = raw.trim().replaceAll", expense_source)
        self.assertIn("Schematic fallback when Mapbox cannot provide road geometry.", map_source)
        self.assertNotIn("for (final c in [number, amount, supplier, desc, litersC, priceC]) { c.dispose(); }", source)


if __name__ == "__main__":
    unittest.main()
