import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/operations/record_writer.dart';
void main(){
  test('revoked Home session cannot begin any backend read or write', () async {
    // Session is checked before touching db, so no initialized Firebase app is needed.
    final db=_NoDatabaseAccess();
    await expectLater(saveRecordCompared(db, 'record',
      {'teamId':'team'}, canContinue:()=>false), throwsA(isA<StateError>().having((e)=>e.message,'message',contains('Sesiunea'))));
    expect(db.accessed,false);
  });

}

class _NoDatabaseAccess implements FirebaseFirestore {
  bool accessed=false;
  @override dynamic noSuchMethod(Invocation invocation) {
    accessed=true;throw ArgumentError('Backend accessed after session replacement');
  }
}
