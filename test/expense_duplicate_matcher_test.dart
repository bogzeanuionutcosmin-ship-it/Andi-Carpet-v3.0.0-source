import 'package:flutter_test/flutter_test.dart';

import '../lib/expenses/expense_duplicate_matcher.dart';

class _ExpenseRecord {
  _ExpenseRecord({
    this.team = 'team-a',
    this.settlement,
    this.fingerprint = '',
    this.number = '',
    DateTime? date,
    this.amount = 10,
  }) : date = date ?? DateTime(2026, 10, 20);

  final String team;
  final String? settlement;
  final String fingerprint;
  final String number;
  final DateTime date;
  final double amount;
}

_ExpenseRecord? _find(
  Iterable<_ExpenseRecord> existing,
  _ExpenseRecord candidate,
) {
  return findPotentialExpenseDuplicate<_ExpenseRecord>(
    existing: existing,
    candidate: candidate,
    teamId: (entry) => entry.team,
    settlementId: (entry) => entry.settlement,
    imageFingerprint: (entry) => entry.fingerprint,
    documentNumber: (entry) => entry.number,
    date: (entry) => entry.date,
    amount: (entry) => entry.amount,
  );
}

void main() {
  group('legacy expense duplicate matcher', () {
    test('isolates teams and settlements while treating null and empty alike', () {
      final candidate = _ExpenseRecord(
        settlement: null,
        fingerprint: 'same',
      );
      final otherTeam = _ExpenseRecord(
        team: 'team-b',
        settlement: null,
        fingerprint: 'same',
      );
      final otherSettlement = _ExpenseRecord(
        settlement: 'settlement-b',
        fingerprint: 'same',
      );
      final legacyEmptySettlement = _ExpenseRecord(
        settlement: '',
        fingerprint: 'same',
      );

      expect(
        identical(
          _find(
            [otherTeam, otherSettlement, legacyEmptySettlement],
            candidate,
          ),
          legacyEmptySettlement,
        ),
        isTrue,
      );
    });

    test('requires a nonempty candidate fingerprint to match fingerprints', () {
      final emptyFingerprints = [
        _ExpenseRecord(number: 'different'),
      ];
      expect(
        _find(emptyFingerprints, _ExpenseRecord(number: 'another')),
        isNull,
      );

      final fingerprintMatch = _ExpenseRecord(
        fingerprint: 'image-hash',
        number: 'unrelated',
        date: DateTime(2026, 10, 22),
        amount: 99,
      );
      expect(
        identical(
          _find(
            [fingerprintMatch],
            _ExpenseRecord(fingerprint: 'image-hash'),
          ),
          fingerprintMatch,
        ),
        isTrue,
      );
    });

    test('normalizes ASCII document numbers and matches the same calendar day', () {
      final existing = _ExpenseRecord(
        number: '  ab 12 ',
        date: DateTime(2026, 10, 20, 8),
        amount: 10,
      );
      final candidate = _ExpenseRecord(
        number: 'AB-12',
        date: DateTime(2026, 10, 20, 22),
        amount: 10,
      );

      expect(identical(_find([existing], candidate), existing), isTrue);
    });

    test('does not match an otherwise equal document on a different day', () {
      final existing = _ExpenseRecord(
        number: 'AB-12',
        date: DateTime(2026, 10, 20),
      );
      final candidate = _ExpenseRecord(
        number: 'ab 12',
        date: DateTime(2026, 10, 21),
      );

      expect(_find([existing], candidate), isNull);
    });

    test('uses the strict amount tolerance of less than two bani', () {
      final belowBoundary = _ExpenseRecord(
        number: 'DOC-1',
        amount: 0,
      );
      final belowCandidate = _ExpenseRecord(
        number: 'DOC 1',
        amount: .019,
      );
      expect(
        identical(_find([belowBoundary], belowCandidate), belowBoundary),
        isTrue,
      );

      final atBoundary = _ExpenseRecord(
        number: 'DOC-1',
        amount: 0,
      );
      final boundaryCandidate = _ExpenseRecord(
        number: 'DOC 1',
        amount: .02,
      );
      expect(_find([atBoundary], boundaryCandidate), isNull);
    });

    test('returns the first matching record in input order', () {
      final first = _ExpenseRecord(fingerprint: 'same');
      final second = _ExpenseRecord(fingerprint: 'same');

      expect(
        identical(
          _find(
            [first, second],
            _ExpenseRecord(fingerprint: 'same'),
          ),
          first,
        ),
        isTrue,
      );
    });
  });
}
