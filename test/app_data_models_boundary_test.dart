// Import the model API directly: no main.dart or application bootstrap.
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_data_models.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';

void main() {
  test('standalone models preserve legacy defaults and isolate mutable lists', () {
    final first=Location(id:'a',name:'A',address:'',type:LocationType.other);
    final second=Location(id:'b',name:'B',address:'',type:LocationType.magic);
    first.contacts.add(LocationContact(name:'Contact',phone:'123'));
    expect(first.categoryId,'cazari');expect(second.categoryId,'magic');expect(second.contacts,isEmpty);
    final day=WorkSchedule(id:'day',teamId:'team',date:DateTime(2026,10,21),items:[]);
    expect(day.graphId,'day');expect(day.graphName,'Grafic 10/2026');expect(day.persisted,false);
    final record=CentralizerRecord(id:'r',teamId:'team',locationId:'a',type:LocationType.other,locationNameSnapshot:'A',addressSnapshot:'');
    expect(record.interventionId,isEmpty);expect(record.scheduleId,isEmpty);expect(record.graphId,isEmpty);
    expect(record.status,WorkAttemptStatus.waitingAccess);expect(record.completed,false);
  });
}
