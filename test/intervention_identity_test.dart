import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/operations/record_writer.dart';

void main() {
  app.ScheduleItem item(String id)=>app.ScheduleItem(interventionId:id,locationId:'room',locationNameSnapshot:'Room',addressSnapshot:'',typeSnapshot:app.LocationType.magic,order:1);
  app.CentralizerRecord record(String id, {bool finished=false})=>app.CentralizerRecord(
    id:'record',teamId:'team',graphId:'graph',scheduleId:'day',interventionId:id,
    locationId:'room',type:app.LocationType.magic,locationNameSnapshot:'Room',addressSnapshot:'',
    finishedAt:finished?DateTime(2026,10,21):null);
  test('new identity is unique; clones, reorder and removal preserve surviving identities', () {
    expect({for(var n=0;n<100;n++)app.newInterventionId()},hasLength(100));
    final first=item('visit-a'),second=item('visit-b')..order=2;
    final day=app.WorkSchedule(id:'day',teamId:'team',date:DateTime(2026,10,21),items:[first,second]);
    final cloned=app.cloneWorkSchedule(day);cloned.date=DateTime(2026,10,22);
    expect(cloned.items.map((i)=>i.interventionId),['visit-a','visit-b']);
    expect(app.reorderScheduleItems(day.items,0,2)!.map((i)=>i.interventionId),['visit-b','visit-a']);
    expect(app.removeProgramScheduleItem(day.items,locationId:'room',order:1).single.interventionId,'visit-b');
  });
  test('same room and date in another graph cannot satisfy a linked visit', () {
    final visit=item('visit-a');final day=app.WorkSchedule(id:'day',teamId:'team',graphId:'graph',date:DateTime(2026,10,21),items:[visit]);
    final other=record('visit-b',finished:true)..status=app.WorkAttemptStatus.completed..startedAt=DateTime(2026,10,20);
    expect(app.programGraphClosureReadiness(schedules:[day],records:[other]).canClose,false);
  });
  test('restart and manual/arrival clients choose same attempt slot; refusal consumes one', () {
    final visit=item('visit-a'); expect(app.nextInterventionRecordId(visit,[]),'iv_visit-a_1');
    expect(app.nextInterventionRecordId(visit,[record('visit-a')]),'iv_visit-a_1');
    expect(app.nextInterventionRecordId(visit,[record('visit-a',finished:true)]),'iv_visit-a_2');
    expect(app.nextInterventionRecordId(visit,[record('visit-b',finished:true)]),'iv_visit-a_1');
  });
  test('record codec preserves graph, day, visit and CAS baseline', () {
    final original=record('visit-a');final decoded=app.centralizerRecordFromData(original.id,app.recordDocumentData(original));
    expect(decoded.graphId,'graph');expect(decoded.scheduleId,'day');expect(decoded.interventionId,'visit-a');expect(decoded.writeBaseline,isNotNull);
  });
  test('START replay preserves committed times and rejects different outcomes or scope', () {
    final current={'teamId':'team','locationId':'room','interventionId':'visit','graphId':'graph','scheduleId':'day','status':'running','startedAt':1,'finishedAt':null};
    expect(recordOperationReplayMatches(current,{...current,'startedAt':2},null),true);
    expect(recordOperationReplayMatches(current,{...current,'interventionId':'another'},null),false);
    expect(recordOperationReplayMatches(current,{...current,'status':'completed','finishedAt':3},null),false);
    final done={...current,'status':'completed','finishedAt':3};
    expect(recordOperationReplayMatches(done,{...done,'finishedAt':4},current),true);
    expect(recordOperationReplayMatches(done,{...done,'finishedAt':4,'facadeDone':true},current),false);
    expect(recordOperationReplayMatches(done,{...done,'finishedAt':4},done),false);
  });
}
