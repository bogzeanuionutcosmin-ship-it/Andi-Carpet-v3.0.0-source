import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/teams/team_selector.dart';

void main() {
  testWidgets('team selector retains selected team, accent, and callback', (tester) async {
    final teams = [
      Team(id: 'a', name: 'Alpha', members: const []),
      Team(id: 'b', name: 'Beta', members: const []),
    ];
    int? changedIndex;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeamSelector(
          teams: teams,
          selected: 0,
          onChanged: (value) => changedIndex = value,
          accent: const Color(0xff1565c0),
        ),
      ),
    ));

    expect(find.text('Alpha'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.groups));
    expect(icon.color, const Color(0xff1565c0));

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();

    expect(changedIndex, 1);
    expect(find.text('Beta'), findsOneWidget);
  });
}
