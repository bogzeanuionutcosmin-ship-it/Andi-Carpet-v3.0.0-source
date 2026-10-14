import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

class GateFixtureUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  GateFixtureUser(this.uid, this.email);
}

class GateFixtureSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  @override
  final bool exists;
  GateFixtureSnapshot(this.value, {this.exists = true});
  @override
  Map<String, dynamic>? data() => value;
}

class GateFixture {
  User? user = GateFixtureUser('a', 'a@example.com');
  var authCancels = 0;
  var settingsCancels = 0;
  final profileCancels = <String, int>{};
  final requestedProfiles = <String>[];
  final profiles = <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  late final auth = StreamController<User?>.broadcast(
    onCancel: () { authCancels++; },
  );
  late final settings = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
    onCancel: () { settingsCancels++; },
  );

  StreamController<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      profiles.putIfAbsent(uid, () => StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
        onCancel: () { profileCancels[uid] = (profileCancels[uid] ?? 0) + 1; },
      ));

  AuthGateSources get sources => AuthGateSources(
    currentUser: () => user,
    authStateChanges: () => auth.stream,
    uiSettingsSnapshots: () => settings.stream,
    profileSnapshots: (uid) {
      requestedProfiles.add(uid);
      return profile(uid).stream;
    },
  );

  Future<void> close() async {
    await auth.close();
    await settings.close();
    for (final controller in profiles.values) { await controller.close(); }
  }
}

Future<void> mountFixtureGate(WidgetTester tester, GateFixture h,
    {AppSettings? settings, VoidCallback? onSettingsChanged,
    Widget Function(Key, FirebaseUserProfile)? activePageBuilder}) async {
  await tester.pumpWidget(MaterialApp(home: AuthGate(
    settings: settings ?? (AppSettings()..brandingBackgroundId = 'none'),
    onSettingsChanged: onSettingsChanged ?? () {},
    sources: h.sources,
    activePageBuilder: activePageBuilder,
  )));
  await tester.pump();
}

Future<void> flushFixtureGate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

