import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class SessionUser extends Fake implements User {
  @override
  final String uid;
  @override
  String get email => '$uid@example.test';
  SessionUser(this.uid);
}

class SessionSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  @override
  final bool exists;
  SessionSnapshot(this.value, {this.exists = true});
  @override
  Map<String, dynamic>? data() => value;
}

class SessionAuth extends Fake implements FirebaseAuth {
  User? user = SessionUser('a');
  final events = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  void switchTo(String? uid) {
    user = uid == null ? null : SessionUser(uid);
    events.add(user);
  }
}

class SessionFirestore extends Fake implements FirebaseFirestore {
  final streams = <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  final listeners = <String, List<void Function(DocumentSnapshot<Map<String, dynamic>>)?>>{};
  final requests = <String>[];
  final cancels = <String, int>{};
  StreamController<DocumentSnapshot<Map<String, dynamic>>> controller(String path) => streams.putIfAbsent(path,
    () => StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
      onCancel: () => cancels[path] = (cancels[path] ?? 0) + 1));
  void profile(String uid, {bool active = true, String? name}) => controller('users/$uid').add(
    SessionSnapshot({'name': name ?? 'Private $uid', 'email': '$uid@example.test', 'active': active, 'role': 'member'}));
  // Adversarial queued callback: deliberately exercise epoch protection beyond cancel.
  void lateProfile(String uid, int index, String name) => listeners['users/$uid']![index]!(
    SessionSnapshot({'name': name, 'active': true, 'role': 'member'}));
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _SessionCollection(this, path);
  Future<void> close() async { for (final c in streams.values) { await c.close(); } }
}

class _SessionCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  final SessionFirestore db;
  final String path;
  _SessionCollection(this.db, this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) => _SessionDocument(db, '$path/$id');
}

class _SessionDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  final SessionFirestore db;
  final String path;
  _SessionDocument(this.db, this.path);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      expect(invocation.namedArguments[#includeMetadataChanges] ?? false, path.startsWith('users/'));
      db.requests.add(path);
      return _SessionStream(db, path);
    }
    return super.noSuchMethod(invocation);
  }
}

class _SessionStream extends Stream<DocumentSnapshot<Map<String, dynamic>>> {
  final SessionFirestore db;
  final String path;
  _SessionStream(this.db, this.path);
  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listen(
      void Function(DocumentSnapshot<Map<String, dynamic>>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    db.listeners.putIfAbsent(path, () => []).add(onData);
    return db.controller(path).stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
