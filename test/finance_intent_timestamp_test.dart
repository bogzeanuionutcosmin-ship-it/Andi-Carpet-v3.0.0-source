import 'dart:convert';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinanceIntent edit(Map<String,Object?> changes) => FinanceIntent(
    operationId:'d'*32, actorUid:'actor', teamId:'team', collection:'settlements',
    documentId:'trip', baseRevision:0, kind:FinanceIntentKind.edit, changes:changes);

  test('microsecond timestamps retain the existing DateTime representation', () {
    final date = DateTime.utc(2026,10,15,12,0,0,1,234);
    expect(decodeFinanceFirestoreDocument({'date':Timestamp.fromDate(date)})!['date'],date);
  });
  test('durable request with an exact timestamp retains its digest after restart', () {
    final request = edit({'startDate':FinanceTimestamp(-1,999999999)});
    final restarted = FinanceIntent.decode(request.encode());
    expect(restarted.digest,request.digest);
    final encoded = encodeFinanceFirestoreDocument('settlements/trip',restarted.changes);
    expect(encoded['startDate'],Timestamp(-1,999999999));
  });
  test('exact timestamp canonical order and one-nanosecond difference remain distinguishable', () {
    expect(sameFinanceValue(FinanceTimestamp(1,1),FinanceTimestamp(1,1)),true);
    expect(sameFinanceValue(FinanceTimestamp(1,1),FinanceTimestamp(1,2)),false);
    expect(sameFinanceValue(FinanceTimestamp(1,1),DateTime.fromMillisecondsSinceEpoch(1000,isUtc:true)),false);
  });
  test('untrusted user maps cannot imitate the reserved timestamp tag', () {
    expect(()=>edit({'startDate':{'@timestamp':[1,2]}}),throwsFormatException);
    expect(()=>edit({'nested':[{'@timestamp':[1,2],'extra':true}]}),throwsFormatException);
  });
  test('malformed persisted timestamps fail closed', () {
    for(final parts in [[1], [1,2,3], [1,0.5], [1,-1], [1,1000000000], [253402300800,0]]) {
      final encoded = jsonDecode(edit({'name':'test'}).encode()) as Map<String,dynamic>;
      encoded['changes']={'startDate':{'@timestamp':parts}};
      expect(()=>FinanceIntent.decode(jsonEncode(encoded)),throwsFormatException);
    }
  });
}
