import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart';

class _GateUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  _GateUser(this.uid, this.email);
}

class _GateSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  @override
  final bool exists;
  _GateSnapshot(this.value, {this.exists = true});
  @override
  Map<String, dynamic>? data() => value;
}

class _GateHarness {
  User? user = _GateUser('a', 'a@example.com');
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

Future<void> mountGate(WidgetTester tester, _GateHarness h,
    {AppSettings? settings, VoidCallback? onSettingsChanged}) async {
  await tester.pumpWidget(MaterialApp(home: AuthGate(
    settings: settings ?? (AppSettings()..brandingBackgroundId = 'none'),
    onSettingsChanged: onSettingsChanged ?? () {},
    sources: h.sources,
  )));
  await tester.pump();
}

Future<void> flushGate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('transient null auth and profile errors retain an existing profile', (tester) async {
    final h = _GateHarness();
    addTearDown(h.close);
    await mountGate(tester, h);
    expect(find.text('Se încarcă profilul...'), findsOneWidget);
    expect(h.requestedProfiles, ['a']);
    h.profile('a').add(_GateSnapshot({'name': 'Alice', 'active': false}));
    await flushGate(tester);
    expect(find.text('Alice\na@example.com'), findsOneWidget);

    h.auth.add(null);
    h.profile('a').addError('synthetic reconnect error');
    await flushGate(tester);
    expect(find.text('Alice\na@example.com'), findsOneWidget);
    expect(h.requestedProfiles, ['a']);
    expect(find.textContaining('synthetic reconnect error'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
    expect(h.profileCancels['a'], 1);
  });

  testWidgets('UID switch cancels the old profile and renders only the new identity', (tester) async {
    final h = _GateHarness();
    addTearDown(h.close);
    await mountGate(tester, h);
    h.profile('a').add(_GateSnapshot({'name': 'Alice', 'active': false}));
    await flushGate(tester);
    h.user = _GateUser('b', 'b@example.com');
    h.auth.add(h.user);
    await flushGate(tester);
    expect(h.requestedProfiles, ['a', 'b']);
    expect(h.profileCancels['a'], 1);
    h.profile('a').add(_GateSnapshot({'name': 'Stale identity', 'active': false}));
    h.profile('b').add(_GateSnapshot({'name': 'Bob', 'active': false}));
    await flushGate(tester);
    expect(find.text('Bob\nb@example.com'), findsOneWidget);
    expect(find.textContaining('Stale identity'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(h.profileCancels['b'], 1);
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
  });

  testWidgets('missing profile and UI settings keep their existing behavior and disposal', (tester) async {
    final h = _GateHarness();
    addTearDown(h.close);
    final settings = AppSettings()..brandingBackgroundId = 'none';
    var changed = 0;
    await mountGate(tester, h, settings: settings, onSettingsChanged: () { changed++; });
    h.profile('a').add(_GateSnapshot(null, exists: false));
    await flushGate(tester);
    expect(find.text('Contul există în Authentication, dar profilul Firestore lipsește.'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    final update = _GateSnapshot({
      'brandingBackgroundId': 'plain', 'backgroundOpacity': .9,
      'androidDownloadUrl': 'https://example.invalid/synthetic.apk',
    });
    h.settings.add(update);
    await flushGate(tester);
    expect(changed, 1);
    expect(settings.brandingBackgroundId, 'plain');
    expect(settings.backgroundOpacity, .7);
    expect(settings.androidDownloadUrl, 'https://example.invalid/synthetic.apk');
    h.settings.add(update);
    await flushGate(tester);
    expect(changed, 1);
    await tester.pumpWidget(const SizedBox());
    h.settings.add(_GateSnapshot({'brandingBackgroundId': 'after-dispose'}));
    await flushGate(tester);
    expect(changed, 1);
    expect(settings.brandingBackgroundId, 'plain');
    expect(h.authCancels, 1);
    expect(h.settingsCancels, 1);
    expect(h.profileCancels['a'], 1);
  });

  testWidgets('initial profile error is visible and a later snapshot recovers', (tester) async {
    final h = _GateHarness();
    addTearDown(h.close);
    await mountGate(tester, h);
    h.profile('a').addError('synthetic initial failure');
    await flushGate(tester);
    expect(find.text('Nu am putut citi profilul: synthetic initial failure'), findsOneWidget);
    h.profile('a').add(_GateSnapshot({'name': 'Recovered', 'active': false}));
    await flushGate(tester);
    expect(find.text('Recovered\na@example.com'), findsOneWidget);
    expect(find.textContaining('synthetic initial failure'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
