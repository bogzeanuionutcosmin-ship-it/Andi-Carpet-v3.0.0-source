import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'support/home_sync_fixture.dart';
void main(){
 for(final legacy in [false,true]){
  dynamic model({List<ReceivedMoneyEntry>? entries,double openingDeparture=0,double openingDuring=0,int? revision}) => legacy ?
   TeamFinance(teamId:'team',receivedDeparture:25,receivedDuring:10,receivedEntries:entries,receivedOpeningDeparture:openingDeparture,receivedOpeningDuring:openingDuring,revision:revision,lastOperationId:revision==null?null:'a'*32) :
   TravelSettlement(id:'trip',teamId:'team',name:'Synthetic',startDate:DateTime.utc(2026),receivedDeparture:25,receivedDuring:10,receivedEntries:entries,receivedOpeningDeparture:openingDeparture,receivedOpeningDuring:openingDuring,revision:revision,lastOperationId:revision==null?null:'a'*32);
  final receipt=ReceivedMoneyEntry(id:'a'*32,kind:'departure',amount:200,method:'Cash',fromName:'Synthetic',date:DateTime.utc(2026));
  test('legacy aggregate-only history unchanged $legacy',(){final m=model();expect(m.departureTotal,25);expect(m.duringTotal,10);expect(m.totalReceived,35);expect(m.revision,isNull);});
  test('legacy itemised history unchanged without opening fields $legacy',(){final m=model(entries:[receipt]);expect(m.departureTotal,200);expect(m.duringTotal,0);});
  test('explicit legacy openings remain visible alongside a new receipt $legacy',(){final m=model(entries:[receipt],openingDeparture:25,openingDuring:10,revision:1);expect(m.departureTotal,225);expect(m.duringTotal,10);expect(m.totalReceived,235);expect(m.receivedEntries,hasLength(1));expect(m.revision,1);expect(m.lastOperationId,'a'*32);});
  test('zero openings do not alter new settlement totals $legacy',(){final m=model(entries:[receipt],revision:1);expect(m.totalReceived,200);});
 }
 for(final protocol in [false,true]){
  testWidgets('real Home codecs retain history and revision protocol=$protocol',(tester)async{
   final db=HomeSyncFixture();addTearDown(db.close);
   await tester.pumpWidget(MaterialApp(home:FixtureHomePage(key:const ValueKey('a'),profile:fixtureHomeProfile('a'),fixture:db)));
   db.emit('teams','t',{'members':['a'],'name':'Synthetic'});await flushHomeFixture(tester);
   final data=<String,dynamic>{'teamId':'t','name':'Trip','startDate':Timestamp.fromDate(DateTime.utc(2026)),
    'receivedDeparture':225.0,'receivedDuring':10.0,'receivedEntries':[{'id':'a'*32,'kind':'departure','amount':200.0,'method':'Cash','fromName':'Synthetic','date':Timestamp.fromDate(DateTime.utc(2026))}],
    if(protocol)...{'receivedOpeningDeparture':25.0,'receivedOpeningDuring':10.0,'revision':1,'lastOperationId':'a'*32}};
   db.emit('finance[where:teamId=t]','t',data);db.emit('settlements[where:teamId=t]','trip',data);await flushHomeFixture(tester);
   final dynamic state=tester.state(find.byType(FixtureHomePage));
   for(final dynamic model in [state.finances.single,state.settlements.single]){
    expect(model.totalReceived,protocol?235:200);expect(model.revision,protocol?1:null);
    expect(model.lastOperationId,protocol?'a'*32:null);expect(model.receivedEntries,hasLength(1));
   }
   await tester.pumpWidget(const SizedBox());expect(db.activeCount,0);expect(tester.takeException(),isNull);
  });
 }

}
