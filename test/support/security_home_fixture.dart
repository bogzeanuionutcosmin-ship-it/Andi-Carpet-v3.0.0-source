import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeFixtureDoc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;
  HomeFixtureDoc(this.id, this.value);
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
}

class HomeFixtureSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  HomeFixtureSnapshot(this.docs);
  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];
}

class _TrackedSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> inner;
  final void Function() cancelled;
  bool didCancel = false;
  _TrackedSubscription(this.inner, this.cancelled);
  @override
  Future<void> cancel() {
    if (!didCancel) { didCancel = true; cancelled(); }
    return inner.cancel();
  }
  @override
  void onData(void Function(T)? handler) => inner.onData(handler);
  @override
  void onError(Function? handler) => inner.onError(handler);
  @override
  void onDone(void Function()? handler) => inner.onDone(handler);
  @override
  void pause([Future<void>? resumeSignal]) => inner.pause(resumeSignal);
  @override
  void resume() => inner.resume();
  @override
  bool get isPaused => inner.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => inner.asFuture<E>(futureValue);
}

class _TrackedStream<T> extends Stream<T> {
  final Stream<T> inner;
  final HomeSyncFixture fixture;
  final String key;
  _TrackedStream(this.inner, this.fixture, this.key);
  @override
  StreamSubscription<T> listen(void Function(T)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    fixture.trace.add('listen:$key');
    fixture.starts[key] = (fixture.starts[key] ?? 0) + 1;
    fixture.active[key] = (fixture.active[key] ?? 0) + 1;
    return _TrackedSubscription(inner.listen(onData, onError: onError,
        onDone: onDone, cancelOnError: cancelOnError), () {
      fixture.trace.add('cancel:$key');
      fixture.active[key] = fixture.active[key]! - 1;
    });
  }
}

class _HomeQuery extends Fake implements CollectionReference<Map<String, dynamic>> {
  final HomeSyncFixture fixture;
  final String key;
  _HomeQuery(this.fixture, this.key);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    if (invocation.memberName == #where) {
      return _HomeQuery(fixture, '$key[where:${args.first}=${invocation.namedArguments[#isEqualTo]}]');
    }
    if (invocation.memberName == #orderBy) {
      return _HomeQuery(fixture, '$key[order:${args.first}:${invocation.namedArguments[#descending] == true ? "desc" : "asc"}]');
    }
    if (invocation.memberName == #limit) return _HomeQuery(fixture, '$key[limit:${args.first}]');
    if (invocation.memberName == #doc) return _HomeDocument(fixture, '$key/${args.first}');
    if (invocation.memberName == #snapshots) {
      expect(invocation.namedArguments[#includeMetadataChanges] ?? false, isFalse);
      fixture.trace.add('snapshots:$key');
      return _TrackedStream(fixture.query(key).stream, fixture, key);
    }
    return super.noSuchMethod(invocation); // Unexpected reads/writes fail loudly.
  }
}

class _HomeDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  final HomeSyncFixture fixture;
  final String key;
  _HomeDocument(this.fixture, this.key);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) return _HomeQuery(fixture, '$key/${invocation.positionalArguments.first}');
    if (invocation.memberName == #set) {
      fixture.writes.add({'path': key, 'data': invocation.positionalArguments.first});
      return Future<void>.value();
    }
    if (invocation.memberName == #snapshots) {
      expect(invocation.namedArguments[#includeMetadataChanges] ?? false, isFalse);
      fixture.trace.add('snapshots:$key');
      return _TrackedStream(fixture.document(key).stream, fixture, key);
    }
    return super.noSuchMethod(invocation);
  }
}

class HomeSyncFixture extends Fake implements FirebaseFirestore {
  final trace = <String>[];
  final writes = <Map<String, dynamic>>[];
  final starts = <String, int>{};
  final active = <String, int>{};
  final queries = <String, StreamController<QuerySnapshot<Map<String, dynamic>>>>{};
  final documents = <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  int get activeCount => active.values.fold(0, (sum, count) => sum + count);
  StreamController<QuerySnapshot<Map<String, dynamic>>> query(String key) =>
      queries.putIfAbsent(key, () => StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast());
  StreamController<DocumentSnapshot<Map<String, dynamic>>> document(String key) =>
      documents.putIfAbsent(key, () => StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast());
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _HomeQuery(this, path);
  void emit(String key, String id, Map<String, dynamic> data) =>
      query(key).add(HomeFixtureSnapshot([HomeFixtureDoc(id, data)]));
  Future<void> close() async {
    for (final c in queries.values) { await c.close(); }
    for (final c in documents.values) { await c.close(); }
  }
}

// Runs the real Home State init/listeners/dispose. Only rendering is replaced,
// avoiding unrelated Dashboard/Documents SDK accesses in lifecycle tests.
class FixtureHomePage extends HomePage {
  FixtureHomePage({required Key key, required FirebaseUserProfile profile,
    required HomeSyncFixture fixture, AppSettings? settings, VoidCallback? onSettingsChanged,
    bool Function()? sessionIsCurrent, FirebaseMessaging? messaging,
    bool realPush = false, bool realLocation = false})
      : super(key: key, profile: profile,
          settings: settings ?? (AppSettings()..autoCloseWhenAllDone = false),
          onSettingsChanged: onSettingsChanged ?? () {},
          firestore: fixture, sessionIsCurrent: sessionIsCurrent, messaging: messaging,
          messageOpenedApp: const Stream<RemoteMessage>.empty(),
          startLocation: realLocation ? null : () => fixture.trace.add('effect:location'),
          initializePush: realPush ? null : () async { fixture.trace.add('effect:push'); });
  @override
  StatefulElement createElement() => _FixtureHomeElement(this);
}

class _FixtureHomeElement extends StatefulElement {
  _FixtureHomeElement(FixtureHomePage widget) : super(widget);
  @override
  Widget build() => Text('home:${(state as dynamic).currentUserId}:${(state as dynamic).me.name}');
}

FirebaseUserProfile fixtureHomeProfile(String uid) => FirebaseUserProfile(
  uid: uid, name: 'User $uid', email: '$uid@example.test', role: 'member',
  active: true, status: 'approved', function: UserFunction.worker, functionIds: const [],
);

Future<void> flushHomeFixture(WidgetTester tester) async { await tester.pump(); await tester.pump(); }
