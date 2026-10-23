import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/schedule/schedule_document_codec.dart';

void main() {
  test('schedule codec preserves the full document and stable revision fields', () {
    final original = WorkSchedule(
      id: 'day-1', teamId: 'team-1', graphId: 'graph-1', graphName: 'Grafic 1',
      date: DateTime.utc(2026, 10, 23),
      items: [
        ScheduleItem(
          interventionId: 'visit-1', locationId: 'room-1', locationNameSnapshot: 'Sala 1',
          addressSnapshot: 'Strada 1', typeSnapshot: LocationType.magic,
          categoryIdSnapshot: 'category-1', order: 1, transferred: true, facadePlanned: true,
        ),
      ],
      active: false, closed: false, started: true, paused: false, postponed: true,
      autoProposed: true, planAlertAt: DateTime.utc(2026, 10, 23, 6), planAlertReason: 'alert',
      lastRecalculatedAt: DateTime.utc(2026, 10, 22), recalculationCount: 3,
      learningExplanation: 'confidence', learningConfidence: .75, learningSamples: 8,
      departureName: 'Brăila', departureLatitude: 45.27, departureLongitude: 27.96,
      returnName: 'Galați', returnLatitude: 45.44, returnLongitude: 28.04,
      updatedAt: DateTime.utc(2026, 10, 22, 8), writeToken: 'old-token', persisted: true,
    );
    final commitTime = Timestamp.fromDate(DateTime.utc(2026, 10, 23, 8));
    final data = scheduleDocumentData(original, updatedAt: commitTime, writeToken: 'new-token');
    final restored = scheduleFromDocumentData('day-1', data);

    expect(restored.teamId, original.teamId);
    expect(restored.graphId, original.graphId);
    expect(restored.graphName, original.graphName);
    expect(restored.date.isAtSameMomentAs(original.date), isTrue);
    expect(restored.active, original.active);
    expect(restored.closed, original.closed);
    expect(restored.started, original.started);
    expect(restored.paused, original.paused);
    expect(restored.postponed, original.postponed);
    expect(restored.autoProposed, original.autoProposed);
    expect(restored.planAlertAt!.isAtSameMomentAs(original.planAlertAt!), isTrue);
    expect(restored.planAlertReason, original.planAlertReason);
    expect(restored.lastRecalculatedAt!.isAtSameMomentAs(original.lastRecalculatedAt!), isTrue);
    expect(restored.recalculationCount, original.recalculationCount);
    expect(restored.learningExplanation, original.learningExplanation);
    expect(restored.learningConfidence, original.learningConfidence);
    expect(restored.learningSamples, original.learningSamples);
    expect(restored.departureName, original.departureName);
    expect(restored.departureLatitude, original.departureLatitude);
    expect(restored.departureLongitude, original.departureLongitude);
    expect(restored.returnName, original.returnName);
    expect(restored.returnLatitude, original.returnLatitude);
    expect(restored.returnLongitude, original.returnLongitude);
    expect(restored.items.single.interventionId, 'visit-1');
    expect(restored.items.single.locationId, 'room-1');
    expect(restored.items.single.transferred, isTrue);
    expect(restored.items.single.facadePlanned, isTrue);
    expect(restored.updatedAt!.isAtSameMomentAs(commitTime.toDate()), isTrue);
    expect(restored.writeToken, 'new-token');
    expect(restored.persisted, isTrue);
  });
}
