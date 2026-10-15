import 'package:andi_carpeta/finance/intents/finance_intent.dart';
import 'package:flutter_test/flutter_test.dart';
FinanceIntent intent({String id='00000000000000000000000000000001', Map<String,Object?>? changes}) => FinanceIntent(
  operationId:id, actorUid:'PRIVATE_ACTOR', teamId:'team', collection:'settlements', documentId:'trip',
  baseRevision:0, kind:FinanceIntentKind.receipt, changes:changes??{'amount':200.0,'date':DateTime.utc(2026,10,15)});
void main(){
 test('durable round trip preserves identity revision dates and digest',(){final a=intent();final b=FinanceIntent.decode(a.encode());expect(b.encode(),a.encode());expect(b.digest,a.digest);expect(b.operationId,a.operationId);});
 test('request is deeply detached and immutable',(){final nested=<String,Object?>{'a':<Object?>[1]};final a=intent(changes:nested);(nested['a'] as List).add(2);expect(a.changes['a'],[1]);expect(()=> (a.changes['a'] as List).add(3),throwsUnsupportedError);});
 test('stable fingerprint ignores map insertion order',(){expect(intent(changes:{'a':1,'b':2}).digest,intent(changes:{'b':2,'a':1}).digest);});
 test('same money different legitimate intent is distinct',(){expect(intent().digest,isNot(intent(id:'00000000000000000000000000000002').digest));});
 test('changed request with reused ID has different fingerprint',(){expect(intent().digest,isNot(intent(changes:{'amount':201}).digest));});
 test('secure IDs are fixed-length and independent',(){final ids=List.generate(100,(_)=>FinanceIntent.newOperationId());expect(ids.toSet(),hasLength(100));expect(ids.every((id)=>RegExp(r'^[a-f0-9]{32}$').hasMatch(id)),true);});
 for(final value in [double.nan,double.infinity,double.negativeInfinity]){test('nonfinite $value cannot enter durable request',(){expect(()=>intent(changes:{'amount':value}),throwsFormatException);});}
 test('path injection rejected',(){expect(()=>FinanceIntent(operationId:'0'*32,actorUid:'a',teamId:'t',collection:'settlements',documentId:'x/y',baseRevision:0,kind:FinanceIntentKind.edit,changes:{}),throwsFormatException);});
 test('unsupported target rejected',(){expect(()=>FinanceIntent(operationId:'0'*32,actorUid:'a',teamId:'t',collection:'users',documentId:'x',baseRevision:0,kind:FinanceIntentKind.edit,changes:{}),throwsFormatException);});
 test('diagnostic interpolation excludes private binding and money',(){expect(intent().toString(),isNot(contains('PRIVATE')));expect(intent().toString(),isNot(contains('200')));});
 test('unknown durable version fails closed',(){expect(()=>FinanceIntent.decode(intent().encode().replaceFirst('"version":1','"version":2')),throwsFormatException);});
 test('storage cap does not discard or truncate an intent',(){expect(()=>intent(changes:{'name':'x'*17000}),throwsFormatException);});
 test('integral numeric encoding has a VM and Chrome golden representation',(){
  final decimal=intent(changes:{'amount':200.0,'fraction':0.25});
  final integer=intent(changes:{'amount':200,'fraction':0.25});
  expect(decimal.encode(),contains('"amount":200,'));
  expect(decimal.encode(),isNot(contains('200.0')));expect(decimal.digest,integer.digest);
  expect(decimal.changes['amount'],200.0);expect(FinanceIntent.decode(decimal.encode()).digest,decimal.digest);
 });
 test('a user map cannot masquerade as a persisted DateTime',(){
  expect(()=>intent(changes:{'date':{'@date':'2026-10-15T00:00:00.000Z'}}),throwsFormatException);
  expect(()=>intent(changes:{'nested':[{'@date':'invalid','extra':1}]}),throwsFormatException);
 });

}
