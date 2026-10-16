import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/finance/intents/finance_checked_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_journal.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'finance_intent_device_storage_test.dart' show DeviceFixture, request, database;

// Separate-process schedule MODEL: two independent RMW clients, real checked
// envelope and real readback. Deliberately no shared in-isolate _queues. This
// is neither a two-tab plugin test nor an Android/OS durability certificate.
String manifest(List<FinanceIntent> rows)=>jsonEncode({'version':1,'ownerUid':'A','intents':rows.map((i)=>i.encode()).toList()});
void main(){
 test('XI checked readbacks both succeed while stale independent RMW loses an uncertain intent',()async{
  final device=DeviceFixture();
  FinanceCheckedJournalStorage client()=>FinanceCheckedJournalStorage.singleWriterCandidate(
   storage:device,ownerUid:'A',sessionIsCurrent:()=>true);
  final a=client(),b=client();const key='finance_intents_v1_A';
  final oldA=await a.read(key),oldB=await b.read(key);expect(oldA,isNull);expect(oldB,isNull);
  final first=request(1),second=request(2,target:'other');
  await a.write(key,manifest([first])); // A readback succeeded.
  final db=database()..commitThenThrow=true;
  final result=await FinanceRepository(port:db,ownerUid:'A',sessionIsCurrent:()=>true).execute(first);
  expect(result.status,FinanceIntentStatus.uncertain);
  await b.write(key,manifest([second])); // B also readback succeeded, using its stale empty read.
  final recovered=FinanceIntentJournal(storage:client(),ownerUid:'A',sessionIsCurrent:()=>true);
  expect((await recovered.pending()).single.operationId,second.operationId);
  expect((await recovered.pending()).any((i)=>i.operationId==first.operationId),false);
  expect(db.documents[first.markerPath],isNotNull,reason:'Lost local intent may already have committed');
  expect(device.writes,2);expect(db.calls,1);expect(db.writes,2);
  expect(jsonDecode(device.values[key]!)['format'],FinanceCheckedJournalStorage.format);
  a.dispose();b.dispose();
 });
}
