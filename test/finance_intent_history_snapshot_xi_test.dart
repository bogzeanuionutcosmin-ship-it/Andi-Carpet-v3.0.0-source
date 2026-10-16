import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/history/history_xi_snapshot.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'finance_intent_history_xi_test.dart' show xi,xiDb,repo;

void main(){
 test('XI snapshot prefix is complete at N but cannot authorize a stale restore after N+1',()async{
  final db=xiDb(),r=repo(db);
  for(var n=1;n<=25;n++){await r.executeExplicitly(xi(n,revision:n-1));}
  final path=xi(1).summaryPath;
  final original=await db.readServer(path);
  final review=HistoryXiSnapshotReview(xi(25,revision:24),original);
  final rows=[for(var n=25;n>=1;n--)db.documents[xi(n,revision:n-1).rowPath]!];
  review.addPage(rows.take(20).toList());
  expect(()=>review.sealExplicitly(),throwsA(isA<FinanceRefusal>()));
  await r.executeExplicitly(xi(26,revision:25)); // Concurrent writer while export pages are in flight.
  review.addPage(rows.skip(20).toList());
  final proof=review.sealExplicitly();expect(proof.receiptCount,25);
  expect(proof.matchesCurrent(original),true);
  expect(proof.matchesCurrent(await db.readServer(path)),false);
  expect(db.writes,52,reason:'Only the 26 receipt commits; snapshot review writes nothing');
  expect(proof.toString(),'HistoryXiPrefixProof');
 });
 test('XI partial/crashed snapshot cannot issue proof, and orphan rows poison the review',()async{
  final db=xiDb(),r=repo(db);await r.executeExplicitly(xi(1));await r.executeExplicitly(xi(2,revision:1));
  final summary=await db.readServer(xi(1).summaryPath);
  final first=HistoryXiSnapshotReview(xi(2,revision:1),summary);
  first.addPage([db.documents[xi(2,revision:1).rowPath]!]);
  expect(()=>first.sealExplicitly(),throwsA(isA<FinanceRefusal>()));
  final restarted=HistoryXiSnapshotReview(xi(2,revision:1),summary);
  expect(()=>restarted.addPage([db.documents[xi(1).rowPath]!]),throwsA(isA<FinanceRefusal>()));
  expect(()=>restarted.sealExplicitly(),throwsA(isA<FinanceRefusal>()));
  expect(db.writes,4);
 });
 test('XI proof refuses cached/pending snapshot and never treats matching cached data as current',()async{
  final db=xiDb(),r=repo(db);await r.executeExplicitly(xi(1));
  final data=db.documents[xi(1).summaryPath]!;
  for(final pending in [false,true]){
   expect(()=>HistoryXiSnapshotReview(xi(1),FinanceServerObservation(data,fromCache:!pending,pendingWrites:pending)),throwsA(isA<FinanceRefusal>()));
  }
  final review=HistoryXiSnapshotReview(xi(1),await db.readServer(xi(1).summaryPath));
  review.addPage([db.documents[xi(1).rowPath]!]);final proof=review.sealExplicitly();
  expect(proof.matchesCurrent(FinanceServerObservation(data,fromCache:true,pendingWrites:false)),false);
  expect(proof.matchesCurrent(FinanceServerObservation(data,fromCache:false,pendingWrites:true)),false);
 });
}
