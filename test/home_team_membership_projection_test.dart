import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  app.Team team(String id, List<String> members, {bool active = true}) =>
      app.Team(id: id, name: id, members: members, active: active);

  test('uses the first containing team and preserves user order', () {
    final result = app.projectHomeTeamMembership(
      userIds: ['shared', 'second-only', 'unassigned'],
      teams: [
        team('first', ['shared'], active: false),
        team('second', ['shared', 'second-only']),
      ],
    );

    expect(result, ['first', 'second', null]);
  });

  test('keeps every user unassigned when there are no teams', () {
    expect(
      app.projectHomeTeamMembership(
        userIds: ['one', 'two'],
        teams: const <app.Team>[],
      ),
      [null, null],
    );
  });

  test('empty user list produces no assignments', () {
    expect(
      app.projectHomeTeamMembership(
        userIds: const <String>[],
        teams: [team('team', ['one'])],
      ),
      isEmpty,
    );
  });
}
