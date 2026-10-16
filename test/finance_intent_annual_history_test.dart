import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/expense_document_fixture.dart';
void main(){
 for(final legacy in [false,true]){
  for(final protocol in [false,true]){
   testWidgets('real annual/all-time opening history legacy=$legacy protocol=$protocol',(tester)async{
    final f=ExpenseDocumentFixture('')..legacyFinance=legacy;
    final entries=protocol?[ReceivedMoneyEntry(id:'a'*32,kind:'departure',amount:200,method:'Cash',fromName:'Synthetic',date:DateTime(legacy?DateTime.now().year:2027,10,15))]:<ReceivedMoneyEntry>[];
    f.financeOverride=TeamFinance(teamId:'team',managerId:f.user.id,receivedDeparture:25,receivedDuring:10,
     receivedEntries:legacy?entries:[],receivedOpeningDeparture:legacy&&protocol?25:0,receivedOpeningDuring:legacy&&protocol?10:0,revision:protocol?1:null);
    if(!legacy){f.settlementOverride=TravelSettlement(id:'settlement',teamId:'team',name:'Synthetic',startDate:DateTime(2026,10,1),managerId:f.user.id,receivedDeparture:25,receivedDuring:10,
      receivedEntries:entries,receivedOpeningDeparture:protocol?25:0,receivedOpeningDuring:protocol?10:0,revision:protocol?1:null);
     f.financeOverride=TeamFinance(teamId:'team',managerId:f.user.id);
    }
    await f.mount(tester);
    final button=find.text('Calcule generale');await tester.ensureVisible(button);await tester.tap(button);await tester.pumpAndSettle();
    void received(double expected){
     final label=find.descendant(of:find.byType(AlertDialog),matching:find.text('Total primit'));
     final row=find.ancestor(of:label,matching:find.byType(Row)).first;
     expect(find.descendant(of:row,matching:find.text('${expected.toStringAsFixed(2)} lei')),findsOneWidget);
    }
    received(legacy?(protocol?200:0):35);
    await tester.tap(find.text('Total general'));await tester.pumpAndSettle();received(protocol?235:35);
    expect(f.logs,isEmpty);expect(f.attempts,isEmpty);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
   });
  }
 }
}
