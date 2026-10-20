import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('schedule clone preserves the complete persisted and local state', () {
    final date = DateTime.utc(2026, 10, 20);
    final alert = DateTime.utc(2026, 10, 20, 8);
    final recalculated = DateTime.utc(2026, 10, 20, 9);
    final updated = DateTime.utc(2026, 10, 20, 10);
    final source = app.WorkSchedule(
      id: 'schedule-1',
      teamId: 'team-1',
      graphId: 'graph-1',
      graphName: 'Intervenții',
      date: date,
      items: [
        app.ScheduleItem(
          locationId: 'location-1',
          locationNameSnapshot: 'Client',
          addressSnapshot: 'Strada 1',
          typeSnapshot: app.LocationType.horeca,
          categoryIdSnapshot: 'horeca',
          order: 2,
          transferred: true,
          facadePlanned: true,
        ),
      ],
      active: false,
      closed: true,
      started: true,
      paused: true,
      postponed: true,
      autoProposed: true,
      planAlertAt: alert,
      planAlertReason: 'late',
      lastRecalculatedAt: recalculated,
      recalculationCount: 4,
      learningExplanation: 'learned route',
      learningConfidence: 0.75,
      learningSamples: 6,
      departureName: 'Brăila',
      departureLatitude: 45.27,
      departureLongitude: 27.96,
      returnName: 'Galați',
      returnLatitude: 45.43,
      returnLongitude: 28.04,
      updatedAt: updated,
      writeToken: 'write-token',
      persisted: true,
    );

    final copy = app.cloneWorkSchedule(source);

    expect(copy, isNot(same(source)));
    expect(copy.id, source.id);
    expect(copy.teamId, source.teamId);
    expect(copy.graphId, source.graphId);
    expect(copy.graphName, source.graphName);
    expect(copy.date, source.date);
    expect(copy.active, source.active);
    expect(copy.closed, source.closed);
    expect(copy.started, source.started);
    expect(copy.paused, source.paused);
    expect(copy.postponed, source.postponed);
    expect(copy.autoProposed, source.autoProposed);
    expect(copy.planAlertAt, source.planAlertAt);
    expect(copy.planAlertReason, source.planAlertReason);
    expect(copy.lastRecalculatedAt, source.lastRecalculatedAt);
    expect(copy.recalculationCount, source.recalculationCount);
    expect(copy.learningExplanation, source.learningExplanation);
    expect(copy.learningConfidence, source.learningConfidence);
    expect(copy.learningSamples, source.learningSamples);
    expect(copy.departureName, source.departureName);
    expect(copy.departureLatitude, source.departureLatitude);
    expect(copy.departureLongitude, source.departureLongitude);
    expect(copy.returnName, source.returnName);
    expect(copy.returnLatitude, source.returnLatitude);
    expect(copy.returnLongitude, source.returnLongitude);
    expect(copy.updatedAt, source.updatedAt);
    expect(copy.writeToken, source.writeToken);
    expect(copy.persisted, source.persisted);

    expect(copy.items, isNot(same(source.items)));
    expect(copy.items, hasLength(1));
    final copiedItem = copy.items.single;
    final originalItem = source.items.single;
    expect(copiedItem, isNot(same(originalItem)));
    expect(copiedItem.locationId, originalItem.locationId);
    expect(copiedItem.locationNameSnapshot, originalItem.locationNameSnapshot);
    expect(copiedItem.addressSnapshot, originalItem.addressSnapshot);
    expect(copiedItem.typeSnapshot, originalItem.typeSnapshot);
    expect(copiedItem.categoryIdSnapshot, originalItem.categoryIdSnapshot);
    expect(copiedItem.order, originalItem.order);
    expect(copiedItem.transferred, originalItem.transferred);
    expect(copiedItem.facadePlanned, originalItem.facadePlanned);

    copiedItem.order = 1;
    copiedItem.transferred = false;
    copy.items.clear();
    expect(originalItem.order, 2);
    expect(originalItem.transferred, isTrue);
    expect(source.items, hasLength(1));
  });
}
