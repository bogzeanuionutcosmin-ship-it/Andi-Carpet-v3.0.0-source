import 'dart:async';

import 'package:andi_carpeta/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoginUser extends Fake implements User {
  final List<String> events;
  _LoginUser(this.events);
  @override
  String get uid => 'synthetic-uid';
  @override
  Future<void> updateDisplayName(String? displayName) async {
    events.add('display:$displayName');
  }
}

class _LoginCredential extends Fake implements UserCredential {
  @override
  final User? user;
  _LoginCredential(this.user);
}

class _LoginHarness {
  final events = <String>[];
  Map<String, dynamic>? profile;
  Object? signInError;
  Object? profileError;
  Completer<UserCredential>? pendingSignIn;
  late final credential = _LoginCredential(_LoginUser(events));

  LoginActions get actions => LoginActions(
    resolveIdentifier: (identifier, password) async {
      events.add('resolve:$identifier:$password');
      return 'resolved@example.test';
    },
    signIn: ({required email, required password}) async {
      events.add('signIn:$email:$password');
      if (signInError != null) throw signInError!;
      if (pendingSignIn != null) return pendingSignIn!.future;
      return credential;
    },
    createUser: ({required email, required password}) async {
      events.add('create:$email:$password');
      return credential;
    },
    resetPassword: ({required email}) async { events.add('reset:$email'); },
    writeProfile: (uid, data) async {
      events.add('profile:$uid');
      if (profileError != null) throw profileError!;
      profile = data;
    },
  );
}

Future<void> _mount(WidgetTester tester, _LoginHarness h) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: LoginPage(
    settings: AppSettings()..brandingBackgroundId = 'none', actions: h.actions,
  )));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump();
}

Future<void> _fillSignup(WidgetTester tester) async {
  await _tap(tester, 'Nu am cont · Creează cont');
  final fields = find.byType(TextField);
  for (final entry in <int, String>{
    0: ' Synthetic Name ', 1: ' User.A ', 2: '+40 (712) 345-678',
    3: ' new@example.test ', 4: 'dummy-password', 5: 'dummy-password',
  }.entries) {
    await tester.enterText(fields.at(entry.key), entry.value);
  }
}

void main() {
  testWidgets('validation avoids all operations; login resolves then signs in', (tester) async {
    final h = _LoginHarness();
    await _mount(tester, h);
    await _tap(tester, 'Intră în cont');
    expect(find.text('Completează toate câmpurile obligatorii.'), findsOneWidget);
    expect(h.events, isEmpty);
    await tester.enterText(find.byType(TextField).at(0), ' Alias ');
    await tester.enterText(find.byType(TextField).at(1), ' dummy password ');
    await _tap(tester, 'Intră în cont');
    expect(h.events, ['resolve:Alias: dummy password ',
      'signIn:resolved@example.test: dummy password ']);
    expect(find.text('Completează toate câmpurile obligatorii.'), findsNothing);
  });

  testWidgets('expired credential error permits a subsequent attempt', (tester) async {
    final h = _LoginHarness()..signInError = FirebaseAuthException(
      code: 'invalid-credential', message: 'synthetic expired session');
    await _mount(tester, h);
    await tester.enterText(find.byType(TextField).at(0), 'alias');
    await tester.enterText(find.byType(TextField).at(1), 'dummy');
    await _tap(tester, 'Intră în cont');
    expect(find.text('Emailul sau parola nu sunt corecte.'), findsOneWidget);
    h.signInError = null;
    await _tap(tester, 'Intră în cont');
    expect(h.events.length, 4);
    expect(find.text('Emailul sau parola nu sunt corecte.'), findsNothing);
  });

  testWidgets('registration keeps operation order and pending profile schema', (tester) async {
    final h = _LoginHarness();
    await _mount(tester, h);
    await _fillSignup(tester);
    await _tap(tester, 'Creează contul');
    expect(h.events, ['create:new@example.test:dummy-password',
      'display:Synthetic Name', 'profile:synthetic-uid']);
    expect(h.profile, {
      'name': 'Synthetic Name', 'email': 'new@example.test',
      'username': 'user.a', 'usernameNormalized': 'user.a',
      'phone': '+40 (712) 345-678', 'phoneNormalized': '40712345678',
      'role': 'member', 'function': '', 'functionIds': <String>[],
      'effectivePermissions': <String>[], 'active': false, 'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

  testWidgets('profile write failure adds no rollback or retry', (tester) async {
    final h = _LoginHarness()..profileError = StateError('synthetic write failure');
    await _mount(tester, h);
    await _fillSignup(tester);
    await _tap(tester, 'Creează contul');
    expect(h.events.length, 3);
    expect(h.profile, isNull);
    expect(find.textContaining('synthetic write failure'), findsOneWidget);
  });

  testWidgets('password recovery requires an email and sends the trimmed address', (tester) async {
    final h = _LoginHarness();
    await _mount(tester, h);
    await tester.enterText(find.byType(TextField).at(0), 'alias');
    await _tap(tester, 'Am uitat parola');
    expect(h.events, isEmpty);
    await tester.enterText(find.byType(TextField).at(0), ' user@example.test ');
    await _tap(tester, 'Am uitat parola');
    expect(h.events, ['reset:user@example.test']);
    expect(find.text('Emailul pentru resetarea parolei a fost trimis.'), findsOneWidget);
  });

  testWidgets('late failure after dispose does not update widget state', (tester) async {
    final h = _LoginHarness()..pendingSignIn = Completer<UserCredential>();
    await _mount(tester, h);
    await tester.enterText(find.byType(TextField).at(0), 'alias');
    await tester.enterText(find.byType(TextField).at(1), 'dummy');
    await _tap(tester, 'Intră în cont');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.pendingSignIn!.completeError(StateError('synthetic late failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(h.events.length, 2);
  });
}
