import 'package:flutter_test/flutter_test.dart';

import '../lib/expenses/expense_duplicate_matcher.dart';

class _ExpenseRecord {
  const _ExpenseRecord({
    this.team = 'team-a',
    this.settlement,
    this.fingerprint = '',
    this.number = '',
    this.date = const DateTime(2026, 10, 20),
    this.amount = 10,
  });

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
      const candidate = _ExpenseRecord(settlement: null, fingerprint: 'same');
      const otherTeam = _ExpenseRecord(
        team: 'team-b',
        settlement: null,
        fingerprint: 'same',
      );
      const otherSettlement = _ExpenseRecord(
        settlement: 'settlement-b',
        fingerprint: 'same',
      );
      const legacyEmptySettlement = _ExpenseRecord(
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
      const emptyFingerprints = [
        _ExpenseRecord(number: 'different'),
      ];
      expect(
        _find(emptyFingerprints, const _ExpenseRecord(number: 'another')),
        isNull,
      );

      const fingerprintMatch = _ExpenseRecord(
        fingerprint: 'image-hash',
        number: 'unrelated',
        date: DateTime(2026, 10, 22),
        amount: 99,
      );
      expect(
        identical(
          _find(
            [fingerprintMatch],
            const _ExpenseRecord(fingerprint: 'image-hash'),
          ),
          fingerprintMatch,
        ),
        isTrue,
      );
    });

    test('normalizes ASCII document numbers and matches the same calendar day', () {
      const existing = _ExpenseRecord(
        number: '  ab 12 ',
        date: DateTime(2026, 10, 20, 8),
        amount: 10,
      );
      const candidate = _ExpenseRecord(
        number: 'AB-12',
        date: DateTime(2026, 10, 20, 22),
        amount: 10,
      );

      expect(identical(_find([existing], candidate), existing), isTrue);
    });

    test('does not match an otherwise equal document on a different day', () {
      const existing = _ExpenseRecord(
        number: 'AB-12',
        date: DateTime(2026, 10, 20),
      );
      const candidate = _ExpenseRecord(
        number: 'ab 12',
        date: DateTime(2026, 10, 21),
      );

      expect(_find([existing], candidate), isNull);
    });

    test('uses the strict amount tolerance of less than two bani', () {
      const belowBoundary = _ExpenseRecord(
        number: 'DOC-1',
        amount: 0,
      );
      const belowCandidate = _ExpenseRecord(
        number: 'DOC 1',
        amount: .019,
      );
      expect(identical(_find([belowBoundary], belowCandidate), belowBoundary), isTrue);

      const atBoundary = _ExpenseRecord(
        number: 'DOC-1',
        amount: 0,
      );
      const boundaryCandidate = _ExpenseRecord(
        number: 'DOC 1',
        amount: .02,
      );
      expect(_find([atBoundary], boundaryCandidate), isNull);
    });

    test('returns the first matching record in input order', () {
      const first = _ExpenseRecord(fingerprint: 'same');
      const second = _ExpenseRecord(fingerprint: 'same');

      expect(
        identical(
          _find(
            [first, second],
            const _ExpenseRecord(fingerprint: 'same'),
          ),
          first,
        ),
        isTrue,
      );
    });
  });
}
