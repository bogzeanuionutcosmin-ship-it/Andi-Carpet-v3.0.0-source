import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

void main() {
  for(final save in [true,false]) {
    testWidgets('manual execution dialog ${save ? "saves" : "cancels"} safely during closing animation', (tester) async {
      final original=CentralizerRecord(id:'existing',teamId:'craiova',locationId:'room',
        type:LocationType.magic,locationNameSnapshot:'Sala test',addressSnapshot:'Craiova',
        startedAt:DateTime(2001,1,1,10),finishedAt:DateTime(2001,1,1,11),status:WorkAttemptStatus.completed);
      CentralizerRecord? added;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:CentralizerPage(
        currentUser:AppUser(id:'admin',name:'Admin',role:UserRole.director),
        teams:[Team(id:'craiova',name:'Craiova',members:['admin'])],
        locations:[],categories:[],schedules:[],records:[original],
        isAdmin:true,canEditTeam:(_)=>true,canEditCentralizer:true,
        onChanged:(){},log:(_,__) {},saveRecord:(record) async {added=record;},
        correctRecord:(_,__) async {fail('manual execution must not correct an existing record');},
      ))));
      await tester.pumpAndSettle();
      final add=find.byTooltip('Adaugă încă o execuție');
      await tester.ensureVisible(add);await tester.tap(add);await tester.pumpAndSettle();
      final fields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextField));
      expect(fields,findsNWidgets(3));
      await tester.enterText(fields.at(0),'09:15');
      await tester.enterText(fields.at(1),'10:45');
      await tester.enterText(fields.at(2),'intervenție manuală');
      final facade=find.descendant(of:find.byType(AlertDialog),matching:find.byType(SwitchListTile));
      await tester.ensureVisible(facade);await tester.tap(facade);await tester.pumpAndSettle();
      final action=find.text(save?'Adaugă':'Anulează');
      await tester.ensureVisible(action);await tester.tap(action);await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.byType(AlertDialog),findsNothing);
      if(save) {
        expect(added,isNotNull);expect(added!.id,isNot(original.id));
        expect(added!.teamId,'craiova');expect(added!.locationId,'room');
        expect(added!.duration,const Duration(minutes:90));
        expect(added!.refusalReason,'intervenție manuală');expect(added!.facadeDone,true);
      } else {
        expect(added,isNull);
      }
      expect(original.startedAt,DateTime(2001,1,1,10));
      expect(original.finishedAt,DateTime(2001,1,1,11));
    });
  }
}
