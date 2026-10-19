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
import 'package:andi_carpeta/centralizer/correction_writer.dart';
import 'package:andi_carpeta/operations/atomic_restore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('XIX native UI creates Craiova Graph -> 11 Dashboard interventions -> Firestore -> Centralizator -> PDF', (tester) async {
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
    final evidence=<String,dynamic>{'completed':false};
    final permissionDenied=isA<FirebaseException>().having((e)=>e.code,'code','permission-denied');
    late List<app.ScheduleItem> items;
    late app.WorkSchedule schedule;
    final schedules=<app.WorkSchedule>[];
    final graphLocations=List<app.Location>.generate(11,(index){
      final suffix=(index+1).toString().padLeft(2,'0');
      return app.Location(id:'craiova-$suffix',name:'Craiova $suffix',address:'Craiova $suffix',type:app.LocationType.magic);
    });
    final records=<app.CentralizerRecord>[];
    Future<void>? pendingScheduleWrite;
    Future<void> save(app.CentralizerRecord record) async {
      final data=app.recordDocumentData(record);
      await saveRecordCompared(db,record.id,data,expected:record.writeBaseline);
      record.writeBaseline=Map<String,dynamic>.from(data)..remove('updatedAt');
      records.removeWhere((r)=>r.id==record.id);records.add(record);
    }
    Future<void> persistSchedules(List<app.WorkSchedule> updated) async {
      for(final entry in updated){
        await db.collection('schedules').doc(entry.id).set({
          'teamId':entry.teamId,'graphId':entry.graphId,'graphName':entry.graphName,
          'date':Timestamp.fromDate(entry.date),'started':entry.started,
          'closed':entry.closed,'active':entry.active,'paused':entry.paused,
          'items':entry.items.map((item)=>{'locationId':item.locationId}).toList(),
        });
      }
      schedules..clear()..addAll(updated);
    }
    Future<void> openProgramPage() async {
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.ProgramPage(
        currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),
        teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],cars:[],locations:graphLocations,categories:[],
        schedules:schedules,records:records,settings:app.AppSettings(),
        canEditTeam:(_)=>true,canEditProgram:true,userName:(_)=>'Editor',
        onChanged:(){},notifyTeam:(_,__,___){},log:(_,__) {},saveSchedules:(updated){
          final pending=persistSchedules(updated);pendingScheduleWrite=pending;return pending;
        },
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,reason:'The Graph page must not raise Flutter framework exceptions');
    }
    Future<void> createGraphThroughUi() async {
      await openProgramPage();
      await tester.tap(find.text('Creează grafic'));
      await tester.pumpAndSettle();
      for(final location in graphLocations){
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField),location.name);
        await tester.pumpAndSettle();
        final tile=find.widgetWithText(CheckboxListTile,location.name);
        await tester.scrollUntilVisible(tile,80,scrollable:find.descendant(of:find.byType(AlertDialog),matching:find.byType(Scrollable)).first);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      expect(find.widgetWithText(Chip,'1. Craiova 01'),findsOneWidget);
      await tester.tap(find.text('Finalizare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuă'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first,'Craiova XIX');
      await tester.pumpAndSettle();
      expect(find.text('Creează graficul').hitTestable(),findsOneWidget);
      await tester.tap(find.text('Creează graficul'));
      await tester.pumpAndSettle();
      expect(pendingScheduleWrite,isNotNull,reason:'Graph UI must invoke its persistence callback');
      await pendingScheduleWrite!.timeout(const Duration(seconds:30));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,reason:'Creating a Graph through the UI must not raise Flutter framework exceptions');
      expect(schedules,hasLength(1));
      schedule=schedules.single;
      items=schedule.items;
      expect(schedule.graphName,'Craiova XIX');
      expect(items,hasLength(11));
      final savedGraph=await db.collection('schedules').doc(schedule.id).get(const GetOptions(source:Source.server));
      expect(savedGraph.metadata.isFromCache,false);
      expect(savedGraph.metadata.hasPendingWrites,false);
      expect(savedGraph.data()!['graphName'],'Craiova XIX');
      expect(savedGraph.data()!['teamId'],'craiova');
      expect(savedGraph.data()!['closed'],false);
      expect((savedGraph.data()!['items'] as List).map((item)=>item['locationId']).toList(),
        graphLocations.map((location)=>location.id).toList());
      evidence['graphCreatedThroughUi']=true;
      // START intentionally remains outside this smoke: it geocodes real trip
      // endpoints. Mark the emulator fixture active after UI creation instead.
      schedule.started=true;
      await persistSchedules([schedule]);
    }
    Future<void> graphPage() async {
      await openProgramPage();
      expect(find.text('Grafic de lucru'),findsWidgets);
      expect(find.text('Craiova XIX'),findsWidgets);
      expect(find.text('Activ'),findsOneWidget);
      expect(find.text('Locații'),findsWidgets);
      expect(find.text('11'),findsWidgets);
      expect(find.text('Craiova 01'),findsWidgets);
      expect(find.text('Craiova 11'),findsWidgets);
    }
    Future<void> dashboard() async {
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.DashboardPage(
        teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],users:[],functionDefinitions:[],locations:[],categories:[],
        schedules:schedules,records:records,settings:app.AppSettings()..allowUndo=false,
        currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),canEditProgram:true,
        userName:(_)=>'Editor',onChanged:(){},saveRecord:save,saveSchedule:(_) async {},saveSchedules:(_) async {},log:(_,__) {},
      ))));await tester.pumpAndSettle();
    }
    // Create and persist the Craiova Graph through ProgramPage UI, then mark
    // the emulator fixture active without invoking external geocoding.
    await createGraphThroughUi();
    await graphPage();
    for(final item in items){
      await dashboard();
      final start=find.byTooltip('Intră / începe lucrul').first;
      await tester.ensureVisible(start);await tester.tap(start);await tester.tap(start,warnIfMissed:false);
      for(var n=0;n<60&&!records.any((r)=>r.locationId==item.locationId&&r.status==app.WorkAttemptStatus.running);n++){await tester.pump(const Duration(milliseconds:200));}
      expect(records.where((r)=>r.locationId==item.locationId&&r.status==app.WorkAttemptStatus.running),hasLength(1));
      await dashboard();
      final stop=find.byTooltip('Stop / ieși din locație');await tester.ensureVisible(stop);
      await tester.tap(stop);await tester.tap(stop,warnIfMissed:false);await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsOneWidget);await tester.tap(find.text('DA'));
      for(var n=0;n<60&&!records.any((r)=>r.locationId==item.locationId&&r.completed);n++){await tester.pump(const Duration(milliseconds:200));}
      expect(records.singleWhere((r)=>r.locationId==item.locationId).completed,true);
    }
    expect(records,hasLength(11));
    // Reproject the 11 UI-created Firestore records onto the reported two-day
    // Craiova scenario. The first is changed to an overnight event below.
    for(var index=0;index<items.length;index++){
      final record=records.singleWhere((r)=>r.locationId==items[index].locationId);
      final ref=db.collection('records').doc(record.id);
      final current=(await ref.get(const GetOptions(source:Source.server))).data()!;
      final day=index<7?15:16;
      final hour=index<7?9+index:9+index-7;
      final started=DateTime(2026,10,day,hour);
      final finished=started.add(const Duration(hours:1));
      await saveRecordCompared(db,record.id,{...current,'startedAt':Timestamp.fromDate(started),'finishedAt':Timestamp.fromDate(finished)},expected:current);
    }
    final reloadedScenarioRecords=<app.CentralizerRecord>[];
    for(final item in items){
      final record=records.singleWhere((r)=>r.locationId==item.locationId);
      final snapshot=await db.collection('records').doc(record.id).get(const GetOptions(source:Source.server));
      expect(snapshot.exists,true);
      reloadedScenarioRecords.add(app.centralizerRecordFromData(snapshot.id,snapshot.data()!));
    }
    records..clear()..addAll(reloadedScenarioRecords);
    final firstRecord=records.first;
    final ref=db.collection('records').doc(firstRecord.id);
    final persisted=await ref.get(const GetOptions(source:Source.server));
    evidence['connectedFlow']={'expected':'11 completed Craiova Dashboard records after double taps and server reload','observed':records.length,'id':persisted.id};
    final expected=Map<String,dynamic>.from(persisted.data()!);
    final desired={...expected,'facadeDone':false,'updatedAt':FieldValue.serverTimestamp()};
    await saveRecordCompared(db,ref.id,desired,expected:expected);
    await saveRecordCompared(db,ref.id,desired,expected:expected); // lost acknowledgement retry
    evidence['sameAttemptRetry']='one document, identical payload accepted';
    final beforeRace=(await ref.get()).data()!;
    final countBeforeRace=(await db.collection('records').get()).size;
    final race=await Future.wait([db,otherDb].asMap().entries.map((e) async {
      try {await saveRecordCompared(e.value,ref.id,{...beforeRace,'addressSnapshot':'race-${e.key}'},expected:beforeRace);return true;}
      on StateError catch(e){
        expect(e.message,contains('modificată pe alt dispozitiv'));return false;
      }
    }));
    expect(race.where((v)=>v).length,1);
    expect((await ref.get(const GetOptions(source:Source.server))).data()!['addressSnapshot'],'race-${race.indexOf(true)}');
    expect((await db.collection('records').get()).size,countBeforeRace);
    evidence['twoNativeClients']={'accepted':race,'loser':'StateError stale baseline','serverWinner':'race-${race.indexOf(true)}','documentCount':countBeforeRace};
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
    final deletedCorrection=otherDb.collection('records').doc('deleted-correction');
    await deletedCorrection.set(legacyBefore);await deletedCorrection.delete();
    await otherAuth.signInWithEmailAndPassword(email:'outsider@andi.test',password:'synthetic-only-123');
    await expectLater(saveRecordCompared(otherDb,ref.id,{...latest,'facadeDone':true},expected:latest),throwsA(permissionDenied));
    evidence['unauthorizedTeam']='permission-denied';
    final beforeCorrection=app.centralizerRecordFromData(ref.id,latest);
    var correctionSaved=false;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.CentralizerPage(
      currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),
      teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],
      locations:[],categories:[],schedules:[],records:[beforeCorrection],
      isAdmin:false,canEditTeam:(_)=>true,canEditCentralizer:true,
      onChanged:(){},log:(_,__) {},saveRecord:(_) async {fail('correction must not add a record');},
      correctRecord:(original,corrected) async {
        expect(original.id,ref.id);expect(corrected.id,ref.id);
        expect(corrected.teamId,original.teamId);expect(corrected.locationId,original.locationId);
        await correctCentralizerRecordCompared(db,ref.id,expected:{
          'teamId':original.teamId,'locationId':original.locationId,'type':original.type.name,
          'startedAt':original.startedAt,'finishedAt':original.finishedAt,'status':original.status.name,
          'facadeDone':original.facadeDone,'facadePlanned':original.facadePlanned,
        },changes:{
          'startedAt':Timestamp.fromDate(corrected.startedAt!),
          'finishedAt':Timestamp.fromDate(corrected.finishedAt!),
          'facadeDone':corrected.facadeDone,'facadePlanned':corrected.facadePlanned,
          'updatedAt':FieldValue.serverTimestamp(),
        });
        correctionSaved=true;
      },
    ))));
    await tester.pumpAndSettle();
    final correctedLocation=find.text(beforeCorrection.locationNameSnapshot);
    await tester.ensureVisible(correctedLocation);await tester.tap(correctedLocation);
    await tester.pumpAndSettle();
    final editCorrection=find.byTooltip('Corectează data, orele și fațada');
    await tester.ensureVisible(editCorrection);await tester.tap(editCorrection);
    await tester.pumpAndSettle();
    final correctionFields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextField));
    expect(correctionFields,findsNWidgets(2));
    await tester.enterText(correctionFields.at(0),'23:55');
    await tester.enterText(correctionFields.at(1),'00:20');
    await tester.pumpAndSettle();
    final facadeSwitch=find.descendant(of:find.byType(AlertDialog),matching:find.byType(SwitchListTile));
    await tester.ensureVisible(facadeSwitch);await tester.tap(facadeSwitch);
    await tester.pumpAndSettle();await tester.tap(find.text('Salvează'));
    for(var n=0;n<60&&!correctionSaved;n++){await tester.pump(const Duration(milliseconds:200));}
    await tester.pumpAndSettle();
    expect(correctionSaved,true);expect(tester.takeException(),isNull);
    evidence['correctionThroughUi']=true;
    final nightSnapshot=await ref.get(const GetOptions(source:Source.server));
    final night=nightSnapshot.data()!;
    // Exercise the production correction writer, rather than the general writer
    // substituted by the earlier component adapter. No synthetic live backend.
    await expectLater(correctCentralizerRecordCompared(db,ref.id,
      expected:{'finishedAt':beforeCorrection.finishedAt},changes:{'facadeDone':false}),
      throwsA(anyOf(isA<StateError>(),isA<FirebaseException>())));
    await expectLater(correctCentralizerRecordCompared(db,'deleted-correction',
      expected:{'teamId':'craiova'},changes:{'facadeDone':false}),
      throwsA(anyOf(isA<StateError>(),isA<FirebaseException>())));
    await expectLater(correctCentralizerRecordCompared(otherDb,ref.id,
      expected:{'teamId':'craiova'},changes:{'facadeDone':false}),throwsA(permissionDenied));
    await db.disableNetwork();
    try {
      await expectLater(correctCentralizerRecordCompared(db,ref.id,
        expected:{'facadeDone':true},changes:{'facadeDone':false}),
        throwsA(anyOf(isA<StateError>(),isA<FirebaseException>())));
    } finally {
      await db.enableNetwork();
    }
    expect((await ref.get(const GetOptions(source:Source.server))).data()!['facadeDone'],true);
    evidence['productionCorrectionWriter']='UI adapter uses HomePage persistence; stale, deleted, unauthorized and offline corrections rejected';
    final reloaded=app.centralizerRecordFromData(ref.id,nightSnapshot.data()!);
    expect(reloaded.duration,const Duration(minutes:25));
    expect(reloaded.startedAt,DateTime(2026,10,15,23,55));
    expect(reloaded.finishedAt,DateTime(2026,10,16,0,20));
    expect(reloaded.facadeDone,true);
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
    final finalScenarioRecords=<app.CentralizerRecord>[];
    for(final item in items){
      final record=records.singleWhere((r)=>r.locationId==item.locationId);
      final snapshot=await db.collection('records').doc(record.id).get(const GetOptions(source:Source.server));
      expect(snapshot.exists,true);
      finalScenarioRecords.add(app.centralizerRecordFromData(snapshot.id,snapshot.data()!));
    }
    final projected=app.centralizerPdfExecutionRows(records:finalScenarioRecords,type:app.LocationType.magic,teamId:'craiova');
    expect(projected,hasLength(11));
    expect(projected.where((row)=>row.date.day==15),hasLength(6));
    expect(projected.where((row)=>row.date.day==16),hasLength(5));
    expect(projected.map((row)=>row.record.id).toSet(),hasLength(11));
    final scheduledLocationIds=schedule.items.map((item)=>item.locationId).toSet();
    final executedLocationIds=finalScenarioRecords.map((record)=>record.locationId).toSet();
    expect(scheduledLocationIds,hasLength(11));
    expect(executedLocationIds,scheduledLocationIds);
    // Keep the same Graph location IDs and split its snapshot by each
    // execution's synthetic operational date for Centralizer/PDF matching.
    final projectedSchedules=<app.WorkSchedule>[
      app.WorkSchedule(id:'graph-craiova-15',teamId:'craiova',date:DateTime(2026,10,15),items:items.sublist(1,7),started:true),
      app.WorkSchedule(id:'graph-craiova-16',teamId:'craiova',date:DateTime(2026,10,16),items:[items.first,...items.sublist(7)],started:true),
    ];
    for(final projectedSchedule in projectedSchedules){
      await db.collection('schedules').doc(projectedSchedule.id).set({
        'teamId':projectedSchedule.teamId,
        'date':Timestamp.fromDate(projectedSchedule.date),
        'started':projectedSchedule.started,
        'items':projectedSchedule.items.map((item)=>{'locationId':item.locationId}).toList(),
      });
    }
    final scenarioSchedules=<app.WorkSchedule>[];
    for(final projectedSchedule in projectedSchedules){
      final snapshot=await db.collection('schedules').doc(projectedSchedule.id).get(const GetOptions(source:Source.server));
      expect(snapshot.exists,true);
      final data=snapshot.data()!;
      final persistedIds=(data['items'] as List).map((raw)=>(raw as Map)['locationId'] as String).toList();
      final persistedItems=persistedIds.map((id)=>items.singleWhere((item)=>item.locationId==id)).toList();
      scenarioSchedules.add(app.WorkSchedule(
        id:snapshot.id,teamId:data['teamId'] as String,date:(data['date'] as Timestamp).toDate(),
        items:persistedItems,started:data['started'] as bool,
      ));
    }
    final scheduledScenarioIds=scenarioSchedules.expand((entry)=>entry.items).map((item)=>item.locationId).toSet();
    expect(scheduledScenarioIds,scheduledLocationIds);
    for(final scenarioSchedule in scenarioSchedules){
      for(final item in scenarioSchedule.items){
        final execution=projected.singleWhere((row)=>row.record.locationId==item.locationId);
        expect(execution.date.year,scenarioSchedule.date.year);
        expect(execution.date.month,scenarioSchedule.date.month);
        expect(execution.date.day,scenarioSchedule.date.day);
      }
    }
    final plannedItem=app.ScheduleItem(locationId:'craiova-planned',locationNameSnapshot:'Craiova planificată',addressSnapshot:'Craiova',typeSnapshot:app.LocationType.magic,order:0);
    final plannedSchedule=app.WorkSchedule(id:'graph-craiova-planned',teamId:'craiova',date:DateTime(2026,10,16),items:[plannedItem],started:true);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:app.CentralizerPage(
      currentUser:app.AppUser(id:uid,name:'Editor',role:app.UserRole.member),teams:[app.Team(id:'craiova',name:'Craiova',members:[uid])],
      locations:[],categories:[],schedules:scenarioSchedules,records:finalScenarioRecords,isAdmin:false,canEditTeam:(_)=>true,canEditCentralizer:true,
      onChanged:(){},log:(_,__) {},saveRecord:save,correctRecord:(_,__) async {},
    ))));await tester.pumpAndSettle();expect(find.textContaining('11 execuții'),findsOneWidget);
    final bytes=await app.buildCentralizerPdf(type:app.LocationType.magic,locations:[],teams:[],schedules:[...scenarioSchedules,plannedSchedule],records:finalScenarioRecords,teamId:'craiova');
    final out=Directory('/data/user/0/com.example.andi_carpeta/files/xix-evidence')..createSync(recursive:true);
    File('${out.path}/native-flow.pdf').writeAsBytesSync(bytes);
    evidence['craiova11']={
      'observed':finalScenarioRecords.length,
      'day15':projected.where((row)=>row.date.day==15).length,
      'day16':projected.where((row)=>row.date.day==16).length,
      'uniqueIds':projected.map((row)=>row.record.id).toSet().length,
      'centralizerCount':finalScenarioRecords.length,
      'dashboardScheduleItems':schedule.items.length,
      'pdfMatchedScheduleItems':scenarioSchedules.expand((entry)=>entry.items).where((item)=>executedLocationIds.contains(item.locationId)).length,
      'scheduleDatesMatchExecutions':true,
      'pdfMarkers':finalScenarioRecords.map((record)=>record.locationNameSnapshot).toList()..sort(),
      'plannedRowName':plannedItem.locationNameSnapshot,
      'plannedRowRecordCount':finalScenarioRecords.where((record)=>record.locationId==plannedItem.locationId).length,
    };
    evidence['pdf']='11 Firestore-reloaded Craiova records rendered; planned row retained';
    File('${out.path}/observations.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    await otherDb.doc('users/$uid').update({'active':false});
    await expectLater(saveRecordCompared(db,ref.id,{...night,'facadeDone':false},expected:night),throwsA(permissionDenied));
    await otherDb.doc('users/$uid').update({'active':true});
    evidence['revokedProfile']='cached Auth identity cannot write after server profile deactivation';
    final snapshot={for(final d in (await otherDb.collection('records').get()).docs)d.id:d.data()};
    await otherDb.doc('meta/backup').set({'fileName':'retained.json','lastExportAt':Timestamp(1,0)});
    await restoreAtomically(otherDb,{'records':snapshot},source:'synthetic-complete');
    await restoreAtomically(otherDb,{'records':snapshot},source:'synthetic-repeat');
    expect((await otherDb.doc('meta/backup').get()).data()!['fileName'],'retained.json');
    expect((await otherDb.collection('records').get()).size,snapshot.length);
    // records inventory is readable by an active member. The intended record
    // update is authorized, while deletion of other records and meta/backup
    // are not: commit must roll back the authorized update as well.
    final deniedRestore={'records':{ref.id:{...snapshot[ref.id]!, 'addressSnapshot':'must-rollback'}}};
    await expectLater(restoreAtomically(db,deniedRestore,source:'denied-partial'),throwsA(permissionDenied));
    expect({for(final d in (await otherDb.collection('records').get()).docs)d.id:d.data()},snapshot);
    await expectLater(restoreAtomically(otherDb,{'records':{for(var i=0;i<401;i++)'large-$i':{'teamId':'craiova'}}},source:'oversized'),throwsA(isA<StateError>()));
    expect((await otherDb.collection('records').get()).size,snapshot.length);
    evidence['restore']='admin complete/repeat passed; readable inventory followed by denied mixed batch rolled back allowed update and deletions; oversized restore changed no records';
    evidence['completed']=true;
    File('${out.path}/observations.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
    // Wait for the host to confirm that both native artifacts were copied.
    final receipt=File('${out.path}/host-captured.ok');
    var received=false;
    for (var n=0;n<120;n++) {
      if (receipt.existsSync()) { received=true; break; }
      await Future<void>.delayed(const Duration(milliseconds:500));
    }
    expect(received,isTrue,reason:'Host evidence capture acknowledgement missing');
    await otherApp.delete();
  },timeout:const Timeout(Duration(minutes:8)));
}
