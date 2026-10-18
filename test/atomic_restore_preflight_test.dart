import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/operations/atomic_restore.dart';

class NoDatabaseAccess implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected database access');
}

void main() {
  test('oversized restore is rejected before database inventory', () async {
    await expectLater(restoreAtomically(NoDatabaseAccess(), {
      'records': {for(var i=0;i<401;i++)'r$i':{'teamId':'synthetic'}},
    }, source:'test'), throwsA(isA<StateError>().having((e)=>e.message,'reason',contains('prea mare'))));
  });
  test('empty restore cannot write successful metadata', () async {
    await expectLater(restoreAtomically(NoDatabaseAccess(), {}, source:'test'),throwsA(isA<FormatException>()));
  });
  test('invalid collection or document path fails before database access', () async {
    for(final data in <Map<String,Map<String,dynamic>>>[
      {'users':{'forbidden':{}}}, {'records':{'bad/path':{}}},
    ]) {
      await expectLater(restoreAtomically(NoDatabaseAccess(),data,source:'test'),throwsA(isA<FormatException>()));
    }
  });
}
