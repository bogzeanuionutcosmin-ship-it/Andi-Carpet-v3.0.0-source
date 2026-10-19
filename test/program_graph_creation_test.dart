import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  for (final keyboardInset in [0.0, 290.0]) {
  testWidgets('creates an eleven-location Graph with keyboard inset $keyboardInset', (tester) async {
    tester.view.physicalSize = const Size(411, 731);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final locations = List.generate(11, (i) => app.Location(
      id: 'room-$i', name: 'Sala ${i + 1}', address: 'Adresă ${i + 1}',
      type: app.LocationType.magic,
    ));
    final saved = <app.WorkSchedule>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: app.ProgramPage(
      currentUser: app.AppUser(id: 'editor', name: 'Editor', role: app.UserRole.member),
      teams: [app.Team(id: 'team', name: 'Craiova', members: ['editor'])],
      cars: [], locations: locations, categories: [], schedules: [], records: [],
      settings: app.AppSettings(), canEditTeam: (_) => true, canEditProgram: true,
      userName: (_) => 'Editor', onChanged: () {}, notifyTeam: (_, __, ___) {},
      log: (_, __) {}, saveSchedules: (schedules) async { saved.addAll(schedules); },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creează grafic'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    await tester.pumpAndSettle();
    // Search uses the real picker UI and handles both sorted/offscreen rows.
    for (final location in locations) {
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), location.name);
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(CheckboxListTile, location.name);
      await tester.scrollUntilVisible(tile, 80, scrollable: find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    expect(find.widgetWithText(Chip, '1. Sala 1'), findsOneWidget);
    expect(find.widgetWithText(Chip, '11. Sala 11'), findsOneWidget);
    await tester.tap(find.text('Finalizare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuă'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Craiova XI');
    await tester.tap(find.text('Creează graficul'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(saved, hasLength(1));
    expect(saved.single.graphName, 'Craiova XI');
    expect(saved.single.items.map((item) => item.locationId).toList(),
      locations.map((location) => location.id).toList());
  });
  }
}
