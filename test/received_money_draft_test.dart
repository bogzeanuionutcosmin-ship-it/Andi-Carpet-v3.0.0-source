import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/finance/received_money_draft.dart';
void main(){
  final entry=ReceivedMoneyEntry(id:'one',kind:'departure',amount:12.34,method:'Cash',fromName:'Source',date:DateTime(2026,10,21));
  test('rejected settlement save preserves balance, history and timestamps',()async{
    final original=TravelSettlement(id:'s',teamId:'t',name:'Trip',startDate:DateTime(2026),managerId:'manager');
    await expectLater(saveReceivedMoneyDraft(entry:entry,settlement:original,
      saveSettlement:(draft)async{expect(identical(draft,original),false);expect(draft.totalReceived,12.34);throw StateError('denied');},
      saveFinance:(_)async{fail('wrong target');}),throwsA(isA<StateError>()));
    expect(original.receivedEntries,isEmpty);expect(original.totalReceived,0);expect(original.closed,false);expect(original.endDate,isNull);
  });
  test('rejected legacy-finance save preserves baseline and explicit retry adds once',()async{
    final original=TeamFinance(teamId:'t',managerId:'manager');
    var calls=0;
    Future<void> save(TeamFinance draft)async{calls++;expect(identical(draft.receivedEntries,original.receivedEntries),false);if(calls==1)throw StateError('denied');}
    Future<void> attempt()=>saveReceivedMoneyDraft(entry:entry,finance:original,saveFinance:save,saveSettlement:(_)async{fail('wrong target');});
    await expectLater(attempt(),throwsA(isA<StateError>()));expect(original.receivedEntries,isEmpty);
    await attempt();expect(original.receivedEntries.single.id,'one');expect(original.totalReceived,12.34);
  });
  test('non-finite and fractional-ban amounts cannot reach persistence',()async{
    for(final value in [double.nan,double.infinity,double.negativeInfinity,-1,0,1.001]){
      final invalid=ReceivedMoneyEntry(id:'bad',kind:'departure',amount:value,method:'Cash',fromName:'Source',date:DateTime(2026));
      await expectLater(saveReceivedMoneyDraft(entry:invalid,finance:TeamFinance(teamId:'t'),
        saveFinance:(_)async{fail('invalid write');},saveSettlement:(_)async{fail('invalid write');}),throwsArgumentError);
    }
  });
  test('undated legacy totals cannot disappear when first history entry is added',()async{
    final original=TeamFinance(teamId:'t',receivedDeparture:200);
    await expectLater(saveReceivedMoneyDraft(entry:entry,finance:original,
      saveFinance:(_)async{fail('legacy totals would be erased');},saveSettlement:(_)async{fail('wrong target');}),throwsA(isA<StateError>()));
    expect(original.receivedDeparture,200);expect(original.receivedEntries,isEmpty);
  });

}
