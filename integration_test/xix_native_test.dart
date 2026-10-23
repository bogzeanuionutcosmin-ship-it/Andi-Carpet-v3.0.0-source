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
    final startTrace=<String>[];
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
          await tester.drag(pi