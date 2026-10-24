import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/centralizer/correction_writer.dart';

// Simulate the observed native false completion: the bridge completes but no
// confirmed server mutation exists. These doubles do not test CAS semantics;
// the native UI flow exercises the actual transaction and backend rules.
class AuthorityDb implements FirebaseFirestore {
  AuthorityDb(this.snapshots, {this.readError});
  final List<AuthoritySnapshot> snapshots;
  final Object? readError;
  int reads = 0;
  int transactions = 0;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #collection) return AuthorityCollection(this);
    if (call.memberName == #runTransaction) {
      transactions++;
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

class AuthorityCollection implements CollectionReference<Map<String, dynamic>> {
  AuthorityCollection(this.db);
  final AuthorityDb db;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #doc) return AuthorityDocument(db);
    return super.noSuchMethod(call);
  }
}

class AuthorityDocument implements DocumentReference<Map<String, dynamic>> {
  AuthorityDocument(this.db);
  final AuthorityDb db;
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #get) {
      expect((call.positionalArguments.single as GetOptions).source, Source.server);
      if (db.readError != null) return Future<Never>.error(db.readError!);
      return Future<DocumentSnapshot<Map<String, dynamic>>>.value(db.snapshots[db.reads++]);
    }
    return super.noSuchMethod(call);
  }
}

class AuthorityMetadata implements SnapshotMetadata {
  AuthorityMetadata(this.isFromCache, this.hasPendingWrites);
  @override final bool isFromCache;
  @override final bool hasPendingWrites;
  @override dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class AuthoritySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  AuthoritySnapshot(this.value, {bool cached=false, bool pending=false})
      : metadata=AuthorityMetadata(cached,pending);
  final Map<String,dynamic>? value;
  @override final SnapshotMetadata metadata;
  @override bool get exists => value != null;
  @override Map<String,dynamic>? data() => value;
  @override dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

void main() {
  final baseline=<String,dynamic>{'teamId':'craiova','facadeDone':false};
  final desired=<String,dynamic>{...baseline,'facadeDone':true};
  Future<void> correct(AuthorityDb db) => correctCentralizerRecordCompared(db,'record',
    expected:baseline,changes:{'facadeDone':true,'updatedAt':FieldValue.serverTimestamp()});

  for(final flags in [(true,false),(false,true),(true,true)]) {
    test('preflight refuses non-authoritative snapshot $flags', () async {
      final db=AuthorityDb([AuthoritySnapshot(baseline,cached:flags.$1,pending:flags.$2)]);
      await expectLater(correct(db),throwsA(isA<StateError>()));
      expect(db.transactions,0);
    });
  }
  test('unavailable server preserves error and prepares no transaction', () async {
    final error=FirebaseException(plugin:'cloud_firestore',code:'unavailable');
    final db=AuthorityDb([],readError:error);
    await expectLater(correct(db),throwsA(same(error)));
    expect(db.transactions,0);
  });
  for(final observed in [
    AuthoritySnapshot(baseline),AuthoritySnapshot(null),
    AuthoritySnapshot(desired,cached:true),AuthoritySnapshot(desired,pending:true),
  ]) {
    test('bridge completion cannot confirm stale, absent or pending state ${observed.value} ${observed.metadata.isFromCache} ${observed.metadata.hasPendingWrites}', () async {
      final db=AuthorityDb([AuthoritySnapshot(baseline),observed]);
      await expectLater(correct(db),throwsA(isA<StateError>()));
      expect(db.transactions,1);expect(db.reads,2);
    });
  }
  test('authoritative changed fields confirm while preserving unrelated fields', () async {
    final db=AuthorityDb([AuthoritySnapshot(baseline),AuthoritySnapshot({...desired,'legacy':{'value':1}})]);
    await correct(db);
    expect(db.transactions,1);expect(db.reads,2);
  });
}
