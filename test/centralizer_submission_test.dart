import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

void main() {
  testWidgets('repeated manual-add taps open one dialog and cancellation permits retry', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CentralizerPage(
      currentUser:AppUser(id:'admin',name:'Admin',role:UserRole.director),
      teams:[Team(id:'craiova',name:'Craiova',members:['admin'])],
      locations:[Location(id:'one',name:'Sala',address:'Craiova',type:LocationType.magic)],
      categories:[],schedules:[],records:[],isAdmin:true,canEditTeam:(_)=>true,
      canEditCentralizer:true,onChanged:(){},log:(_,__) {},
      saveRecord:(_) async {},correctRecord:(_,__) async {},
    ))));
    final add=find.text('Adaugă execuție');
    await tester.tap(add);
    await tester.tap(add, warnIfMissed:false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsOneWidget);
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsNothing);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsOneWidget);
  });
  testWidgets('execution remains visible from its snapshot after registry deletion', (tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CentralizerPage(
      currentUser:AppUser(id:'admin',name:'Admin',role:UserRole.director),
      teams:[Team(id:'craiova',name:'Craiova',members:['admin'])],
      locations:[],categories:[],schedules:[],records:[CentralizerRecord(
        id:'retained',teamId:'craiova',locationId:'removed',type:LocationType.magic,
        locationNameSnapshot:'Sala arhivată',addressSnapshot:'Craiova',
        startedAt:DateTime(2026,10,16,10),finishedAt:DateTime(2026,10,16,11),
        status:WorkAttemptStatus.completed,
      )],isAdmin:true,canEditTeam:(_)=>true,canEditCentralizer:true,
      onChanged:(){},log:(_,__) {},saveRecord:(_) async {fail('display must not write');},
      correctRecord:(_,__) async {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Sala arhivată'),findsOneWidget);
    expect(find.byTooltip('Adaugă încă o execuție'),findsNothing);
  });

}
