import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/reports/centralizer_pdf_projection.dart';

class _Record {
  const _Record({
    required this.id,
    required this.teamId,
    required this.type,
    required this.status,
    required this.name,
    required this.address,
    required this.eventDate,
  });

  final String id;
  final String teamId;
  final LocationType type;
  final WorkAttemptStatus status;
  final String name;
  final String address;
  final DateTime eventDate;
}

void main() {
  List<CentralizerPdfProjectionRow<_Record>> project(
    List<_Record> records, {
    String? teamId,
    DateTime? from,
    DateTime? to,
    String search = '',
    WorkAttemptStatus? statusFilter,
  }) =>
      projectCentralizerPdfExecutionRows<_Record>(
        records: records,
        type: LocationType.magic,
        teamId: teamId,
        from: from,
        to: to,
        search: search,
        statusFilter: statusFilter,
        typeOf: (record) => record.type,
        teamIdOf: (record) => record.teamId,
        statusOf: (record) => record.status,
        locationNameOf: (record) => record.name,
        addressOf: (record) => record.address,
        eventDateOf: (record) => record.eventDate,
      );

  test('filters by type, team, status and normalized name or address', () {
    final records = [
      _Record(
        id: 'wrong-date-order',
        teamId: 'team-a',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala 2',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 16, 10),
      ),
      _Record(
        id: 'matching-address',
        teamId: 'team-a',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala 1',
        address: 'Craiova Centru',
        eventDate: DateTime(2026, 10, 15, 10),
      ),
      _Record(
        id: 'wrong-team',
        teamId: 'team-b',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala 3',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 14, 10),
      ),
      _Record(
        id: 'wrong-status',
        teamId: 'team-a',
        type: LocationType.magic,
        status: WorkAttemptStatus.refused,
        name: 'Sala 4',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 13, 10),
      ),
      _Record(
        id: 'wrong-type',
        teamId: 'team-a',
        type: LocationType.horeca,
        status: WorkAttemptStatus.completed,
        name: 'Sala 5',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 12, 10),
      ),
    ];

    final rows = project(
      records,
      teamId: 'team-a',
      search: '  CRAIOVA CENTRU ',
      statusFilter: WorkAttemptStatus.completed,
    );

    expect(rows.map((row) => row.record.id), ['matching-address']);
    expect(rows.single.date, DateTime(2026, 10, 15, 10));
  });

  test('sorts by event date, preserves empty-team behavior and end-date boundary', () {
    final records = [
      _Record(
        id: 'last-microsecond',
        teamId: 'team-a',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala A',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 16, 23, 59, 59, 999, 999),
      ),
      _Record(
        id: 'next-midnight',
        teamId: 'team-a',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala B',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 17),
      ),
      _Record(
        id: 'first',
        teamId: 'team-b',
        type: LocationType.magic,
        status: WorkAttemptStatus.completed,
        name: 'Sala C',
        address: 'Craiova',
        eventDate: DateTime(2026, 10, 16, 0, 0, 0, 0, 1),
      ),
    ];

    final rows = project(
      records,
      teamId: '',
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );

    expect(rows.map((row) => row.record.id), ['first', 'last-microsecond']);
    expect(rows.first.date, DateTime(2026, 10, 16, 0, 0, 0, 0, 1));
  });

  test('uses the injected event date consistently for filtering and projection', () {
    final record = _Record(
      id: 'overnight',
      teamId: 'team-a',
      type: LocationType.magic,
      status: WorkAttemptStatus.completed,
      name: 'Sala 1',
      address: 'Craiova',
      eventDate: DateTime(2026, 10, 15, 23, 55),
    );

    final rows = project(
      [record],
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );

    // The model's injected event-time policy can select the finished-at date,
    // independently from the start time stored on the record.
    final overnightRows = project(
      [
        _Record(
          id: record.id,
          teamId: record.teamId,
          type: record.type,
          status: record.status,
          name: record.name,
          address: record.address,
          eventDate: DateTime(2026, 10, 16, 0, 20),
        ),
      ],
      from: DateTime(2026, 10, 16),
      to: DateTime(2026, 10, 16),
    );

    expect(rows, isEmpty);
    expect(overnightRows.single.date, DateTime(2026, 10, 16, 0, 20));
    expect(overnightRows.single.record.id, 'overnight');
  });
}
