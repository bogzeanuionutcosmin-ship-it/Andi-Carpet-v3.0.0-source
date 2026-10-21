import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  app.CentralizerRecord record(String id, int day, int hour,
    app.WorkAttemptStatus status, {String teamId = 'team'}) => app.CentralizerRecord(
      id:id,teamId:teamId,locationId:'room',type:app.LocationType.magic,
      locationNameSnapshot:'Room',addressSnapshot:'Address',
      startedAt:DateTime(2026,10,day,hour),
      finishedAt:DateTime(2026,10,day,hour,20),status:status,
    );
  final completed=app.WorkAttemptStatus.completed;
  final cases=<String,(List<app.CentralizerRecord>,bool)>{
    'historical completion does not complete a later day':([record('old',14,9,completed)],false),
    'completion on the schedule work date is shown':([record('today',15,9,completed)],true),
    'latest refused retry remains pending':([
      record('done',15,8,completed),record('retry',15,9,app.WorkAttemptStatus.refused),
    ],false),
    'completion by another team does not complete this team':([
      record('other',15,9,completed,teamId:'other-team'),
    ],false),
  };
  for(final entry in cases.entries){
    testWidgets(entry.key,(tester) async {
      tester.view.physicalSize=const Size(1000,1400);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings=app.AppSettings()..learning['program']!.enabled=false;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.ProgramPage(
        currentUser:app.AppUser(id:'editor',name:'Editor',role:app.UserRole.member),
        teams:[app.Team(id:'team',name:'Team',members:['editor'])],
        cars:[],locations:[],categories:[],
        schedules:[app.WorkSchedule(id:'day',teamId:'team',date:DateTime(2026,10,15),items:[
          app.ScheduleItem(locationId:'room',locationNameSnapshot:'Room',
            addressSnapshot:'Address',typeSnapshot:app.LocationType.magic,order:1),
        ])],
        records:entry.value.$1,settings:settings,canEditTeam:(_)=>true,
        canEditProgram:true,userName:(_)=>'Editor',onChanged:(){},
        notifyTeam:(_,__,___){},log:(_,__){},saveSchedules:(_) async {},
      ))));
      await tester.pumpAndSettle();
      final expected=entry.value.$2?'Finalizată':'Rămasă';
      expect(find.text('Address · $expected'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
