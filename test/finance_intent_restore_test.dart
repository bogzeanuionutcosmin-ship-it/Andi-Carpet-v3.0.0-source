import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:andi_carpeta/finance/intents/finance_repository.dart';
import 'package:andi_carpeta/finance/intents/finance_restore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/finance_atomic_fixture.dart';

class RestoreFixture implements FinanceRestorePort {
  final db=FinanceAtomicFixture();
  @override Future<void> atomic(Future<void> Function(FinanceRestoreTransaction) action) =>
    db.atomic((tx)=>action(_RestoreTx(tx)));
}
class _RestoreTx implements FinanceRestoreTransaction {
  final FinanceTransaction tx;
  _RestoreTx(this.tx);
  @override Future<Map<String,Object?>?> read(String path)=>tx.read(path);
  @override void write(String path,Map<String,Object?> data)=>tx.write(path,data);
}
// A port may lose its acknowledgement using a domain exception. The caller
// must not infer that no write happened from the exception type alone.
class _PostCommitFailure implements FinanceRestorePort {
  final RestoreFixture delegate;
  final Object error;
  _PostCommitFailure(this.delegate,this.error);
  @override Future<void> atomic(Future<void> Function(FinanceRestoreTransaction) action) async {
    await delegate.atomic(action);
    throw error;
  }
}
class _RetryRefusal implements FinanceRestorePort {
  final RestoreFixture delegate;
  _RetryRefusal(this.delegate);
  @override Future<void> atomic(Future<void> Function(FinanceRestoreTransaction) action) async {
    // First callback schedules a write but contention prevents commit. A later
    // callback refuses during preflight. No successful commit is asserted.
    var first=true;
    delegate.db.beforeCommit=()async {
      if(first) {
        first=false;
        delegate.db.seed('locations/room',{'name':'Concurrent'});
      }
    };
    await delegate.atomic(action);
  }
}
void main() {
  const target='settlements/trip', room='locations/room';
  final marker='$target/financialIntents/${'a'*32}';
  Map<String,Object?> finance()=>{'teamId':'team','revision':1,'lastOperationId':'a'*32,
    'startDate':FinanceTimestamp(1790812800,123456789),'receivedDeparture':200};
  Map<String,Object?> evidence()=>{'operationId':'a'*32,'digest':'b'*64,'revision':1,
    'baseRevision':0,'targetPath':target,'teamId':'team','actorUid':'manager','kind':'receipt'};
  RestoreFixture fixture() {
    final f=RestoreFixture();
    f.db.seed(target,finance());f.db.seed(marker,evidence());
    f.db.seed(room,{'name':'Current'});return f;
  }
  FinanceRestorePlan plan(RestoreFixture f)=>FinanceRestorePlan(expected:{
    target:f.db.documents[target],marker:f.db.documents[marker],room:f.db.documents[room],
  },replacements:{room:{'name':'Restored'}});
  test('archive roundtrip retains marker, revision, exact timestamps and detached immutable input',() {
    final f=fixture(),p=plan(f),restored=FinanceRestorePlan.decode(plan(f).encode());
    f.db.documents[target]!['receivedDeparture']=999;
    expect(restored.encode(),p.encode());
    expect((restored.expected[target] as Map)['receivedDeparture'],200);
    expect(()=>restored.expected.clear(),throwsUnsupportedError);
    expect((restored.expected[marker] as Map)['digest'],'b'*64);
  });
  test('all financial and operational reads precede one atomic targeted restore',()async {
    final f=fixture(),p=plan(f);final financialBefore=canonicalFinanceJson(f.db.documents[target]);
    final r=await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p);
    expect(r.status,FinanceIntentStatus.confirmed);expect(f.db.reads,3);expect(f.db.writes,1);
    expect(f.db.documents[room],{'name':'Restored'});
    expect(canonicalFinanceJson(f.db.documents[target]),financialBefore);
    expect(f.db.documents[marker],evidence());
  });
  test('stale financial target rejects entire restore before unrelated writes',()async {
    final f=fixture(),p=plan(f);f.db.seed(target,{...finance(),'revision':2});
    final r=await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p);
    expect(r.status,FinanceIntentStatus.conflict);expect(f.db.writes,0);expect(f.db.documents[room],{'name':'Current'});
  });
  test('mismatched marker late in manifest cannot cause partial restoration',()async {
    final f=fixture(),p=plan(f);f.db.seed(marker,{'digest':'c'*64,'revision':1});
    expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p)).status,FinanceIntentStatus.conflict);
    expect(f.db.writes,0);expect(f.db.documents[room],{'name':'Current'});
  });
  test('concurrent financial receipt between preflight and commit aborts without rebase',()async {
    final f=fixture(),p=plan(f);var once=true;
    f.db.beforeCommit=()async{if(once){once=false;f.db.seed(target,{...finance(),'revision':2,'receivedDeparture':400});}};
    // The earlier callback already scheduled a write: the public result must
    // remain conservative even though this fixture proves no commit happened.
    expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p)).status,FinanceIntentStatus.uncertain);
    expect(f.db.calls,1);expect(f.db.callbacks,2);
    expect(f.db.writes,0);expect(f.db.documents[room],{'name':'Current'});expect(f.db.documents[target]!['receivedDeparture'],400);
  });
  test('changed operational document also rejects the global plan',()async {
    final f=fixture(),p=plan(f);f.db.seed(room,{'name':'New edit'});
    expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p)).status,FinanceIntentStatus.conflict);
    expect(f.db.writes,0);
  });
  test('write failure and lost acknowledgement do not trigger another application attempt',()async {
    for(final committed in [false,true]) {
      final f=fixture(),p=plan(f);f.db.failBeforeCommit=!committed;f.db.commitThenThrow=committed;
      expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p)).status,FinanceIntentStatus.uncertain);
      expect(f.db.calls,1);expect(f.db.documents[room],{'name':committed?'Restored':'Current'});
    }
  });
  test('typed exceptions after commit cannot certify rejection or conflict',()async {
    for(final error in <Object>[
      const FinanceRefusal('synthetic_lost_ack'),const FinanceRevisionConflict(),
    ]) {
      final f=fixture(),p=plan(f);
      final result=await FinanceDemoRestore(port:_PostCommitFailure(f,error),
        sessionIsCurrent:()=>true).executeExplicitly(p);
      expect(result.status,FinanceIntentStatus.uncertain);
      expect(result.code,'finance_restore_uncertain');
      expect(f.db.calls,1);expect(f.db.writes,1);
      expect(f.db.documents[room],{'name':'Restored'});
    }
  });
  test('scheduled writes remain ambiguous across callback retry refusal',()async {
    final f=fixture(),p=plan(f);
    final result=await FinanceDemoRestore(port:_RetryRefusal(f),
      sessionIsCurrent:()=>true).executeExplicitly(p);
    expect(result.status,FinanceIntentStatus.uncertain);
    expect(f.db.calls,1);expect(f.db.callbacks,2);expect(f.db.writes,0);
    expect(f.db.documents[room],{'name':'Concurrent'});
  });
  test('revoked session after a read schedules no write',()async {
    final f=fixture(),p=plan(f);var current=true;
    f.db.beforeRead=(_)async{current=false;};
    expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>current).executeExplicitly(p)).status,FinanceIntentStatus.rejectedBeforeWrite);
    expect(f.db.writes,0);
  });
  test('session revoked after commit cannot certify no-write or success to new owner',()async {
    final f=fixture(),p=plan(f);var current=true;f.db.beforeCommit=()async{current=false;};
    expect((await FinanceDemoRestore(port:f,sessionIsCurrent:()=>current).executeExplicitly(p)).status,FinanceIntentStatus.uncertain);
    expect(f.db.writes,1);
  });
  test('financial replacements, deletes, unknown collections and V1 backups fail closed',() {
    for(final path in [target,marker,'expenses/e','teams/team','users/admin','locations/x/y']) {
      expect(()=>FinanceRestorePlan(expected:{target:finance(),path:{}},replacements:{path:{}}),throwsA(isA<FinanceRefusal>()));
    }
    expect(()=>FinanceRestorePlan(expected:{target:finance(),room:{}},replacements:{room:null}),throwsA(isA<FinanceRefusal>()));
    expect(()=>FinanceRestorePlan.decode('{"format":"AndiCarpetaBackupV1","collections":{}}'),throwsA(isA<FinanceRefusal>()));
  });
  test('oversize plans fail before any port can be invoked',() {
    expect(()=>FinanceRestorePlan(expected:{target:finance(),for(var n=0;n<21;n++) 'locations/$n':{}},replacements:{'locations/0':{}}),
      throwsA(isA<FinanceRefusal>().having((e)=>e.code,'code','finance_restore_invalid_manifest')));
    final f=fixture();
    expect(()=>FinanceRestorePlan(expected:plan(f).expected,replacements:{room:{'name':'x'*(256*1024)}}),
      throwsA(isA<FinanceRefusal>().having((e)=>e.code,'code','finance_restore_capacity')));
  });
  test('restore refuses malformed or cross-bound immutable evidence before opening a transaction',(){
    for(final change in <Map<String,Object?>>[
      {'targetPath':'settlements/other'},{'teamId':'other'},{'actorUid':''},{'actorUid':'a/b'},
      {'operationId':'c'*32},{'baseRevision':1},{'baseRevision':0.5},{'revision':0},{'digest':'bad'},
      {'kind':'unknown'},{'unexpected':'field'},
    ]) {
      final f=fixture();
      expect(()=>FinanceRestorePlan(expected:{target:finance(),marker:{...evidence(),...change},room:{}},
        replacements:{room:{}}),throwsA(isA<FinanceRefusal>()));
      expect(f.db.calls,0);
    }
  });
  test('restore refuses inconsistent legacy and out-of-range revision bindings',(){
    for(final change in <Map<String,Object?>>[
      {'teamId':''},{'teamId':'a/b'},{'revision':9007199254740992},
      {'revision':0,'lastOperationId':'a'*32},
    ]) {
      expect(()=>FinanceRestorePlan(expected:{target:{...finance(),...change},marker:evidence(),room:{}},
        replacements:{room:{}}),throwsA(isA<FinanceRefusal>()));
    }
  });
  test('valid historical and latest evidence stay immutable across targeted restore',()async{
    final f=fixture(),latest='$target/financialIntents/${'c'*32}';
    f.db.seed(target,{...finance(),'revision':2,'lastOperationId':'c'*32});
    f.db.seed(latest,{...evidence(),'operationId':'c'*32,'revision':2,'baseRevision':1,'kind':'edit'});
    final expected=<String,Object?>{target:f.db.documents[target],marker:f.db.documents[marker],
      latest:f.db.documents[latest],room:f.db.documents[room]};
    final p=FinanceRestorePlan(expected:expected,replacements:{room:{'name':'Restored'}});
    final r=await FinanceDemoRestore(port:f,sessionIsCurrent:()=>true).executeExplicitly(p);
    expect(r.status,FinanceIntentStatus.confirmed);expect(f.db.reads,4);expect(f.db.writes,1);
    for(final path in [target,marker,latest])expect(sameFinanceValue(f.db.documents[path],p.expected[path]),true);
  });
  test('missing latest marker or orphan evidence is rejected before SDK access',() {
    expect(()=>FinanceRestorePlan(expected:{target:finance(),room:{}},replacements:{room:{}}),throwsA(isA<FinanceRefusal>()));
    expect(()=>FinanceRestorePlan(expected:{marker:{'revision':1},room:{}},replacements:{room:{}}),throwsA(isA<FinanceRefusal>()));
  });
}
