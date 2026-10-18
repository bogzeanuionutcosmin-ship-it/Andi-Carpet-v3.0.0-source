import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/history/history_xi.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/session_xiii/session_fence_xiii.dart';
import 'finance_intent_history_xi_test.dart' show xi, xiDb;

FinanceSessionXiiiBinding binding([int epoch=1]) => FinanceSessionXiiiBinding(ownerUid:'a',teamId:'team',epoch:epoch);
Map<String,Object?> fence([int epoch=1]) => {...binding(epoch).toMap(),'enabled':true};
void main() {
 test('XIII model frozen session envelope roundtrip retains XI bytes and refuses silent V1/XI upgrade', () {
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final restored=FinanceSessionXiiiIntent.decode(i.encode());
  expect(restored.encode(),i.encode()); expect(restored.history.digest,i.history.digest);
  expect(()=>FinanceSessionXiiiIntent.decode(i.history.encode()),throwsFormatException);
  expect(()=>FinanceSessionXiiiIntent(history:xi(1,team:'other'),binding:binding()),throwsFormatException);
  for(final epoch in [0,9007199254740992]) { expect(()=>binding(epoch),throwsFormatException); }
 });
 test('XIII model fence, exact receipt pair and immutable permit share one transaction', () async {
  final db=xiDb()..seed(binding().fencePath,fence());
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>true);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.confirmed);
  expect(db.writes,3); expect(db.documents[i.permitPath],i.permit());
  expect((await r.executeExplicitly(i.history)).replayed,true);expect(db.writes,3);
 });
 test('XIII model authoritative epoch change between read and commit retries then refuses old generation', () async {
  final db=xiDb()..seed(binding().fencePath,fence());
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());var changed=false;
  db.beforeCommit=()async {if(!changed){changed=true;db.seed(binding().fencePath,fence(2));}};
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>true);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  expect(db.writes,0);expect(db.documents[i.history.rowPath],isNull);
 });
 test('XIII model lost ACK then epoch advancement reconciles same immutable permit without new write', () async {
  final db=xiDb()..seed(binding().fencePath,fence())..commitThenThrow=true;
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>true);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  db.seed(binding().fencePath,fence(2));
  expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.confirmed);
  expect(db.calls,1);expect(db.writes,3);expect(db.serverReads,4);
 });
 test('XIII model delayed callback after logout cannot revive when bool returns true again', () async {
  final db=xiDb()..seed(binding().fencePath,fence());var current=true;
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>current);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  db.beforeRead=(path)async { if(path==i.permitPath)current=false; };
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.rejectedBeforeWrite);
  current=true;db.beforeRead=null;
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.rejectedBeforeWrite);
  expect(db.writes,0);
 });
 test('XIII model rejects missing/corrupt/cache permit even if money and XI marker match', () async {
  final db=xiDb()..seed(binding().fencePath,fence());
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>true);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  await r.executeExplicitly(i.history);db.documents.remove(i.permitPath);
  expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  db.seed(i.permitPath,{...i.permit(),'epoch':2});
  expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  db.seed(i.permitPath,i.permit());db.fromCache=true;
  expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  db.fromCache=false;db.pending=true;
  expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  expect(db.writes,3);
 });
 test('XIII model commit before local logout remains accepted; old callback uncertain and new authorized review succeeds', () async {
  final db=xiDb()..seed(binding().fencePath,fence());var current=true;
  final i=FinanceSessionXiiiIntent(history:xi(1),binding:binding());
  final p=FinanceSessionXiiiPort(inner:db,intent:i,sessionIsCurrent:()=>current);
  final r=FinanceHistoryXiRepository(port:p,ownerUid:'a',sessionIsCurrent:()=>true);
  db.beforeCommit=()async { current=false; };
  expect((await r.executeExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  expect(db.documents[i.history.rowPath],i.history.row());expect(db.writes,3);
  current=true;expect((await r.reconcileExplicitly(i.history)).status,FinanceIntentStatus.uncertain);
  final fresh=FinanceSessionXiiiPort(inner:db,intent:FinanceSessionXiiiIntent.decode(i.encode()),sessionIsCurrent:()=>true);
  final review=FinanceHistoryXiRepository(port:fresh,ownerUid:'a',sessionIsCurrent:()=>true);
  expect((await review.reconcileExplicitly(i.history)).status,FinanceIntentStatus.confirmed);
  expect(db.calls,1);expect(db.writes,3);
 });
}
