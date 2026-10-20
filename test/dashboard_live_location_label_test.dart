import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);

  Map<String, dynamic> live({
    Object? latitude = 44.4268,
    Object? longitude = 26.1025,
    Object? updatedAt,
    String locality = 'Craiova',
  }) => {
    'latitude': latitude,
    'longitude': longitude,
    'updatedAt': updatedAt ?? Timestamp.fromDate(now),
    'localityLabel': locality,
  };

  app.CentralizerRecord record({
    required String id,
    required String locationId,
    String teamId = 'team-1',
    app.WorkAttemptStatus status = app.WorkAttemptStatus.running,
    DateTime? finishedAt,
  }) => app.CentralizerRecord(
    id: id,
    teamId: teamId,
    locationId: locationId,
    type: app.LocationType.magic,
    locationNameSnapshot: id,
    addressSnapshot: 'Address $id',
    status: status,
    startedAt: now.subtract(const Duration(minutes: 10)),
    finishedAt: finishedAt,
  );

  app.Location site(String id, String name, double latitude) => app.Location(
    id: id,
    name: name,
    address: 'Address $name',
    type: app.LocationType.magic,
    latitude: latitude,
    longitude: 1,
  );

  String resolve({
    Map<String, dynamic>? payload,
    Iterable<app.CentralizerRecord> records = const [],
    Iterable<app.Location> locations = const [],
    bool Function(app.CentralizerRecord)? belongsToWorkDate,
    Map<double, double> distanceBySiteLatitude = const {},
  }) => app.dashboardMemberLocationLabel(
    live: payload,
    teamId: 'team-1',
    records: records,
    locations: locations,
    now: () => now,
    belongsToWorkDate: (record, workDate) =>
        belongsToWorkDate?.call(record) ?? true,
    distanceBetween: (startLat, startLon, endLat, endLon) =>
        distanceBySiteLatitude[endLat] ?? double.infinity,
    formatTime: (_) => '12:00',
    locationCityLabel: (name, address) => 'City:$name',
  );

  group('dashboardMemberLocationLabel', () {
    test('rejects missing and invalid coordinates', () {
      expect(resolve(), 'Locație live indisponibilă');
      expect(resolve(payload: live(latitude: double.nan)), 'Locație live indisponibilă');
      expect(resolve(payload: live(longitude: double.infinity)), 'Locație live indisponibilă');
      expect(resolve(payload: live(latitude: 90.01)), 'Locație live indisponibilă');
      expect(resolve(payload: live(longitude: -180.01)), 'Locație live indisponibilă');
    });

    test('preserves fresh timestamp boundaries and rejects stale/future data', () {
      expect(
        resolve(payload: live(updatedAt: Timestamp.fromDate(now.subtract(const Duration(minutes: 30))))),
        'Craiova · actualizat 12:00',
      );
      expect(
        resolve(payload: live(updatedAt: Timestamp.fromDate(now.subtract(const Duration(minutes: 30, microseconds: 1))))),
        'Locație live neactualizată',
      );
      expect(
        resolve(payload: live(updatedAt: Timestamp.fromDate(now.add(const Duration(minutes: 5))))),
        'Craiova · actualizat 12:00',
      );
      expect(
        resolve(payload: live(updatedAt: Timestamp.fromDate(now.add(const Duration(minutes: 5, microseconds: 1))))),
        'Locație live neactualizată',
      );
    });

    test('proximity alone never labels a site as active work', () {
      final nearby = site('site-1', 'Near Site', 1);
      expect(
        resolve(
          records: const [],
          locations: [nearby],
          distanceBySiteLatitude: {1: 1},
        ),
        'Craiova · actualizat 12:00',
      );
    });

    test('selects the nearest site within 150 m only for active eligible records', () {
      final locations = [
        site('site-1', 'Farther', 1),
        site('site-2', 'Nearest', 2),
        site('site-3', 'Wrong Team', 3),
        site('site-4', 'Finished', 4),
        site('site-5', 'Not Running', 5),
      ];
      final records = [
        record(id: 'r1', locationId: 'site-1'),
        record(id: 'r2', locationId: 'site-2'),
        record(id: 'r3', locationId: 'site-3', teamId: 'team-2'),
        record(id: 'r4', locationId: 'site-4', finishedAt: now),
        record(id: 'r5', locationId: 'site-5', status: app.WorkAttemptStatus.waitingAccess),
      ];
      expect(
        resolve(
          records: records,
          locations: locations,
          distanceBySiteLatitude: {1: 100, 2: 20, 3: 1, 4: 1, 5: 1},
        ),
        'Nearest · City:Nearest · actualizat 12:00',
      );
    });

    test('includes the 150 m boundary and falls back beyond it', () {
      final active = record(id: 'r1', locationId: 'site-1');
      final location = site('site-1', 'Boundary', 1);
      expect(
        resolve(records: [active], locations: [location], distanceBySiteLatitude: {1: 150}),
        'Boundary · City:Boundary · actualizat 12:00',
      );
      expect(
        resolve(records: [active], locations: [location], distanceBySiteLatitude: {1: 150.001}),
        'Craiova · actualizat 12:00',
      );
    });

    test('uses the unavailable locality fallback when no label is supplied', () {
      expect(resolve(payload: live(locality: '  ')), 'Oraș/județ indisponibil · actualizat 12:00');
    });
  });
}
