import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/operations/record_writer.dart';

// Only the recovery path is simulated: the transaction bridge rejects and the
// following server read may still contain local latency-compensated writes.
class RecoveryDatabase implements FirebaseFirestore {
  RecoveryDatabase(this.recovered);
  final DocumentSnapshot<Map<String, dynamic>> recovered;
  final failure = FirebaseException(plugin: 'cloud_firestore', code: 'unknown');
  int reads = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) return RecoveryCollection(this);
    if (invocation.memberName == #runTransaction) return Future<Never>.error(failure);
    return super.noSuchMethod(invocation);
  }
}

class RecoveryCollection implements CollectionReference<Map<String, dynamic>> {
  RecoveryCollection(this.db);
  final RecoveryDatabase db;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #doc) return RecoveryDocument(db);
    return super.noSuchMethod(invocation);
  }
}

class RecoveryDocument implements DocumentReference<Map<String, dynamic>> {
  RecoveryDocument(this.db);
  final RecoveryDatabase db;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      db.reads++;
      return Future<DocumentSnapshot<Map<String, dynamic>>>.value(
        db.reads == 1 ? RecoverySnapshot(false, false) : db.recovered);
    }
    return super.noSuchMethod(invocation);
  }
}

class RecoveryMetadata implements SnapshotMetadata {
  RecoveryMetadata(this.hasPendingWrites, this.isFromCache);
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecoverySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  RecoverySnapshot(bool pending, bool cached)
      : metadata = RecoveryMetadata(pending, cached);
  @override
  final SnapshotMetadata metadata;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => {'teamId': 'team', 'locationId': 'room'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final flags in [(true, false), (false, true), (true, true)]) {
    test('recovery cannot confirm local/cache state $flags', () async {
      final db = RecoveryDatabase(RecoverySnapshot(flags.$1, flags.$2));
      await expectLater(
        saveRecordCompared(db, 'record', {'teamId': 'team', 'locationId': 'room'}),
        throwsA(same(db.failure)),
      );
      expect(db.reads, 2);
    });
  }
  test('authoritative identical recovery still accepts lost acknowledgement', () async {
    final db = RecoveryDatabase(RecoverySnapshot(false, false));
    await saveRecordCompared(db, 'record', {'teamId': 'team', 'locationId': 'room'});
    expect(db.reads, 2);
  });
}
