import 'package:andi_carpeta/finance/intents/finance_capacity.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/finance_atomic_fixture.dart';

void main() {
  test('official Firestore storage example has 147 bytes including path and footer',() {
    expect(estimateFinanceDocumentBytes('users/jeff/tasks/my_task_id',{
      'type':'Personal','done':false,'priority':1,'description':'Learn Cloud Firestore',
    }),147);
  });
  test('UTF8 field names values and nested maps are counted beyond JSON length',() {
    expect(estimateFinanceDocumentBytes('n/x',{'a':'a'}),56);
    expect(estimateFinanceDocumentBytes('n/x',{'é':'€'}),59);
    expect(estimateFinanceDocumentBytes('n/x',{'a':{'b':1}}),96);
    expect(estimateFinanceDocumentBytes('n/x',{'a':[1,2]}),70);
  });
  test('both timestamp representations count as eight bytes and server update is included',() {
    expect(estimateFinanceDocumentBytes('n/x',{'a':DateTime.utc(2026)}),62);
    expect(estimateFinanceDocumentBytes('n/x',{'a':FinanceTimestamp(1,1)}),62);
    expect(estimateFinanceDocumentBytes('n/x',{},includesServerUpdate:true),70);
  });
  test('receipt crossing a full legacy document is refused before any financial write',()async {
    final request=FinanceIntent(operationId:'1'*32,actorUid:'a',teamId:'team',
      collection:'settlements',documentId:'trip',baseRevision:0,kind:FinanceIntentKind.receipt,
      changes:{'kind':'departure','amount':200,'method':'Cash','fromName':'Synthetic','date':DateTime.utc(2026,10,15)});
    final previous=<String,Object?>{'teamId':'team','closed':false,'receivedDeparture':0,
      'receivedDuring':0,'receivedEntries':<Object?>[],'padding':''};
    final small=applyFinanceIntent(request,previous);
    final required=financeDocumentLimitBytes-estimateFinanceDocumentBytes(request.targetPath,small,includesServerUpdate:true)+1;
    previous['padding']='x'*required;
    expect(estimateFinanceDocumentBytes(request.targetPath,previous,includesServerUpdate:true),lessThan(financeDocumentLimitBytes));
    final db=FinanceAtomicFixture()..seed(request.targetPath,previous);
    final result=await FinanceRepository(port:db,ownerUid:'a',sessionIsCurrent:()=>true).execute(request);
    expect(result.status,FinanceIntentStatus.rejectedBeforeWrite);
    expect(result.code,'finance_document_capacity_requires_review');
    expect(db.writes,0);expect(db.documents[request.markerPath],isNull);
    expect(db.documents[request.targetPath]!['receivedEntries'],isEmpty);
  });
}
