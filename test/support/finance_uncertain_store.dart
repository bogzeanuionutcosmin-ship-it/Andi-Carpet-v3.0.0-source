import 'dart:async';
import 'package:andi_carpeta/main.dart';

// Synthetic persistence boundary, NOT a Firestore emulator or replacement SDK.
// Capture at invocation, independently of later mutations of the shared model.
// Only the financial fields under observation are projected; no codec is copied.
Map<String, Object?> financeEvidence(dynamic value) => {
  'departure': value.departureTotal,
  'during': value.duringTotal,
  'entries': [for (final ReceivedMoneyEntry e in value.receivedEntries)
    {'id': e.id, 'kind': e.kind, 'amount': e.amount,
     'method': e.method, 'from': e.fromName, 'date': e.date}],
  if (value is TravelSettlement) ...{
    'name': value.name, 'closed': value.closed, 'end': value.endDate,
  },
};

class PendingFinanceWrite {
  final Map<String, Object?> payload;
  final String documentKey;
  final done = Completer<void>();
  PendingFinanceWrite(dynamic value) : payload = financeEvidence(value),
      documentKey = value is TravelSettlement ? 'settlements/${value.id}' : 'finance/${value.teamId}';
}

class FinanceUncertainStore {
  final writes = <PendingFinanceWrite>[];
  Map<String, Object?>? durable;
  Future<void> save(dynamic value) {
    final write = PendingFinanceWrite(value);
    writes.add(write);
    return write.done.future;
  }
  // Commit and acknowledgement are deliberately separate controls. An injected
  // timeout represents an ambiguous application boundary, not a claim that
  // Firestore.set itself times out offline in the installed SDK version.
  void commit(int index) => durable = writes[index].payload;
  void acknowledge(int index, {Object? error}) {
    if (error == null) {
      writes[index].done.complete();
    } else {
      writes[index].done.completeError(error);
    }
  }
}
