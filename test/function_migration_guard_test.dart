import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/home/function_migration_guard.dart';

class GuardDatabase implements FirebaseFirestore {
  GuardDatabase(this.snapshot);
  final GuardSnapshot snapshot;
  int reads=0;
  @override dynamic noSuchMethod(Invocation i) {
    if(i.memberName==#collection){expect(i.positionalArguments.single,'meta');return GuardCollection(this);}
    throw StateError('Unexpected database mutation or access: ${i.memberName}');
  }
}
class GuardCollection implements CollectionReference<Map<String,dynamic>> {
  GuardCollection(this.db);final GuardDatabase db;
  @override dynamic noSuchMethod(Invocation i) {
    if(i.memberName==#doc){expect(i.positionalArguments.single,'uiSettings');return GuardDocument(db);}
    throw StateError('Unexpected collection access: ${i.memberName}');
  }
}
class GuardDocument implements DocumentReference<Map<String,dynamic>> {
  GuardDocument(this.db);final GuardDatabase db;
  @override dynamic noSuchMethod(Invocation i) {
    if(i.memberName==#get){
      expect((i.positionalArguments.single as GetOptions).source,Source.server);db.reads++;
      return Future<DocumentSnapshot<Map<String,dynamic>>>.value(db.snapshot);
    }
    throw StateError('Migration must not write: ${i.memberName}');
  }
}
class GuardMetadata implements SnapshotMetadata {
  GuardMetadata(this.isFromCache,this.hasPendingWrites);
  @override final bool isFromCache;
  @override final bool hasPendingWrites;
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class GuardSnapshot implements DocumentSnapshot<Map<String,dynamic>> {
  GuardSnapshot(this.version,{bool cached=false,bool pending=false}):metadata=GuardMetadata(cached,pending);
  final String? version;
  @override final SnapshotMetadata metadata;
  @override Map<String,dynamic> data()=>{if(version!=null)'functionSystemVersion':version};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
void main(){
  test('missing and legacy migration markers preserve all business data',()async{
    for(final version in [null,'legacy','badge_v2']){
      final db=GuardDatabase(GuardSnapshot(version));
      expect(await functionBadgeMigrationReady(db),version=='badge_v2');expect(db.reads,1);
    }
  });
  test('cache or pending writes cannot certify migration completion',()async{
    for(final snapshot in [GuardSnapshot('badge_v2',cached:true),GuardSnapshot('badge_v2',pending:true)]){
      await expectLater(functionBadgeMigrationReady(GuardDatabase(snapshot)),throwsA(isA<StateError>()));
    }
  });
}
