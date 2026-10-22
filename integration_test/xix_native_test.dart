import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:andi_carpeta/operations/graph_closure_client.dart';
import 'package:andi_carpeta/operations/graph_closure_journal.dart';
import 'package:andi_carpeta/home/function_migration_guard.dart';
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
    final geocodedProgramQueries=<String>[];
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
          'departureName':entry.departureName,'departureLatitude':entry.departureLatitude,
          'departureLongitude':entry.departureLongitude,'returnName':entry.returnName,
          'returnLatitude':entry.returnLatitude,'returnLongitude':entry.returnLongitude,
          'interventionLocations':{for(final item in entry.items) item.interventionId:item.locationId},
          'items':entry.items.map((item)=>{'locationId':item.locationId,'interventionId':item.interventionId}).toList(),
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
        onChanged:(){},notifyTeam:(_,__,___){},log:(_,__) {},
        geocodeTripPoint:(query) async {
          geocodedProgramQueries.add(query);
          return query.toLowerCase().contains('plecare')
            ? {'lat':44.31,'lon':23.80}
            : {'lat':44.32,'lon':23.81};
        },
        saveSchedules:(updated){
          final pending=persistSchedules(updated);pendingScheduleWrite=pending;return pending;
        },
      ))));
      await tester.pumpAndSettle();
      final frameworkException=tester.takeException();
      if(frameworkException!=null){
        debugPrint('Program Graph page framework exception: $frameworkException');
        debugDumpRenderTree();
      }
      expect(frameworkException,isNull,reason:'The Graph page must not raise Flutter framework exceptions');
    }
    Future<void> createGraphThroughUi() async {
      await openProgramPage();
      await tester.tap(find.text('Creează grafic'));
      await tester.pumpAndSettle();
      final search=find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Caută sală / adresă / categorie');
      expect(search,findsOneWidget,reason:'The Graph picker must expose its location search field');
      await tester.ensureVisible(search);
      await tester.enterText(search,'Craiova');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Creează grafic · Ziua 1'));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus,false);
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text,'Craiova',
        reason:'The active Graph filter must stay visible while locations are selected');
      for(final location in graphLocations){
        // Scope scrolling to the picker's CustomScrollView. AlertDialog can
        // contain other scrollables (selected chips/actions); scrolling those
        // leaves virtualized location rows unbuilt.
        final pickerList=find.descendant(
          of:find.byType(CustomScrollView).last,
          matching:find.byType(Scrollable),
        ).first;
        final tile=find.widgetWithText(CheckboxListTile,location.name);
        // Selection chips change the sliver header height. Start each search
        // from the top so a target above the previous offset is not skipped.
        final pickerState=tester.state<ScrollableState>(pickerList);
        while(pickerState.position.pixels>pickerState.position.minScrollExtent+1){
          final before=pickerState.position.pixels;
          await tester.drag(pickerList,const Offset(0,240));
          await tester.pumpAndSettle();
          expect(pickerState.position.pixels,lessThan(before),
            reason:'The picker must scroll back toward its first location');
        }
        await tester.scrollUntilVisible(tile,60,scrollable:pickerList);
        await Scrollable.ensureVisible(tester.element(tile),alignment:.5);
        await tester.pumpAndSettle();
        debugPrint('[xix-native] picker query="Craiova" '
          'resultTiles=${tile.evaluate().length} '
          'listScrollables=${find.descendant(of:find.byType(CustomScrollView).last,matching:find.byType(Scrollable)).evaluate().length}');
        expect(tile,findsOneWidget,
          reason:'The open/active fixture location "${location.name}" must remain present under the Craiova filter and after scrolling the Graph picker');
        expect(tile.hitTestable(),findsOneWidget,
          reason:'The location row must be clear of the dialog action bar before it is tapped');
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      for(var index=0;index<graphLocations.length;index++){
        expect(find.widgetWithText(Chip,'${index+1}. ${graphLocations[index].name}'),findsOneWidget,
          reason:'Every selected location must remain visible in order before the Graph is finalized');
      }
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
      pendingScheduleWrite=null;
      final startGraphButton=find.text('START GRAFIC');
      expect(startGraphButton,findsOneWidget);
      await tester.ensureVisible(startGraphButton);
      await tester.pumpAndSettle();
      expect(startGraphButton.hitTestable(),findsOneWidget,
        reason:'START GRAFIC must be visible before the native test taps it');
      await tester.tap(startGraphButton);
      await tester.pumpAndSettle();
      final endpointFields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextField));
      expect(endpointFields,findsNWidgets(2));
      await tester.enterText(endpointFields.at(0),'Punct plecare test');
      await tester.enterText(endpointFields.at(1),'Punct final test');
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull,
        reason:'Program START endpoint inputs must remain scrollable above the keyboard');
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsNothing,
        reason:'Program START must dismiss its endpoint dialog before persistence completes');
      expect(tester.takeException(),isNull,
        reason:'Program START must not overflow while resolving the route endpoints');
      expect(pendingScheduleWrite,isNotNull,reason:'Program START must persist after both endpoints geocode');
      await pendingScheduleWrite!.timeout(const Duration(seconds:30));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsNothing,
        reason:'Persisting Program START must not leave a modal dialog over the graph');
      expect(tester.takeException(),isNull,
        reason:'Persisted Program START must leave a valid graph layout');
      schedule=schedules.single;
      items=schedule.items;
      expect(geocodedProgramQueries,['Punct plecare test','Punct final test']);
      expect(schedule.started,true);
      expect(schedule.departureLatitude,44.31);
      expect(schedule.returnLongitude,23.81);
      final startedGraph=await db.collection('schedules').doc(schedule.id).get(const GetOptions(source:Source.server));
      expect(startedGraph.metadata.isFromCache,false);
      expect(startedGraph.metadata.hasPendingWrites,false);
      expect(startedGraph.data()!['started'],true);
      expect(startedGraph.data()!['departureName'],'Punct plecare test');
      expect(startedGraph.data()!['departureLatitude'],44.31);
      expect(startedGraph.data()!['returnName'],'Punct final test');
      expect(startedGraph.data()!['returnLongitude'],23.81);
      evidence['programStartThroughUi']={
        'geocodeQueries':geocodedProgramQueries,
        'serverPersistedEndpoints':true,
        'started':startedGraph.data()!['started'],
      };
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
      if(item == items.first) {
        final startedRecord=records.singleWhere((r)=>r.locationId==item.locationId);
        final current=(await db.collection('records').doc(startedRecord.id).get(const GetOptions(source:Source.server))).data()!;
        final replay={...current,'startedAt':Timestamp.fromDate(DateTime.now().add(const Duration(seconds:3)))};
        await saveRecordCompared(otherDb,startedRecord.id,replay);
        expect(replay['startedAt'],current['startedAt']);
        expect((await db.collection('activeRecordLocks').doc('craiova').get(const GetOptions(source:Source.server))).data()!['interventionId'],item.interventionId);
        evidence['stableStartReplay']=true;
      }
      await dashboard();
      final stop=find.byTooltip('Stop / ieși din locație');await tester.ensureVisible(stop);
      final finishSource=Map<String,dynamic>.from(records.singleWhere((r)=>r.locationId==item.locationId).writeBaseline!);
      await tester.tap(stop);await tester.tap(stop,warnIfMissed:false);await tester.pumpAndSettle();
      if(item.facadePlanned){
        expect(find.byType(AlertDialog),findsOneWidget);await tester.tap(find.text('DA'));
      }else{
        expect(find.byType(AlertDialog),findsNothing);
      }
      for(var n=0;n<60&&!records.any((r)=>r.locationId==item.locationId&&r.completed);n++){await tester.pump(const Duration(milliseconds:200));}
      expect(records.singleWhere((r)=>r.locationId==item.locationId).completed,true);
      if(item == items.first) {
        final finished=records.singleWhere((r)=>r.locationId==item.locationId);
        final current=(await db.collection('records').doc(finished.id).get(const GetOptions(source:Source.server))).data()!;
        final replay={...current,'finishedAt':Timestamp.fromDate(DateTime.now().add(const Duration(seconds:3)))};
        await saveRecordCompared(otherDb,finished.id,replay,expected:finishSource);
        expect(replay['finishedAt'],current['finishedAt']);
        expect((await db.collection('activeRecordLocks').doc('craiova').get(const GetOptions(source:Source.server))).exists,false);
        evidence['stableFinishReplay']=true;
      }
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
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    // Deliberately malformed legacy fixture uses the emulator owner API;
    // even Admin clients must now obey the reservation integrity rules.
    final legacySeed=await http.post(Uri.parse('http://10.0.2.2:8080/v1/projects/demo-andi-xix/databases/(default)/documents:commit'),
      headers:{'Authorization':'Bearer owner','Content-Type':'application/json'},
      body:jsonEncode({'writes':[{'update':{
        'name':'projects/demo-andi-xix/databases/(default)/documents/records/legacy-active-without-lock',
        'fields':{
          'teamId':{'stringValue':'craiova'},'locationId':{'stringValue':'legacy-active-room'},
          'locationNameSnapshot':{'stringValue':'Sală activă din versiunea veche'},
          'type':{'stringValue':'magic'},'status':{'stringValue':'running'},
          'startedAt':{'timestampValue':DateTime.now().toUtc().toIso8601String()},'finishedAt':{'nullValue':null},
        },
      }}]}));
    expect(legacySeed.statusCode,200);
    await otherAuth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    await expectLater(saveRecordCompared(db,'must-not-start-over-legacy-active',{
      'teamId':'craiova','locationId':'new-room','type':'magic','status':'running',
      'startedAt':Timestamp.fromDate(DateTime.now()),'finishedAt':null,
    }),throwsA(isA<StateError>().having((error)=>error.message,'message',contains('deja o intervenție pornită'))));
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    await otherDb.collection('records').doc('legacy-active-without-lock').delete();
    await otherAuth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    evidence['legacyActiveRecordWithoutLock']='server query rejected a new START before lock migration';
    final crossDeviceStarts = List.generate(2, (index) => <String, dynamic>{
      'teamId':'craiova','locationId':'cross-device-$index','type':'magic',
      'status':'running','startedAt':Timestamp.fromDate(DateTime.now()),'finishedAt':null,
    });
    final crossDeviceStartResults = await Future.wait([db, otherDb].asMap().entries.map((entry) async {
      try {
        await saveRecordCompared(entry.value, 'cross-device-start-${entry.key}', crossDeviceStarts[entry.key]);
        return true;
      } on StateError {
        return false;
      }
    }));
    expect(crossDeviceStartResults.where((accepted) => accepted), hasLength(1));
    final acceptedStartIndex = crossDeviceStartResults.indexOf(true);
    final acceptedStartId = 'cross-device-start-$acceptedStartIndex';
    final lockRef = db.collection('activeRecordLocks').doc('craiova');
    expect((await lockRef.get(const GetOptions(source:Source.server))).data()!['recordId'], acceptedStartId);
    final acceptedStart = crossDeviceStarts[acceptedStartIndex];
    final completedStart = {...acceptedStart,'status':'completed','finishedAt':Timestamp.fromDate(DateTime.now())};
    await saveRecordCompared(db, acceptedStartId, completedStart, expected: acceptedStart);
    expect((await lockRef.get(const GetOptions(source:Source.server))).exists, false);
    final afterFinishStart = {
      ...crossDeviceStarts[0], 'locationId':'after-finish',
    };
    await saveRecordCompared(db, 'cross-device-after-finish', afterFinishStart);
    expect((await lockRef.get(const GetOptions(source:Source.server))).data()!['recordId'], 'cross-device-after-finish');
    await saveRecordCompared(db, 'cross-device-after-finish', {
      ...afterFinishStart,'status':'completed','finishedAt':Timestamp.fromDate(DateTime.now()),
    }, expected: afterFinishStart);
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    await otherDb.collection('records').doc(acceptedStartId).delete();
    await otherDb.collection('records').doc('cross-device-start-${1-acceptedStartIndex}').delete();
    await otherDb.collection('records').doc('cross-device-after-finish').delete();
    await otherAuth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    expect((await lockRef.get(const GetOptions(source:Source.server))).exists, false);
    evidence['crossDeviceStartReservation']={
      'simultaneousDistinctIdsAccepted':crossDeviceStartResults.where((accepted) => accepted).length,
      'winner':acceptedStartId,'lockReleasedOnFinish':true,'newStartAfterFinish':'cross-device-after-finish',
    };
    await expectLater(saveRecordCompared(db,ref.id,{...beforeRace,'addressSnapshot':'stale'},expected:beforeRace),throwsA(isA<StateError>()));
    final latest=(await ref.get()).data()!;
    // The former merge-upsert path must not recreate a document deleted elsewhere.
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    final legacy=otherDb.collection('records').doc('deleted-legacy');
    await legacy.set({'teamId':'craiova','locationId':'legacy','type':'magic'});
    final legacyBefore=(await legacy.get()).data()!;await legacy.delete();
    await otherAuth.signInWithEmailAndPassword(email:'outsider@andi.test',password:'synthetic-only-123');
    await expectLater(otherDb.collection('records').doc(legacy.id).set(legacyBefore,SetOptions(merge:true)),throwsA(permissionDenied));
    await otherAuth.signInWithEmailAndPassword(email:'admin@andi.test',password:'synthetic-only-123');
    expect((await legacy.get(const GetOptions(source:Source.server))).exists,false);
    evidence['unauthorizedRecreate']='permission-denied; deleted record remains absent';
    await expectLater(saveRecordCompared(db,legacy.id,{...legacyBefore,'status':'running'},expected:legacyBefore),throwsA(isA<StateError>()));
    expect((await legacy.get()).exists,false);
    evidence['oldWriterWitness']='application compare-before-write denied recreating a deleted baseline';
    await legacy.set({...legacyBefore,'status':'completed',
      'startedAt':Timestamp.fromDate(DateTime(2026,10,14,8)),
      'finishedAt':Timestamp.fromDate(DateTime(2026,10,14,9)),
      'metadata':{'tags':['legacy',{'version':1}]}});
    final nestedLegacy=(await legacy.get()).data()!;
    await saveRecordCompared(db,legacy.id,{...nestedLegacy,'addressSnapshot':'nested-update'},expected:nestedLegacy);
    evidence['legacyAndDeletion']='legacy update passed; deleted baseline rejected';
    await legacy.delete();
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
    final offlineDesired=<String,dynamic>{
      'teamId':'craiova','locationId':'offline','status':'running',
      'startedAt':Timestamp.fromDate(DateTime(2026,10,16,2)),
      'finishedAt':null,
    };
    await db.disableNetwork();
    try {
      await expectLater(saveRecordCompared(db,'offline-attempt',offlineDesired),throwsA(isA<FirebaseException>()));
    } finally {
      await db.enableNetwork();
    }
    expect((await db.doc('records/offline-attempt').get(const GetOptions(source:Source.server))).exists,false);
    await saveRecordCompared(db,'offline-attempt',offlineDesired);
    final reconnected=await db.doc('records/offline-attempt').get(const GetOptions(source:Source.server));
    expect(reconnected.exists,true);
    expect(reconnected.metadata.isFromCache,false);
    expect(reconnected.metadata.hasPendingWrites,false);
    expect(reconnected.data()!['status'],'running');
    final completedOffline={...reconnected.data()!,'status':'completed',
      'finishedAt':Timestamp.fromDate(DateTime(2026,10,16,2,25))};
    await saveRecordCompared(db,'offline-attempt',completedOffline,expected:reconnected.data());
    expect((await db.doc('activeRecordLocks/craiova').get(const GetOptions(source:Source.server))).exists,false);
    evidence['offlineBeforeStart']='offline write rejected without queue; explicit server-backed retry after reconnect persisted once and released its lock on completion';
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
    // Mount the real application and let HomePage supply the correction
    // callback and permission result. Grants exist only in the demo emulator.
    final uiPermissions=['viewDashboard','viewProgram','editProgram','viewCentralizer','editCentralizer','viewOwnDecont'];
    // The former login migration deleted definitions and cleared every member
    // assignment when a marker was missing. Exercise the production guard
    // against authoritative emulator state without altering those assignments.
    final migrationProfileBefore=(await otherDb.doc('users/$uid').get(const GetOptions(source:Source.server))).data()!;
    final migrationFunctionsBefore={for(final d in (await otherDb.collection('functions').get(const GetOptions(source:Source.server))).docs)d.id:d.data()};
    expect(await functionBadgeMigrationReady(otherDb),false);
    expect((await otherDb.doc('users/$uid').get(const GetOptions(source:Source.server))).data(),migrationProfileBefore);
    expect({for(final d in (await otherDb.collection('functions').get(const GetOptions(source:Source.server))).docs)d.id:d.data()},migrationFunctionsBefore);
    evidence['nonDestructiveFunctionMigration']=true;
    await otherDb.doc('functions/xix-ui-editor').set({
      'name':'Synthetic UI editor','active':true,'permissions':uiPermissions,
    });
    await otherDb.doc('users/$uid').update({'functionIds':['xix-ui-editor']});
    await tester.pumpWidget(const app.AndiCarpetaApp());
    Future<void> pumpUntil(bool Function() ready,String reason) async {
      for(var n=0;n<120&&!ready();n++){
        await tester.pump(const Duration(milliseconds:200));
      }
      expect(ready(),true,reason:reason);
    }
    final centralNav=find.text('Central.');
    final centralWideNav=find.text('Centralizator');
    await pumpUntil(()=>centralNav.evaluate().isNotEmpty||centralWideNav.evaluate().isNotEmpty,
      'Actual HomePage must load the synthetic editor navigation');
    await tester.tap(centralNav.evaluate().isNotEmpty?centralNav:centralWideNav);
    await tester.pumpAndSettle();
    final mainCentralizer=find.byType(app.CentralizerPage);
    await pumpUntil((){
      if(mainCentralizer.evaluate().isEmpty)return false;
      final page=tester.widget<app.CentralizerPage>(mainCentralizer);
      return page.canEditCentralizer&&page.records.any((record)=>record.id==ref.id);
    },'Actual HomePage must grant correction and load the server record');
    final mainSearch=find.descendant(of:mainCentralizer,matching:find.byType(TextField));
    await tester.enterText(mainSearch,'Craiova 01');await tester.pumpAndSettle();
    final mainLocation=find.widgetWithText(ExpansionTile,'Craiova 01');
    await tester.ensureVisible(mainLocation);await tester.tap(mainLocation);
    await tester.pumpAndSettle();
    Future<void> correctFromHome(String newFinish) async {
      // The first record is the overnight scenario edited above. Identify its
      // ListTile by its unique START time, then target the permission-gated
      // correction action inside that row. The location has another execution,
      // so selecting only by location would be ambiguous.
      final recordStart=find.textContaining('23:55');
      expect(recordStart,findsOneWidget);
      final recordRow=find.ancestor(of:recordStart,matching:find.byType(ListTile));
      expect(recordRow,findsOneWidget);
      final edit=find.descendant(
        of:recordRow,
        matching:find.byTooltip('Corectează data, orele și fațada'),
      );
      expect(edit,findsOneWidget);
      await tester.ensureVisible(edit);await tester.tap(edit);await tester.pumpAndSettle();
      final fields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextField));
      await tester.enterText(fields.at(1),newFinish);await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvează'));await tester.tap(find.text('Salvează'));
      await pumpUntil(()=>find.text('Data, orele și fațada au fost salvate.').evaluate().isNotEmpty,
        'HomePage correction must report server-confirmed success');
      await tester.pumpAndSettle();
      final server=await ref.get(const GetOptions(source:Source.server));
      expect(server.metadata.isFromCache,false);expect(server.metadata.hasPendingWrites,false);
      expect((server.data()!['finishedAt'] as Timestamp).toDate(),DateTime(2026,10,16,0,int.parse(newFinish.split(':')[1])));
      expect(server.data()!['facadeDone'],true);
      ScaffoldMessenger.of(tester.element(mainCentralizer)).clearSnackBars();
      await tester.pumpAndSettle();
    }
    await correctFromHome('00:21');
    await correctFromHome('00:20');
    await otherDb.doc('functions/xix-ui-editor').update({
      'permissions':uiPermissions.where((permission)=>permission!='editCentralizer').toList(),
    });
    await pumpUntil(()=>!tester.widget<app.CentralizerPage>(mainCentralizer).canEditCentralizer,
      'HomePage must remove correction permission after the function changes');
    expect(find.byTooltip('Corectează data, orele și fațada'),findsNothing);
    expect((await ref.get(const GetOptions(source:Source.server))).data()!['finishedAt'],night['finishedAt']);

    final receiptSettlement=app.TravelSettlement(
      id:'xix-receipt-settlement',teamId:'craiova',name:'Decont E2E',
      startDate:DateTime(2026,10,1),managerId:uid,
    );
    await db.collection('settlements').doc(receiptSettlement.id).set({
      'teamId':receiptSettlement.teamId,'name':receiptSettlement.name,
      'startDate':Timestamp.fromDate(receiptSettlement.startDate),
      'managerId':uid,'closed':false,
    });
    final expenseSettings=app.AppSettings()..learning['ocr']!.enabled=true;
    final receiptBytes=Uint8List.fromList(img.encodePng(img.Image(width:2,height:2)));
    // Keep HomePage mounted: its real financial listener and production
    // persistence callback own the receipt round trip. Only media/OCR inputs
    // are controlled; there is no parallel test implementation of saving.
    final decontNav=find.byWidgetPredicate((widget)=>
      widget is NavigationDestination && widget.label=='Decont');
    expect(decontNav,findsOneWidget);
    await tester.tap(decontNav);
    await tester.pumpAndSettle();
    final homeExpenseFinder=find.byType(app.ExpensePage);
    await pumpUntil(()=>homeExpenseFinder.evaluate().isNotEmpty &&
      tester.widget<app.ExpensePage>(homeExpenseFinder).settlements
        .any((entry)=>entry.id==receiptSettlement.id),
      'HomePage must load the selected settlement from its financial subscription');
    final moneyCard=find.text('Primit la plecare');
    await tester.ensureVisible(moneyCard);await tester.tap(moneyCard);await tester.pumpAndSettle();
    expect(find.text('Adaugă sumă primită la plecare'),findsOneWidget);
    final moneyFields=find.descendant(of:find.byType(AlertDialog),matching:find.byType(TextFormField));
    await tester.enterText(moneyFields.first,'NaN');await tester.enterText(moneyFields.last,'Sursă sintetică');
    await tester.tap(find.text('Adaugă'));await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsOneWidget);
    expect((await db.collection('settlements').doc(receiptSettlement.id).get(const GetOptions(source:Source.server))).data()!['receivedEntries'],isNull);
    await tester.enterText(moneyFields.first,'12,34');await tester.tap(find.text('Adaugă'));await tester.pumpAndSettle();
    await pumpUntil(()=>tester.widget<app.ExpensePage>(homeExpenseFinder).settlements
      .firstWhere((s)=>s.id==receiptSettlement.id).totalReceived==12.34,
      'Home settlement listener must confirm the received-money amount');
    final moneyServer=(await db.collection('settlements').doc(receiptSettlement.id).get(const GetOptions(source:Source.server))).data()!;
    expect((moneyServer['receivedEntries'] as List).single['amount'],12.34);
    expect(moneyServer['receivedDeparture'],12.34);
    evidence['receivedMoneyThroughHome']={'rejectedNonFinite':true,'serverPersisted':12.34};
    final homeExpense=tester.widget<app.ExpensePage>(homeExpenseFinder);
    expect(homeExpense.canEditOwnDecont,true);
    expect(homeExpense.canEditTeam('craiova'),true);
    final expensePageExpenses=homeExpense.expenses;
    expect(expensePageExpenses,isEmpty);
    final expenseNavigator=Navigator.of(tester.element(homeExpenseFinder));
    final expenseRoute=expenseNavigator.push<void>(MaterialPageRoute(builder:(_)=>
      Scaffold(body:app.ExpensePage(
      currentUser:homeExpense.currentUser,
      teams:homeExpense.teams,users:homeExpense.users,
      expenses:expensePageExpenses,perDiems:homeExpense.perDiems,
      finances:homeExpense.finances,
      settlements:homeExpense.settlements,settings:expenseSettings,
      canEditTeam:homeExpense.canEditTeam,isAdmin:homeExpense.isAdmin,
      canEditOwnDecont:homeExpense.canEditOwnDecont,
      canViewOtherDecont:homeExpense.canViewOtherDecont,
      onChanged:homeExpense.onChanged,
      notifyUser:homeExpense.notifyUser,log:homeExpense.log,
      pickDocumentImage:({allowNoImage=false}) async => XFile.fromData(
        receiptBytes,name:'synthetic-receipt.png',path:'synthetic-receipt.png',
      ),
      recognizeExpenseText:(bytes,{path}) async {
        expect(bytes,isNotEmpty);
        return 'SC EXEMPLU SRL\nBON FISCAL NR 12345\nDATA 05.10.2026\nTOTAL 148,75 LEI';
      },
      saveExpense:homeExpense.saveExpense,
      savePerDiem:homeExpense.savePerDiem,
      saveFinance:homeExpense.saveFinance,
      saveSettlement:homeExpense.saveSettlement,
    ))));
    await tester.pumpAndSettle();
    final scanReceipt=find.text('Scanează bon / factură');
    await tester.ensureVisible(scanReceipt);
    expect(scanReceipt.hitTestable(),findsOneWidget,
      reason:'receipt scan must be visible and tappable before exercising OCR');
    await tester.tap(scanReceipt);
    await tester.pumpAndSettle();
    expect(find.text('Verifică datele citite prin OCR'),findsOneWidget);
    final receiptFields=find.descendant(
      of:find.byType(AlertDialog),matching:find.byType(TextFormField),
    );
    expect(receiptFields,findsNWidgets(3),reason:'OCR review must expose document number, supplier, and amount fields');
    await tester.enterText(receiptFields.at(2),'150,25');
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();
    await pumpUntil(()=>expensePageExpenses.length==1,
      'HomePage financial subscription must reload the persisted receipt');
    expect(expensePageExpenses,hasLength(1));
    final savedExpense=await db.collection('expenses').doc(expensePageExpenses.single.id)
      .get(const GetOptions(source:Source.server));
    expect(savedExpense.metadata.isFromCache,false);
    expect(savedExpense.metadata.hasPendingWrites,false);
    expect(savedExpense.data()!['teamId'],'craiova');
    expect(savedExpense.data()!['settlementId'],receiptSettlement.id);
    expect(savedExpense.data()!['documentNumber'],'12345');
    expect(savedExpense.data()!['amount'],150.25,reason:'manual correction must persist the corrected OCR amount');
    expect(savedExpense.data()!['confirmed'],true);
    final savedExpenseData=savedExpense.data()!;
    final serverExpense=app.Expense(
      id:savedExpense.id,
      teamId:savedExpenseData['teamId'] as String,
      settlementId:savedExpenseData['settlementId'] as String,
      category:savedExpenseData['category'] as String,
      description:savedExpenseData['description'] as String,
      amount:(savedExpenseData['amount'] as num).toDouble(),
      date:(savedExpenseData['date'] as Timestamp).toDate(),
      documentType:app.ExpenseDocumentType.values.byName(savedExpenseData['documentType'] as String),
      documentNumber:savedExpenseData['documentNumber'] as String,
      supplier:savedExpenseData['supplier'] as String,
      confirmed:savedExpenseData['confirmed'] as bool,
    );
    final decontPdf=await app.buildDecontPdfBytes(
      team:app.Team(id:'craiova',name:'Craiova',members:[uid]),
      users:[app.AppUser(id:uid,name:'Editor',role:app.UserRole.member)],
      expenses:[serverExpense],perDiems:[],
      finance:app.TeamFinance(teamId:'craiova',managerId:uid,receivedDeparture:200),
      settlement:homeExpense.settlements.firstWhere((s)=>s.id==receiptSettlement.id),
    );
    final evidenceDir=Directory('/data/user/0/com.example.andi_carpeta/files/xix-evidence')..createSync(recursive:true);
    File('${evidenceDir.path}/decont-flow.pdf').writeAsBytesSync(decontPdf);
    evidence['expenseOcrThroughUi']={
      'controlledRecognition':true,'manualCorrection':150.25,
      'settlementId':receiptSettlement.id,'serverPersisted':true,
      'decontPdfBuiltFromServerExpense':true,'homePagePersistence':true,
    };
    expenseNavigator.pop();
    await expenseRoute;
    await tester.pumpAndSettle();
    final reloadedReceipt=find.widgetWithText(ListTile,'Bon Fiscal nr 12345');
    await tester.ensureVisible(reloadedReceipt);
    expect(find.descendant(of:reloadedReceipt,matching:find.textContaining('150.25 lei')),
      findsOneWidget,reason:'The real HomePage Decont must display the reloaded corrected receipt amount');
    final programNav=find.text('Grafic de lucru');
    final shortProgramNav=find.text('Grafic');
    await tester.tap(shortProgramNav.evaluate().isNotEmpty?shortProgramNav:programNav.first);
    await pumpUntil(()=>find.byType(app.ProgramPage).evaluate().isNotEmpty,'Home Program must load');
    await tester.pumpAndSettle();
    final programPage=tester.widget<app.ProgramPage>(find.byType(app.ProgramPage));
    expect(programPage.closeGraph,isNotNull);
    final stopGraph=find.text('STOP GRAFIC');
    await tester.ensureVisible(stopGraph);await tester.tap(stopGraph);await tester.pumpAndSettle();
    expect(find.text('STOP Grafic de lucru'),findsOneWidget);
    await tester.tap(find.text('STOP'));await tester.pumpAndSettle();
    await pumpUntil(()=>tester.widget<app.ProgramPage>(find.byType(app.ProgramPage)).schedules
      .where((d)=>d.graphId==schedule.graphId).every((d)=>d.closed),'Server STOP must reach the Home subscription');
    final closedDay=await db.collection('schedules').doc(schedule.id).get(const GetOptions(source:Source.server));
    expect(closedDay.data()!['closed'],true);
    final receiptId=closedDay.data()!['closeReceiptId'];
    final receiptDoc=await db.collection('graphClosures').doc(receiptId as String).get(const GetOptions(source:Source.server));
    expect(receiptDoc.data()!['interventionCount'],11);
    final replayOperation=<String,dynamic>{'teamId':'craiova','graphId':schedule.graphId,
      'requestId':receiptDoc.data()!['requestId'],
      'days':[{'id':schedule.id,'writeToken':schedule.writeToken}]};
    Future<String> sendClosure(Map<String,dynamic> operation) => requestGraphClosure(
      endpoint:Uri.parse('http://10.0.2.2:5001/demo-andi-xix/europe-central2/closeProgramGraph'),
      getIdToken:() async=>auth.currentUser?.getIdToken(),
      post:(uri,{headers,body})=>http.post(uri,headers:headers,body:body),
      operation:operation);
    // Persist to actual Android secure storage, lose the ACK after a real
    // Functions receipt, then reconstruct the journal as after process loss.
    const stopStorage=FlutterSecureStorage();
    GraphClosureJournal newJournal()=>GraphClosureJournal(
      read:(key)=>stopStorage.read(key:key),
      write:(key,value)=>stopStorage.write(key:key,value:value),
      remove:(key)=>stopStorage.delete(key:key));
    String? persistedStopKey;
    await expectLater(newJournal().close(projectId:Firebase.app().options.projectId,
      userId:uid,operation:replayOperation,send:(operation) async {
        expect(await sendClosure(operation),receiptId);
        final saved=await stopStorage.readAll();
        persistedStopKey=saved.keys.singleWhere((key)=>key.startsWith('graph-stop-v1-'));
        throw TimeoutException('Injected ACK loss after actual server receipt');
      }),throwsA(isA<TimeoutException>()));
    final closureReplay=await newJournal().close(projectId:Firebase.app().options.projectId,
      userId:uid,operation:{...replayOperation,'requestId':'must-not-replace-original',
        'days':[{'id':schedule.id,'writeToken':closedDay.data()!['writeToken']}]},
      send:sendClosure);
    expect(closureReplay,receiptId);
    expect(await stopStorage.read(key:persistedStopKey!),isNull);
    evidence['durableStopReplay']=true;
    evidence['atomicGraphStopThroughHome']={'serverPersisted':true,'receiptReplay':true,'interventions':11};
    await otherDb.doc('users/$uid').update({'functionIds':['worker']});
    await otherDb.doc('functions/xix-ui-editor').delete();
    evidence['homeCorrectionThroughUi']='actual app root, HomePage callback, server-confirmed edit and revert, UI permission removal';
    // Switch the actual default Auth instance under the actual application
    // navigator, including a mounted private route owned by the editor.
    final editorUid=auth.currentUser!.uid;
    final homeContext=tester.element(find.byType(app.HomePage));
    Navigator.of(homeContext).push(MaterialPageRoute<void>(builder:(_)=>
      Scaffold(body:Text('Private editor route $editorUid'))));
    await tester.pumpAndSettle();expect(find.text('Private editor route $editorUid'),findsOneWidget);
    final outsiderSession=await auth.signInWithEmailAndPassword(email:'outsider@andi.test',password:'synthetic-only-123');
    await pumpUntil(()=>find.text('Private editor route $editorUid').evaluate().isEmpty &&
      find.byType(app.HomePage).evaluate().isNotEmpty &&
      tester.widget<app.HomePage>(find.byType(app.HomePage)).profile.uid==outsiderSession.user!.uid,
      'Actual Firebase Auth UID switch must remove the editor private route and profile');
    await auth.signInWithEmailAndPassword(email:'editor@andi.test',password:'synthetic-only-123');
    await pumpUntil(()=>find.byType(app.HomePage).evaluate().isNotEmpty &&
      tester.widget<app.HomePage>(find.byType(app.HomePage)).profile.uid==editorUid,
      'Editor UID must return with a fresh Home scope');
    expect(find.text('Private editor route $editorUid'),findsNothing);
    evidence['authUidIsolationThroughMain']=true;
    evidence['completed']=true;
    File('${out.path}/observations.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
    // Wait for the host to confirm that every native artifact was copied.
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
