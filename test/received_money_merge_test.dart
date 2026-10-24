import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/received_money_merge.dart';

Map<String, dynamic> entry(String id, {String kind = 'during', double amount = 12.34,
    String from = 'Client'}) => {
  'id': id, 'kind': kind, 'amount': amount, 'method': 'Transfer', 'fromName': from,
  'date': DateTime.utc(2026, 10, 23),
};

Map<String, dynamic> doc(List<Map<String, dynamic>> entries) => {
  'receivedEntries': entries, 'receivedDeparture': 0.0, 'receivedDuring': 0.0,
  'updatedAt': 'server timestamp sentinel',
};

void main() {
  test('same-ID replay is idempotent and recomputes only one amount', () {
    final receipt = entry('receipt-a');
    final result = mergeReceivedMoneyDocument(incoming: doc([receipt]),
      current: doc([receipt]), exists: true);
    expect(result['receivedEntries'], hasLength(1));
    expect(result['receivedDuring'], 12.34);
  });

  test('same ID with a different payload fails closed', () {
    expect(() => mergeReceivedMoneyDocument(incoming: doc([entry('receipt-a', amount: 15)]),
      current: doc([entry('receipt-a')]), exists: true), throwsStateError);
  });

  test('stale client write preserves a server-only entry and its total', () {
    final local = entry('local');
    final remote = entry('remote', kind: 'departure', amount: 5);
    final result = mergeReceivedMoneyDocument(incoming: doc([local]),
      current: doc([local, remote]), exists: true);
    final entries = result['receivedEntries'] as List;
    expect(entries.map((item) => item['id']).toSet(), {'local', 'remote'});
    expect(result['receivedDeparture'], 5.0);
    expect(result['receivedDuring'], 12.34);
  });

  test('legacy aggregate totals cannot be mixed into a partial history', () {
    final legacy = {'receivedDeparture': 40.0, 'receivedDuring': 0.0};
    expect(() => mergeReceivedMoneyDocument(incoming: doc([entry('new')]),
      current: legacy, exists: true), throwsStateError);
  });
}
