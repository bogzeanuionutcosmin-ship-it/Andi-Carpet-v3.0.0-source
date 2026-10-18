import 'dart:async';
import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_platform_sdk_fixture.dart';
import 'home_sync_fixture.dart';

class ValidTokenFcmFixture extends HomeFcmSdkFixture {
  int refreshStarts = 0, refreshCancels = 0;
  late final refresh = StreamController<String>.broadcast(
    onListen: () { refreshStarts++; }, onCancel: () { refreshCancels++; },
  );
  Future<RemoteMessage?>? initialResult;
  @override
  Stream<String> get onTokenRefresh {
    trace.add('refresh');
    return refresh.stream;
  }
  @override
  Future<RemoteMessage?> getInitialMessage() {
    trace.add('initial');
    return initialResult ?? Future<RemoteMessage?>.value();
  }
}

class PushWrite {
  final String path;
  final Map<String, dynamic> data;
  final bool merge;
  PushWrite(this.path, this.data, this.merge);
}

class PushFirestoreFixture extends Fake implements FirebaseFirestore {
  final attempts = <PushWrite>[];
  final writes = <PushWrite>[];
  final reads = <String>[];
  final unexpected = <String>[];
  final scriptedReads = <String, Future<DocumentSnapshot<Map<String, dynamic>>> Function()>{};
  Future<void> Function(PushWrite)? beforeSet;
  Never reject(String operation) {
    unexpected.add(operation);
    throw StateError('Unscripted push fixture operation');
  }
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => _PushCollection(this, path);
}
class _PushCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  final PushFirestoreFixture db;
  final String path;
  _PushCollection(this.db, this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) {
    if (id == null) return db.reject('auto-id:$path');
    return _PushDocument(db, '$path/$id');
  }
  @override
  dynamic noSuchMethod(Invocation i) => db.reject('$path:${i.memberName}');
}
class _PushDocument extends Fake implements DocumentReference<Map<String, dynamic>> {
  final PushFirestoreFixture db;
  @override
  final String path;
  _PushDocument(this.db, this.path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) => _PushCollection(db, '$path/$name');
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (!RegExp(r'^users/[^/]+/pushTokens/[^/]+$').hasMatch(path)) db.reject('set:$path');
    final write = PushWrite(path, Map<String, dynamic>.from(data), options?.merge == true);
    db.attempts.add(write);
    await db.beforeSet?.call(write);
    db.writes.add(write);
  }
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    db.reads.add(path);
    return db.scriptedReads[path]?.call() ?? db.reject('get:$path');
  }
  @override
  dynamic noSuchMethod(Invocation i) => db.reject('$path:${i.memberName}');
}

class PushSdkHomePage extends HomePage {
  PushSdkHomePage({required String uid, required HomeSyncFixture sync, required PushFirestoreFixture push})
    : super(key: ValueKey('push-$uid'), profile: fixtureHomeProfile(uid),
      settings: AppSettings()..autoCloseWhenAllDone = false,
      onSettingsChanged: () {}, syncFirestore: sync, pushFirestore: push);
  @override
  StatefulElement createElement() => _PushHomeElement(this);
}
class _PushHomeElement extends StatefulElement {
  _PushHomeElement(PushSdkHomePage widget) : super(widget);
  @override
  Widget build() => const SizedBox();
}
