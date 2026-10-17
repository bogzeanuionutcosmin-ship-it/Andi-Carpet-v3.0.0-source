import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('renders actual Craiova and overnight PDF bytes using the production builder', () async {
    final records = <CentralizerRecord>[
      for (var i = 1; i <= 11; i++) CentralizerRecord(
        id:'execution-$i',teamId:'craiova',locationId:'room-$i',type:LocationType.magic,
        locationNameSnapshot:'Sala $i',addressSnapshot:'Craiova',
        startedAt:DateTime(2026,10,i<=6?15:16,10),finishedAt:DateTime(2026,10,i<=6?15:16,11),
        status:WorkAttemptStatus.completed,facadeDone:i==6,facadePlanned:i==6,
      ),
    ];
    final directory=Directory('build/pdf-verification')..createSync(recursive:true);
    for(final overnight in [false,true]) {
      final input=overnight?<CentralizerRecord>[CentralizerRecord(
        id:'overnight',teamId:'craiova',locationId:'night',type:LocationType.magic,
        locationNameSnapshot:'Night room',addressSnapshot:'Craiova',
        startedAt:DateTime(2026,10,15,23,55),finishedAt:DateTime(2026,10,16,0,20),
        status:WorkAttemptStatus.completed,
      )]:records;
      final bytes=await buildCentralizerPdf(type:LocationType.magic,locations:[],teams:[],schedules:[],
        records:input,teamId:'craiova');
      expect(bytes.take(5),[37,80,68,70,45]);
      expect(bytes.length,greaterThan(1000));
      File('${directory.path}/${overnight?'overnight':'craiova'}.pdf').writeAsBytesSync(bytes);
    }
    final history=<CentralizerRecord>[
      for(var i=0;i<80;i++) CentralizerRecord(
        id:'history-$i',teamId:'craiova',locationId:'history-room',type:LocationType.magic,
        locationNameSnapshot:'Istoric extins',addressSnapshot:'Craiova',
        startedAt:DateTime(2026,10,15,10),finishedAt:DateTime(2026,10,15,11),
        status:WorkAttemptStatus.completed,
      ),
    ];
    final dense=await buildCentralizerPdf(type:LocationType.magic,locations:[],teams:[],schedules:[],records:history);
    File('${directory.path}/history.pdf').writeAsBytesSync(dense);
  });
}
