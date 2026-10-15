import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'support/admin_ui_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/admin_backup_fixture.dart';
import 'support/home_maintenance_fixture.dart';

void main(){
  late FirebasePlatform original;late NoFirebaseAccess sdk;
  final unexpectedHttp=<String>[];var clientCreations=0;
  final noNetwork=MockClient((request)async{
    unexpectedHttp.add(request.url.toString());
    throw StateError('Unexpected HTTP in synthetic restore fixture');
  });
  setUp((){original=FirebasePlatform.instance;sdk=NoFirebaseAccess();FirebasePlatform.instance=sdk;});
  tearDown((){expect(sdk.attempts,isEmpty);FirebasePlatform.instance=original;});
  tearDownAll((){
    expect(clientCreations,1,reason:'Actual Admin dashboard creates one shared Mapbox client');
    expect(unexpectedHttp,isEmpty,reason:'Restore tests must never request an external service');
    noNetwork.close();
  });
  for(final collection in ['finance','settlements','settlements/trip/financialIntents']){
    testWidgets('manual mixed legacy backup refuses $collection before any unrelated write',(t)=>http.runWithClient(()async{
      final h=AdminBackupHarness();
      h.files.file({'format':'AndiCarpetaBackupV1','collections':{
        'locations':{'room':{'name':'Stale'}},collection:<String,Object?>{},
      }});
      await h.mount(t);
      final button=find.widgetWithText(OutlinedButton,'Restaurează backup');
      await t.ensureVisible(button);await t.tap(button);await t.pumpAndSettle();
      expect(find.textContaining('Backup-ul financiar necesită un manifest'),findsOneWidget);
      expect(find.widgetWithText(FilledButton,'Restaurează'),findsNothing);
      h.expectNoCommand();await h.finish(t);
    },(){clientCreations++;return noNetwork;}));
    testWidgets('automatic mixed snapshot refuses $collection after global preflight with zero mutations',(t)=>http.runWithClient(()async{
      final h=AdminBackupHarness();
      h.db.setDocument('backups/snapshot',{'status':'complete'});
      h.db.setQuery('backups/snapshot/items',[
        MaintenanceDoc(h.db,'backups/snapshot/items/first',{'collection':'locations','documentId':'room','data':{'name':'Stale'}}),
        MaintenanceDoc(h.db,'backups/snapshot/items/last',{'collection':collection,'documentId':'trip','data':{'revision':0}}),
      ]);
      await h.mount(t,latest:{'status':'complete'});
      final button=find.widgetWithText(OutlinedButton,'Restaurează');
      await t.ensureVisible(button);await t.tap(button);await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton,'Restaurează'));await t.pumpAndSettle();
      expect(find.textContaining('Backup-ul financiar necesită un manifest'),findsOneWidget);
      expect(h.db.trace,['get:backups/snapshot','get:backups/snapshot/items']);
      expect(h.db.commitAttempts,isEmpty);expect(h.db.directWrites,isEmpty);expect(h.ui.logs,isEmpty);
      await h.finish(t);
    },(){clientCreations++;return noNetwork;}));
  }
}
