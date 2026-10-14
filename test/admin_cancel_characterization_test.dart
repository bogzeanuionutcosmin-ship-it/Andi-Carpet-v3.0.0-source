import 'package:andi_carpeta/main.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/admin_ui_fixture.dart';

AppUser member(String id, String name, {bool active = true}) => AppUser(
  id: id, name: name, role: UserRole.member, function: UserFunction.developer,
  active: active,
);

void main() {
  late FirebasePlatform original;
  late NoFirebaseAccess firebase;
  setUp(() {
    original = FirebasePlatform.instance;
    firebase = NoFirebaseAccess();
    FirebasePlatform.instance = firebase;
  });
  tearDown(() { FirebasePlatform.instance = original; });
  Future<void> finish(WidgetTester tester, AdminUiFixture fixture) async {
    await tester.pumpWidget(const SizedBox());
    expect(firebase.attempts, isEmpty); // zero read/write/listener/send attempts
    expect(fixture.logs, isEmpty);
    expect(fixture.changes, 0);
    expect(tester.takeException(), isNull);
  }

  for (final users in <List<AppUser>>[[], [member('off', 'Inactive', active: false)]]) {
    testWidgets('no active recipients shows error without dialog or Firebase access (${users.length} rows)', (tester) async {
      final fixture = AdminUiFixture(users: users);
      await fixture.mount(tester, 11);
      await tester.tap(find.widgetWithText(FilledButton, 'Trimite notificare'));
      await tester.pumpAndSettle();
      expect(find.text('Nu există membri activi care să primească notificarea.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(users.every((u) => !u.active), isTrue);
      await finish(tester, fixture);
    });
  }

  testWidgets('duplicate display names retain distinct IDs; no selection and single selection both cancel safely', (tester) async {
    final users = [member('a', 'Duplicate'), member('b', 'Duplicate'), member('off', 'Hidden', active: false)];
    final fixture = AdminUiFixture(users: users);
    await fixture.mount(tester, 11);
    for (final select in [false, true]) {
      await tester.tap(find.widgetWithText(FilledButton, 'Trimite notificare'));
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsNWidgets(2));
      expect(find.text('Hidden'), findsNothing);
      if (select) {
        await tester.ensureVisible(find.byType(CheckboxListTile).first);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Destinatari (${select ? 1 : 0}/2)'), findsOneWidget);
      await tester.tap(find.text('Anulează'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
    expect(users.map((u) => u.role), everyElement(UserRole.member));
    expect(users.map((u) => u.functionIds), everyElement(isEmpty));
    await finish(tester, fixture);
  });

  testWidgets('scrollable recipient list beyond viewport selects last member then cancels', (tester) async {
    final users = List.generate(35, (i) => member('id-$i', 'Member ${i.toString().padLeft(2, '0')}'));
    final fixture = AdminUiFixture(users: users);
    await fixture.mount(tester, 11);
    await tester.tap(find.widgetWithText(FilledButton, 'Trimite notificare'));
    await tester.pumpAndSettle();
    expect(find.text('Destinatari (0/35)'), findsOneWidget);
    final last = find.widgetWithText(CheckboxListTile, 'Member 34');
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pumpAndSettle();
    final selected = tester.widget<CheckboxListTile>(last);
    expect(selected.value, isTrue);
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();
    expect(users.length, 35);
    expect(users.map((u) => u.role), everyElement(UserRole.member));
    await finish(tester, fixture);
  });

  testWidgets('real function edit changes only dialog copy before cancel, preserving definition and rights', (tester) async {
    final definition = FunctionDefinition(id: 'developer', name: 'Developer', iconKey: 'badge_developer',
      colorValue: 0xff123456, permissions: {}, active: false);
    final fixture = AdminUiFixture(functions: [definition]);
    await fixture.mount(tester, 14);
    await tester.tap(find.byTooltip('Editează funcția'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed locally');
    final toggle = find.widgetWithText(SwitchListTile, 'Funcție activă').last;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();
    expect(definition.name, 'Developer');
    expect(definition.active, isFalse);
    expect(definition.permissions, isEmpty);
    expect(definition.badgeKeys, ['badge_developer']);
    expect(definition.colorValue, 0xff123456);
    await finish(tester, fixture);
  });
}
