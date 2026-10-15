import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums.dart';
import 'package:andi_carpeta/schedule/schedule_card_full.dart';

void main() {
  testWidgets('renders schedule state and forwards add, remove, and reorder',
      (tester) async {
    final date = DateTime(2026, 10, 14);
    final item = ScheduleItem(
      locationId: 'location-1',
      locationNameSnapshot: 'Magazin Centru',
      addressSnapshot: 'Strada Exemplu 10',
      typeSnapshot: LocationType.other,
      categoryIdSnapshot: 'test-category',
      order: 0,
    );
    final schedule = WorkSchedule(
      id: 'schedule-1',
      teamId: 'team-1',
      date: date,
      items: [item],
      autoProposed: true,
      learningConfidence: .75,
    );
    final record = CentralizerRecord(
      id: 'record-1',
      teamId: 'team-1',
      locationId: 'location-1',
      type: LocationType.other,
      locationNameSnapshot: 'Magazin Centru',
      addressSnapshot: 'Strada Exemplu 10',
      status: WorkAttemptStatus.completed,
      startedAt: date,
      finishedAt: date.add(const Duration(minutes: 10)),
    );
    var added = false;
    ScheduleItem? removed;
    List<int>? reordered;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleCardFull(
          schedule: schedule,
          locations: const [],
          categories: const [],
          records: [record],
          canEdit: true,
          onAdd: () => added = true,
          onRemove: (value) => removed = value,
          onReorder: (oldIndex, newIndex) => reordered = [oldIndex, newIndex],
        ),
      ),
    ));

    expect(find.text('Zi grafic · miercuri-14-octombrie-2026'), findsOneWidget);
    expect(find.text('Ordine propusă · încredere 75%'), findsOneWidget);
    expect(find.text('Strada Exemplu 10 · Finalizată'), findsOneWidget);

    await tester.tap(find.text('Adaugă locații'));
    await tester.pump();
    expect(added, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(removed, same(item));

    final reorderList = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(reorderList.onReorder, isNotNull);
    reorderList.onReorder!(0, 1);
    expect(reordered, [0, 1]);
  });

  testWidgets('closed schedules hide edit controls and disable reordering',
      (tester) async {
    final schedule = WorkSchedule(
      id: 'schedule-closed',
      teamId: 'team-1',
      date: DateTime(2026, 10, 14),
      items: [
        ScheduleItem(
          locationId: 'location-1',
          locationNameSnapshot: 'Magazin Centru',
          addressSnapshot: 'Strada Exemplu 10',
          typeSnapshot: LocationType.other,
          categoryIdSnapshot: 'test-category',
          order: 0,
        ),
      ],
      closed: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleCardFull(
          schedule: schedule,
          locations: const [],
          categories: const [],
          records: const [],
          canEdit: true,
          onAdd: () {},
          onRemove: (_) {},
          onReorder: (_, __) {},
        ),
      ),
    ));

    expect(find.text('Adaugă locații'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final reorderList = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(reorderList.buildDefaultDragHandles, isFalse);
    expect(reorderList.onReorder, isNotNull);
  });
}
