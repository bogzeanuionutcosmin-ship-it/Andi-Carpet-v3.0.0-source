import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/operations/work_date_record_selection.dart';

class _Record {
  const _Record(this.id, this.teamId, this.locationId, this.inWorkDate);

  final String id;
  final String teamId;
  final String locationId;
  final bool inWorkDate;
}

void main() {
  group('selectWorkDateRecords', () {
    test('filters by team, location, and work date while preserving order', () {
      const records = <_Record>[
        _Record('first', 'team-a', 'location-a', true),
        _Record('other-team', 'team-b', 'location-a', true),
        _Record('other-location', 'team-a', 'location-b', true),
        _Record('other-date', 'team-a', 'location-a', false),
        _Record('second', 'team-a', 'location-a', true),
      ];

      final result = selectWorkDateRecords(
        records,
        teamId: 'team-a',
        locationId: 'location-a',
        teamIdOf: (record) => record.teamId,
        locationIdOf: (record) => record.locationId,
        belongsToWorkDate: (record) => record.inWorkDate,
      );

      expect(result.map((record) => record.id), ['first', 'second']);
      expect(records.map((record) => record.id), [
        'first',
        'other-team',
        'other-location',
        'other-date',
        'second',
      ]);
    });

    test('returns an empty list when no record matches', () {
      final result = selectWorkDateRecords(
        const <_Record>[_Record('record', 'team-a', 'location-a', false)],
        teamId: 'team-a',
        locationId: 'location-a',
        teamIdOf: (record) => record.teamId,
        locationIdOf: (record) => record.locationId,
        belongsToWorkDate: (record) => record.inWorkDate,
      );

      expect(result, isEmpty);
    });
  });
}
