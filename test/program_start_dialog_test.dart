import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  for(final keyboardInset in [0.0,290.0,360.0]){
    testWidgets('Program START remains usable with keyboard inset $keyboardInset',(tester) async {
      tester.view.physicalSize=const Size(411,731);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final saved=<app.WorkSchedule>[];
      final settings=app.AppSettings()..learning['program']!.enabled=false;
      final day=app.WorkSchedule(id:'day',teamId:'team',date:DateTime(2026,10,21),items:[
        app.ScheduleItem(locationId:'room',locationNameSnapshot:'Room',addressSnapshot:'Address',
          typeSnapshot:app.LocationType.magic,order:1),
      ]);
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.ProgramPage(
        currentUser:app.AppUser(id:'editor',name:'Editor',role:app.UserRole.member),
        teams:[app.Team(id:'team',name:'Team',members:['editor'])],
        cars:[],locations:[],categories:[],schedules:[day],records:[],settings:settings,
        canEditTeam:(_)=>true,canEditProgram:true,userName:(_)=>'Editor',
        onChanged:(){},notifyTeam:(_,__,___){},log:(_,__){},
        geocodeTripPoint:(query) async => {'lat':44.3,'lon':23.8},
        saveSchedules:(days) async {saved.addAll(days);},
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,
        reason:'The graph selector must fit the phone even with the default long graph name');
      final start=find.text('START GRAFIC');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      tester.view.viewInsets=FakeViewPadding(bottom:keyboardInset);
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,reason:'The endpoint dialog must fit above the keyboard');
      final fields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextFormField));
      expect(fields,findsNWidgets(2));
      await tester.ensureVisible(fields.first);
      await tester.enterText(fields.first,'Plecare test');
      await tester.ensureVisible(fields.last);
      await tester.enterText(fields.last,'Destinație test');
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      final confirm=find.text('START');
      expect(confirm.hitTestable(),findsOneWidget);
      await tester.tap(confirm);
      // Model the changing viewport during the dialog/keyboard close animation.
      for(final inset in [keyboardInset,keyboardInset*.5,0.0]){
        tester.view.viewInsets=FakeViewPadding(bottom:inset);
        await tester.pump(const Duration(milliseconds:80));
        expect(tester.takeException(),isNull,reason:'Closing START must not overflow during keyboard animation');
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsNothing);
      expect(saved,hasLength(1));
      expect(saved.single.started,true);
      expect(saved.single.departureName,'Plecare test');
      expect(saved.single.returnName,'Destinație test');
      expect(day.started,false,reason:'Persistence receives an isolated schedule snapshot');
    });
  }
}
