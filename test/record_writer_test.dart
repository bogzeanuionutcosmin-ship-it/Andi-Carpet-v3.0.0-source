import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:andi_carpeta/operations/record_writer.dart';

void main() {
  test('legacy optional defaults remain compatible', () {
    final legacy=<String,dynamic>{'teamId':'t','locationId':'l','type':'magic'};
    expect(recordPayloadMatches(legacy,{...legacy,'facadeDone':false,'startedAt':null}),true);
    expect(recordPayloadMatches(legacy,{...legacy,'facadeDone':true}),false);
  });
  test('independently decoded nested legacy metadata compares by value', () {
    Map<String,dynamic> data()=>{'teamId':'t','meta':{'items':[{'at':Timestamp(1,0),'tags':['one',null]}]}};
    expect(recordPayloadMatches(data(),data()),true);
    final changed=data();(changed['meta'] as Map)['items']=[{'at':Timestamp(2,0)}];
    expect(recordPayloadMatches(data(),changed),false);
  });
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
