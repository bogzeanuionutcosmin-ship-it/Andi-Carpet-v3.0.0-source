import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  final teams = <app.Team>[
    app.Team(id: 'team-a', name: 'A', members: <String>['other-user']),
    app.Team(id: 'team-b', name: 'B', members: <String>['current-user']),
    app.Team(id: 'team-c', name: 'C', members: <String>['current-user']),
  ];

  test('schedule screen selects a team the signed-in member belongs to', () {
    expect(
      app.preferredProgramTeamIndex(
        teams: teams,
        currentIndex: 0,
        canEditTeam: (teamId) => teams
            .firstWhere((team) => team.id == teamId)
            .members
            .contains('current-user'),
      ),
      1,
    );
  });

  test('keeps the selected team when the user is already a member', () {
    expect(
      app.preferredProgramTeamIndex(
        teams: teams,
        currentIndex: 2,
        canEditTeam: (teamId) => teams
            .firstWhere((team) => team.id == teamId)
            .members
            .contains('current-user'),
      ),
      2,
    );
  });

  test('admin selection is preserved and safely clamped after team refresh', () {
    expect(
      app.preferredProgramTeamIndex(
        teams: teams,
        currentIndex: 2,
        canEditTeam: (_) => true,
      ),
      2,
    );
    expect(
      app.preferredProgramTeamIndex(
        teams: teams,
        currentIndex: 9,
        canEditTeam: (_) => true,
      ),
      2,
    );
  });

  test('preserves a read-only selection when no team grants edit membership', () {
    expect(
      app.preferredProgramTeamIndex(
        teams: teams,
        currentIndex: 1,
        canEditTeam: (_) => false,
      ),
      1,
    );
  });
}
