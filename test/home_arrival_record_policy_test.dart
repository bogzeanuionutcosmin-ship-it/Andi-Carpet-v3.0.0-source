import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

app.CentralizerRecord record({
  app.WorkAttemptStatus status = app.WorkAttemptStatus.waitingAccess,
  DateTime? startedAt,
  DateTime? finishedAt,
}) => app.CentralizerRecord(
  id: 'record-1',
  teamId: 'team-1',
  locationId: 'location-1',
  type: app.LocationType.magic,
  locationNameSnapshot: 'Client',
  addressSnapshot: 'Address',
  status: status,
  startedAt: startedAt,
  finishedAt: finishedAt,
);

void main() {
  group('canWriteHomeArrivalChoice', () {
    test('allows a first arrival when there is no existing record', () {
      expect(app.canWriteHomeArrivalChoice(null), isTrue);
    });

    test('blocks overwriting running and waiting records', () {
      expect(
        app.canWriteHomeArrivalChoice(
          record(status: app.WorkAttemptStatus.running),
        ),
        isFalse,
      );
      expect(
        app.canWriteHomeArrivalChoice(
          record(status: app.WorkAttemptStatus.waitingAccess),
        ),
        isFalse,
      );
    });

    test('blocks records whose existing completed getter is true', () {
      expect(
        app.canWriteHomeArrivalChoice(record(
          status: app.WorkAttemptStatus.completed,
          startedAt: DateTime.utc(2026, 10, 20, 10),
          finishedAt: DateTime.utc(2026, 10, 20, 11),
        )),
        isFalse,
      );
    });

    test('preserves the existing computed-completion boundary', () {
      // A completed status without both timestamps is not a completed record
      // under CentralizerRecord.completed and remains eligible as before.
      expect(
        app.canWriteHomeArrivalChoice(
          record(status: app.WorkAttemptStatus.completed),
        ),
        isTrue,
      );
    });
  });
}
