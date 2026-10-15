import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/firestore_finance_port.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  FinanceIntent edit(Map<String,Object?> changes) => FinanceIntent(
    operationId:'d'*32, actorUid:'actor', teamId:'team', collection:'settlements',
    documentId:'trip', baseRevision:0, kind:FinanceIntentKind.edit, changes:changes);
  test('historical timestamp nanos survive a financial edit and nested receipt rewrite', () {
    final historical = Timestamp(1790812800, 123456789);
    final previous = decodeFinanceFirestoreDocument({
      'teamId':'team','name':'Original','startDate':historical,
      'receivedEntries':[{'date':historical,'amount':25}],
    })!;
    final next = applyFinanceIntent(edit({'name':'Updated'}), previous);
    final encoded = encodeFinanceFirestoreDocument('settlements/trip',next);
    expect(encoded['startDate'],historical);
    expect(((encoded['receivedEntries'] as List).single as Map)['date'],historical);
    expect(next['name'],'Updated');
  });
}
