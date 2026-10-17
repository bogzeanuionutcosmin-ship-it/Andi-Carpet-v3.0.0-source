import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/centralizer/correction_snapshot.dart';

void main() {
  final startedAt = DateTime.utc(2026, 10, 15, 22, 45);
  final finishedAt = DateTime.utc(2026, 10, 16, 0, 15);
  final expected = <String, Object?>{
    'teamId': 'craiova',
    'locationId': 'sala-11',
    'type': 'magic',
    'status': 'completed',
    'startedAt': startedAt,
    'finishedAt': finishedAt,
    'facadeDone': false,
    'facadePlanned': false,
  };

  test('accepts legacy records with omitted optional facade fields', () {
    final current = <String, dynamic>{
      'teamId': 'craiova',
      'locationId': 'sala-11',
      'type': 'magic',
      'status': 'completed',
      'startedAt': Timestamp.fromDate(startedAt),
      'finishedAt': Timestamp.fromDate(finishedAt),
    };

    expect(centralizerCorrectionSnapshotMatches(current, expected), isTrue);
  });

  test('accepts explicitly stored defaults and null timestamps', () {
    final nullableExpected = <String, Object?>{
      ...expected,
      'startedAt': null,
      'finishedAt': null,
    };

    expect(
      centralizerCorrectionSnapshotMatches(
        <String, dynamic>{
          'teamId': 'craiova',
          'locationId': 'sala-11',
          'type': 'magic',
          'status': 'completed',
          'startedAt': null,
          'finishedAt': null,
          'facadeDone': false,
          'facadePlanned': false,
        },
        nullableExpected,
      ),
      isTrue,
    );
  });

  test('rejects stale time, facade, status, team, or location values', () {
    final current = <String, dynamic>{
      'teamId': 'craiova',
      'locationId': 'sala-11',
      'type': 'magic',
      'status': 'completed',
      'startedAt': Timestamp.fromDate(startedAt),
      'finishedAt': Timestamp.fromDate(finishedAt),
      'facadeDone': false,
      'facadePlanned': false,
    };

    for (final stale in <Map<String, dynamic>>[
      <String, dynamic>{'startedAt': Timestamp.fromDate(startedAt.add(const Duration(minutes: 1)))},
      <String, dynamic>{'finishedAt': Timestamp.fromDate(finishedAt.add(const Duration(minutes: 1)))},
      <String, dynamic>{'facadeDone': true},
      <String, dynamic>{'status': 'running'},
      <String, dynamic>{'teamId': 'other-team'},
      <String, dynamic>{'locationId': 'other-room'},
    ]) {
      expect(
        centralizerCorrectionSnapshotMatches(<String, dynamic>{...current, ...stale}, expected),
        isFalse,
        reason: 'stale fields: $stale',
      );
    }
  });

  test('rejects missing required identity and status fields', () {
    expect(
      centralizerCorrectionSnapshotMatches(
        <String, dynamic>{
          'locationId': 'sala-11',
          'type': 'magic',
          'status': 'completed',
          'startedAt': Timestamp.fromDate(startedAt),
          'finishedAt': Timestamp.fromDate(finishedAt),
        },
        expected,
      ),
      isFalse,
    );
  });
}
