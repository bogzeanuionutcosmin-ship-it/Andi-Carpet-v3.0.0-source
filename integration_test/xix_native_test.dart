import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/main.dart' as app;
import 'package:andi_carpeta/operations/record_writer.dart';
import 'package:andi_carpeta/operations/atomic_restore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('XIX native SDK connected Dashboard -> Firestore -> reload -> Centralizator -> PDF', (tester) async {
    await app.main();
    final auth=FirebaseAuth.instance;
    final db=FirebaseFirestore.instance;
    await auth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    final uid=auth.currentUser!.uid;
    final otherApp=await Firebase.initializeApp(name:'second-device',options:Firebase.app().options);
    final otherAuth=FirebaseAuth.instanceFor(app:otherApp);
    await otherAuth.useAuthEmulator('10.0.2.2',9099);
    final otherDb=FirebaseFirestore.instanceFor(app:otherApp)..useFirestoreEmulator('10.0.2.2',8080);
    await otherAuth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    final evidence=<String,dynamic>{};
    final workDate=app.operationalWorkDate(DateTime.now());
    final item=app.ScheduleItem(locationId:'sala-xix',locationNameSnapshot:'Sala XIX',addressSnapshot:'Craiova',typeSnapshot:app.LocationType.magic,order:0);
    final schedule=app.WorkSchedule(id:'graph-xix',teamId:'craiova',date:workDate,items:[item],started:true);
    await db.collection('schedules').doc(schedule.id).set({'teamId':'craiova','date':Timestamp.fromDate(workDate),'started':true,'items':[{'locationId':item.locationId}]});
    final records=<app.CentralizerRecord>[];
    Future<void> save(app.CentralizerRecord record) async {
      final data=app.recordDocumentData(record);
      await saveRecordCompared(db,record.id,data,expected:record.writeBaseline);
      record.writeBaseline=Map<String,dynamic>.from(data)..remove('updatedAt');
      records.removeWhere((r)=>r.id==record.id);records.add(record);
    }
    Future<void> dashboard() async {
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.DashboardPage(
        teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],users:[],functionDefinitions:[],locations:[],categories:[],
        schedules:[schedule],records:records,settings:app.AppSettings()..allowUndo=false,
        currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),canEditProgram:true,
        userName:(_)=>'Editor',onChanged:(){},saveRecord:save,saveSchedule:(_) async {},saveSchedules:(_) async {},log:(_,__) {},
      ))));await tester.pumpAndSettle();
    }
    await dashboard();
    final start=find.byTooltip('Intră / începe lucrul');
    await tester.ensureVisible(start);await tester.tap(start);await tester.tap(start,warnIfMissed:false);
    for(var n=0;n<60&&records.isEmpty;n++){await tester.pump(const Duration(milliseconds:200));}
    expect(records.length,1);expect(records.single.status,app.WorkAttemptStatus.running);
    await dashboard();
    final stop=find.byTooltip('Stop / ieși din locație');await tester.ensureVisible(stop);
    await tester.tap(stop);await tester.tap(stop,warnIfMissed:false);await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsOneWidget);await tester.tap(find.text('DA'));
    for(var n=0;n<60&&!records.single.completed;n++){await tester.pump(const Duration(milliseconds:200));}
    expect(records.single.completed,true);
    final ref=db.collection('records').doc(records.single.id);
    final persisted=await ref.get(const GetOptions(source:Source.server));
    records..clear()..add(app.centralizerRecordFromData(persisted.id,persisted.data()!));
    evidence['connectedFlow']={'expected':'one completed record after double taps and server reload','observed':records.length,'id':persisted.id};
    final expected=Map<String,dynamic>.from(persisted.data()!);
    final desired={...expected,'facadeDone':false,'updatedAt':FieldValue.serverTimestamp()};
    await saveRecordCompared(db,ref.id,desired,expected:expected);
    await saveRecordCompared(db,ref.id,desired,expected:expected); // lost acknowledgement retry
    evidence['sameAttemptRetry']='one document, identical payload accepted';
    final beforeRace=(await ref.get()).data()!;
    final race=await Future.wait([db,otherDb].asMap().entries.map((e) async {
      try {await saveRecordCompared(e.value,ref.id,{...beforeRace,'addressSnapshot':'race-${e.key}'},expected:beforeRace);return true;}
      catch(_){return false;}
    }));
    expect(race.where((v)=>v).length,1);evidence['twoNativeClients']=race;
    await expectLater(saveRecordCompared(db,ref.id,{...beforeRace,'addressSnapshot':'stale'},expected:beforeRace),throwsA(isA<StateError>()));
    final latest=(await ref.get()).data()!;
    // Actual former writer operation: demonstrate deleted-document resurrection.
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    final legacy=otherDb.collection('records').doc('deleted-legacy');
    await legacy.set({'teamId':'craiova','locationId':'legacy','type':'magic'});
    final legacyBefore=(await legacy.get()).data()!;await legacy.delete();
    await db.collection('records').doc(legacy.id).set(legacyBefore,SetOptions(merge:true));
    expect((await legacy.get()).exists,true);evidence['oldWriterWitness']='deleted legacy document recreated by former upsert';
    await legacy.delete();
    await expectLater(saveRecordCompared(db,legacy.id,{...legacyBefore,'status':'running'},expected:legacyBefore),throwsA(isA<StateError>()));
    expect((await legacy.get()).exists,false);
    await legacy.set({...legacyBefore,'metadata':{'tags':['legacy',{'version':1}]}});
    final nestedLegacy=(await legacy.get()).data()!;
    await saveRecordCompared(db,legacy.id,{...nestedLegacy,'status':'running'},expected:nestedLegacy);
    evidence['legacyAndDeletion']='legacy update passed; deleted baseline rejected';
    await otherAuth.signInWithEmailAndPassword(email:'outsider@andi.test',password:'synthetic-only-123');
    await expectLater(saveRecordCompared(otherDb,ref.id,{...latest,'facadeDone':true},expected:latest),throwsA(isA<FirebaseException>()));
    evidence['unauthorizedTeam']='permission-denied';
    final night={...latest,'startedAt':Timestamp.fromDate(DateTime(2026,10,15,23,55)),'finishedAt':Timestamp.fromDate(DateTime(2026,10,16,0,20)),'status':'completed'};
    await saveRecordCompared(db,ref.id,night,expected:latest);
    final nightSnapshot=await ref.get(const GetOptions(source:Source.server));
    final reloaded=app.centralizerRecordFromData(ref.id,nightSnapshot.data()!);
    expect(reloaded.duration,const Duration(minutes:25));
    await saveRecordCompared(db,'second-legitimate',{...nightSnapshot.data()!,
      'startedAt':Timestamp.fromDate(DateTime(2026,10,16,0,55)),
      'finishedAt':Timestamp.fromDate(DateTime(2026,10,16,1,20))});
    expect((await db.doc('records/second-legitimate').get()).exists,true);
    evidence['distinctLegitimateAttempt']='a distinct completed attempt retains a distinct ID';
    await db.disableNetwork();
    try {
      await expectLater(saveRecordCompared(db,'offline-attempt',{'teamId':'craiova','locationId':'offline','status':'running'}),throwsA(isA<FirebaseException>()));
    } finally {
      await db.enableNetwork();
    }
    expect((await db.doc('records/offline-attempt').get(const GetOptions(source:Source.server))).exists,false);
    evidence['offlineBeforeStart']='native transaction rejected; reconnect has no queued record';
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.CentralizerPage(
      currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],
      locations:[],categories:[],schedules:[schedule],records:[reloaded],isAdmin:false,canEditTeam:(_)=>true,canEditCentralizer:true,
      onChanged:(){},log:(_,__) {},saveRecord:save,correctRecord:(_,__) async {},
    ))));await tester.pumpAndSettle();expect(find.text('Sala XIX'),findsOneWidget);
    final bytes=await app.buildCentralizerPdf(type:app.LocationType.magic,locations:[],teams:[],schedules:[schedule],records:[reloaded]);
    final out=Directory('/data/user/0/com.example.andi_carpeta/files/xix-evidence')..createSync(recursive:true);
    File('${out.path}/native-flow.pdf').writeAsBytesSync(bytes);
    evidence['pdf']='real builder with data reloaded from native Firestore; missing registry retained';
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    await otherDb.doc('users/$uid').update({'active':false});
    await expectLater(saveRecordCompared(db,ref.id,{...night,'facadeDone':true},expected:night),throwsA(isA<FirebaseException>()));
    await otherDb.doc('users/$uid').update({'active':true});
    evidence['revokedProfile']='cached Auth identity cannot write after server profile deactivation';
    final snapshot={for(final d in (await otherDb.collection('records').get()).docs)d.id:d.data()};
    await otherDb.doc('meta/backup').set({'fileName':'retained.json','lastExportAt':Timestamp(1,0)});
    await restoreAtomically(otherDb,{'records':snapshot},source:'synthetic-complete');
    await restoreAtomically(otherDb,{'records':snapshot},source:'synthetic-repeat');
    expect((await otherDb.doc('meta/backup').get()).data()!['fileName'],'retained.json');
    expect((await otherDb.collection('records').get()).size,snapshot.length);
    await expectLater(restoreAtomically(db,{'records':{},'finance':{'forbidden':{'teamId':'forbidden'}}},source:'denied-partial'),throwsA(isA<FirebaseException>()));
    expect({for(final d in (await otherDb.collection('records').get()).docs)d.id:d.data()},snapshot);
    await expectLater(restoreAtomically(otherDb,{'records':{for(var i=0;i<401;i++)'large-$i':{'teamId':'craiova'}}},source:'oversized'),throwsA(isA<StateError>()));
    expect((await otherDb.collection('records').get()).size,snapshot.length);
    evidence['restore']='admin complete/repeat passed; denied atomic batch and oversized restore changed no records';
    File('${out.path}/observations.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
    await otherApp.delete();
  },timeout:const Timeout(Duration(minutes:8)));
}
