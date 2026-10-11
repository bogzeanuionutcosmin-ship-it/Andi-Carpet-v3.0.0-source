import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  group('Exact money parsing for per diems', () {
    test('accepts whole lei, decimal commas and one or two bani digits', () {
      expect(app.parsePerDiemBani('50'), 5000);
      expect(app.parsePerDiemBani('50,5'), 5050);
      expect(app.parsePerDiemBani('50.05'), 5005);
      expect(app.parsePerDiemBani(' 0,01 '), 1);
      expect(app.parsePerDiemBani('0'), 0);
      expect(app.parsePerDiemBani('0', allowZero: false), isNull);
    });

    test('rejects extra decimals, negative values and malformed inputs', () {
      for (final value in ['12.345', '-1', '1e3', 'abc', '', '12,3,4', '1 000']) {
        expect(app.parsePerDiemBani(value), isNull, reason: value);
      }
    });

    test('enforces maximum value without silently rounding', () {
      expect(app.parsePerDiemBani('100000000'), 10000000000);
      expect(app.parsePerDiemBani('100000001'), isNull);
      expect(app.parsePerDiemBani('999999999'), isNull);
    });
  });

  group('Finance ledger totals', () {
    test('legacy totals are preserved when no detailed entries exist', () {
      final finance = app.TeamFinance(
        teamId: 'team', receivedDeparture: 100, receivedDuring: 25,
      );
      expect(finance.departureTotal, 100);
      expect(finance.duringTotal, 25);
      expect(finance.totalReceived, 125);
    });

    test('detailed entries take precedence over legacy totals', () {
      final entries = [
        app.ReceivedMoneyEntry(id: 'a', kind: 'departure', amount: 70, method: 'Cash', fromName: 'A', date: DateTime(2026)),
        app.ReceivedMoneyEntry(id: 'b', kind: 'during', amount: 35.50, method: 'Transfer', fromName: 'B', date: DateTime(2026)),
        app.ReceivedMoneyEntry(id: 'c', kind: 'departure', amount: 30, method: 'Cash', fromName: 'C', date: DateTime(2026)),
      ];
      final finance = app.TeamFinance(
        teamId: 'team', receivedDeparture: 999, receivedDuring: 999,
        receivedEntries: entries,
      );
      expect(finance.departureTotal, 100);
      expect(finance.duringTotal, 35.50);
      expect(finance.totalReceived, 135.50);
    });

    test('settlement uses the same ledger aggregation', () {
      final settlement = app.TravelSettlement(
        id: 'trip', teamId: 'team', name: 'Night shift',
        startDate: DateTime(2026, 10, 11),
        receivedDeparture: 100,
        receivedDuring: 50,
        receivedEntries: [
          app.ReceivedMoneyEntry(id: 'x', kind: 'during', amount: 20, method: 'Cash', fromName: 'A', date: DateTime(2026)),
        ],
      );
      expect(settlement.departureTotal, 0);
      expect(settlement.duringTotal, 20);
      expect(settlement.totalReceived, 20);
    });
  });
}
