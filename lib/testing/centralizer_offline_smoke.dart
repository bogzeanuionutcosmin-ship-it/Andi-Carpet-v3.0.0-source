// Synthetic UI harness. No Firebase initialization, login, network or real data.
import 'package:flutter/material.dart';
import '../main.dart' as app;

void main() => runApp(const MaterialApp(home:CentralizerOfflineSmoke()));

class CentralizerOfflineSmoke extends StatefulWidget {
  const CentralizerOfflineSmoke({super.key});
  @override State<CentralizerOfflineSmoke> createState()=>_SmokeState();
}
class _SmokeState extends State<CentralizerOfflineSmoke> {
  bool rejectWrites=false;
  final locations=<app.Location>[
    for(var i=1;i<=11;i++) app.Location(id:'room-$i',name:'Sala $i',address:'Craiova sintetic',type:app.LocationType.magic),
  ];
  final records=<app.CentralizerRecord>[
    for(var i=1;i<=11;i++) app.CentralizerRecord(id:'execution-$i',teamId:'craiova',locationId:'room-$i',type:app.LocationType.magic,
      locationNameSnapshot:'Sala $i',addressSnapshot:'Craiova sintetic',
      startedAt:DateTime(2026,10,i<=6?15:16,10),finishedAt:DateTime(2026,10,i<=6?15:16,11),status:app.WorkAttemptStatus.completed),
  ];
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('TEST Centralizator · fără Firebase')),
    body:Column(children:[
      SwitchListTile(title:const Text('Simulează salvare eșuată'),value:rejectWrites,onChanged:(v)=>setState(()=>rejectWrites=v)),
      Expanded(child:app.CentralizerPage(
        currentUser:app.AppUser(id:'synthetic-admin',name:'TEST',role:app.UserRole.director),
        teams:[app.Team(id:'craiova',name:'Craiova TEST',members:['synthetic-admin'])],
        locations:locations,categories:[],schedules:[],records:records,isAdmin:true,
        canEditTeam:(_)=>true,canEditCentralizer:true,onChanged:()=>setState((){}),log:(_,__){},
        saveRecord:(record) async {
          if(rejectWrites) throw StateError('Eroare sintetică; nimic salvat.');
          setState(()=>records.add(record));
        },
        correctRecord:(original,corrected) async {
          if(rejectWrites) throw StateError('Eroare sintetică; nimic salvat.');
          final index=records.indexWhere((r)=>r.id==original.id);
          if(index<0)throw StateError('Intervenție lipsă.');
          setState(()=>records[index]=corrected);
        },
      )),
    ]),
  );
}
