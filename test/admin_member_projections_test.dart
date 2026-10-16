import 'package:andi_carpeta/admin/admin_member_projections.dart' as projection;
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(String id, String name, {bool active = true,
    UserRole role = UserRole.member, UserFunction function = UserFunction.worker}) =>
    AppUser(id: id, name: name, role: role, function: function, active: active);

void main() {
  test('filters active profiles and preserves the exact case-insensitive order and object identities', () {
    final users = [_user('z', 'zulu'), _user('b', 'Beta'),
      _user('off', 'Aaron', active: false), _user('a', 'alpha')];
    final before = List<AppUser>.from(users);
    final actual = projection.activeAdminNotificationRecipients(users);
    expect(actual.map((u) => u.id), ['a', 'b', 'z']);
    expect(users, before); expect(identical(actual[0], users[3]), isTrue);
    expect(identical(actual, users), isFalse);
    actual.clear(); expect(users.length, 4);
  });

  test('keeps empty, duplicate and equal-name behavior without deduplication or name normalization', () {
    final users = [_user('same', ' ALPHA'), _user('same', 'alpha'),
      _user('x', 'ALPHA'), _user('blank', '')];
    final original = users.where((u) => u.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    expect(projection.activeAdminNotificationRecipients(users), original);
    expect(projection.activeAdminNotificationRecipients(users).length, 4);
    expect(projection.activeAdminNotificationRecipients([]), isEmpty);
    expect(projection.activeAdminNotificationRecipients([_user('off', '', active: false)]), isEmpty);
  });

  test('professional developer/director functions do not change the member role or assigned rights', () {
    final developer = _user('dev', 'Developer', function: UserFunction.developer);
    final directorFunction = _user('pro', 'Director function', function: UserFunction.director);
    final administrator = _user('admin', 'Administrator', role: UserRole.director);
    final users = [developer, directorFunction, administrator];
    expect(activeAdminNotificationRecipients(users),
      projection.activeAdminNotificationRecipients(users)); // main re-export API.
    expect(developer.role, UserRole.member); expect(developer.functionIds, isEmpty);
    expect(directorFunction.role, UserRole.member); expect(directorFunction.functionIds, isEmpty);
    expect(administrator.role, UserRole.director);
    expect(users.map((u) => u.active), everyElement(isTrue));
    // Projection is display selection, not a server authorization check.
  });

  testWidgets('actual AdminPanel notification dialog uses active projection and cancel performs no mutation', (tester) async {
    final users = [_user('z', 'Zulu synthetic'), _user('off', 'Inactive synthetic', active: false),
      _user('a', 'Alpha synthetic', function: UserFunction.developer)];
    final logs = <String>[]; var changes = 0;
    await tester.pumpWidget(MaterialApp(home: AdminPanelPage(
      users: users, teams: [], cars: [], locations: [], categories: [],
      functionDefinitions: [], schedules: [], records: [], expenses: [],
      perDiems: [], finances: [], settlements: [], notifications: [], audit: [],
      settings: AppSettings(), userName: (id) => id,
      onChanged: () { changes++; }, log: (a, b) => logs.add('$a:$b'),
      saveLocation: (_) async { fail('Unexpected location write'); },
      deleteLocation: (_) async { fail('Unexpected location delete'); },
    )));
    final dynamic state = tester.state(find.byType(AdminPanelPage));
    state.setState(() { state.section = 11; });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Trimite notificare'));
    await tester.pumpAndSettle();
    final recipients = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(recipients.map((w) => (w.title as Text).data), ['Alpha synthetic', 'Zulu synthetic']);
    expect(find.text('Inactive synthetic'), findsNothing);
    expect(find.text('Destinatari (0/2)'), findsOneWidget);
    await tester.tap(find.text('Bifează toate'));
    await tester.pumpAndSettle();
    expect(find.text('Destinatari (2/2)'), findsOneWidget);
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();
    expect(logs, isEmpty); expect(changes, 0);
    expect(users.map((u) => u.id), ['z', 'off', 'a']);
    expect(users.last.role, UserRole.member); expect(users.last.functionIds, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
