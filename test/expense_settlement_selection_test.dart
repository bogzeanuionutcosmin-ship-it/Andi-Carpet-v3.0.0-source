import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/expenses/expense_settlement_selection.dart';

class _Settlement {
  const _Settlement(this.id, {required this.closed});

  final String id;
  final bool closed;
}

String? resolve({
  required List<_Settlement> settlements,
  String? selected,
  bool hasLegacyData = false,
}) =>
    resolveExpenseSettlementId<_Settlement>(
      orderedSettlements: settlements,
      selectedSettlementId: selected,
      hasLegacyData: hasLegacyData,
      legacySettlementKey: '__legacy__',
      idOf: (settlement) => settlement.id,
      isClosed: (settlement) => settlement.closed,
    );

void main() {
  test('keeps an explicitly selected available settlement, including a closed one', () {
    final settlements = [
      _Settlement('open', closed: false),
      _Settlement('closed', closed: true),
    ];

    expect(resolve(settlements: settlements, selected: 'closed'), 'closed');
  });

  test('keeps the legacy selection only while legacy data exists', () {
    expect(
      resolve(settlements: const [], selected: '__legacy__', hasLegacyData: true),
      '__legacy__',
    );
    expect(
      resolve(
        settlements: const [_Settlement('open', closed: false)],
        selected: '__legacy__',
      ),
      'open',
    );
  });

  test('selects the first open settlement in the supplied display order', () {
    final settlements = [
      _Settlement('open-newest', closed: false),
      _Settlement('open-older', closed: false),
      _Settlement('closed', closed: true),
    ];

    expect(resolve(settlements: settlements, selected: 'removed'), 'open-newest');
  });

  test('falls back to the first settlement when all are closed', () {
    expect(
      resolve(
        settlements: const [
          _Settlement('closed-newest', closed: true),
          _Settlement('closed-older', closed: true),
        ],
        selected: 'removed',
      ),
      'closed-newest',
    );
  });

  test('falls back to legacy data when no settlement exists', () {
    expect(resolve(settlements: const [], hasLegacyData: true), '__legacy__');
    expect(resolve(settlements: const []), isNull);
  });

  test('preserves the existing sentinel collision behavior for an available ID', () {
    expect(
      resolve(
        settlements: const [_Settlement('__legacy__', closed: true)],
        selected: '__legacy__',
      ),
      '__legacy__',
    );
  });

  test('does not mutate the ordered settlement list', () {
    final settlements = [
      _Settlement('closed', closed: true),
      _Settlement('open', closed: false),
    ];
    final before = List<_Settlement>.of(settlements);

    expect(resolve(settlements: settlements), 'open');
    expect(settlements, orderedEquals(before));
  });
}
