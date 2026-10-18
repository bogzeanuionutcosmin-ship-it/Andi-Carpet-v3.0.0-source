import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_scoped_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/security_gate_fixture.dart';

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Test-only integration of the existing AuthGate ownership callback.
///
/// Production Home/AuthGate sources are deliberately NOT modified. The
/// onSessionChanged callback is the synchronous invalidation hook; the
/// supplied activeSessionPageBuilder predicate includes UID + generation.
class _VisionGateHarness {
  final journal = VisionSessionJournal();
  VisionSessionJournalLease? active;
  final leases = <VisionSessionJournalLease>[];
  int epochs = 0;
  int revocations = 0;

  bool onSessionChanged(String? _) {
    revocations++;
    journal.revoke();
    return false; // Allow AuthGate to subscribe to the replacement profile.
  }

  Widget buildPage(
    Key key,
    FirebaseUserProfile profile,
    bool Function() sessionIsCurrent,
  ) {
    if (active == null || !active!.isCurrent) {
      active = journal.startSession(isSessionCurrent: sessionIsCurrent);
      epochs++;
      leases.add(active!);
      active!.record(
        area: 'auth',
        code: 'epoch_${profile.uid}_$epochs',
        platform: 'android',
      );
    }
    return VisionScopedDiagnosticsPage(key: key, lease: active!);
  }
}

Future<void> _mountAuthGate(
  WidgetTester tester,
  SessionAuth auth,
  SessionFirestore db,
  _VisionGateHarness harness,
) async {
  await tester.pumpWidget(MaterialApp(
    home: AuthGate(
      settings: AppSettings()..brandingBackgroundId = 'none',
      onSettingsChanged: () {},
      onSessionChanged: harness.onSessionChanged,
      sources: AuthGateSources(
        currentUser: () => auth.currentUser,
        authStateChanges: auth.authStateChanges,
        uiSettingsSnapshots:
            () => db.collection('meta').doc('uiSettings').snapshots(),
        profileSnapshots: (uid) =>
            db.collection('users').doc(uid).snapshots(
              includeMetadataChanges: true,
            ),
      ),
      activeSessionPageBuilder: harness.buildPage,
    ),
  ));
  await _flush(tester);
}

void main() {
  testWidgets('real AuthGate UID and epoch callback isolates A B A2 and late profile',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final harness = _VisionGateHarness();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mountAuthGate(tester, auth, db, harness);

    db.profile('a', name: 'Original Alice');
    await _flush(tester);
    expect(harness.epochs, 1);
    expect(find.text('auth / epoch_a_1'), findsOneWidget);
    final firstA = harness.leases.single;
    expect(firstA.isCurrent, isTrue);

    auth.switchTo('b');
    await _flush(tester);
    expect(harness.revocations, greaterThanOrEqualTo(1));
    expect(find.text('auth / epoch_a_1'), findsNothing);
    expect(firstA.isCurrent, isFalse);
    expect(firstA.entries, isEmpty);
    expect(firstA.buildReport(), isNull);

    db.profile('b', name: 'New Bob');
    await _flush(tester);
    expect(harness.epochs, 2);
    expect(find.text('auth / epoch_b_2'), findsOneWidget);
    final b = harness.leases.last;
    expect(b.isCurrent, isTrue);

    auth.switchTo('a');
    await _flush(tester);
    expect(find.text('auth / epoch_b_2'), findsNothing);
    expect(b.isCurrent, isFalse);

    // Old subscription callback must never re-authorize previous A1 history.
    db.lateProfile('a', 0, 'Stale Original Alice');
    await _flush(tester);
    expect(find.text('auth / epoch_a_1'), findsNothing);
    expect(find.textContaining('Stale Original Alice'), findsNothing);

    db.profile('a', name: 'Returning Alice');
    await _flush(tester);
    expect(harness.epochs, 3);
    expect(find.text('auth / epoch_a_3'), findsOneWidget);
    expect(find.text('auth / epoch_a_1'), findsNothing);
    expect(find.text('auth / epoch_b_2'), findsNothing);
    expect(firstA.record(area: 'ocr', code: 'late_a', platform: 'android'),
        isFalse);
    expect(b.record(area: 'gps', code: 'late_b', platform: 'android'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real AuthGate logout invalidates lease and same UID login is fresh',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final harness = _VisionGateHarness();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mountAuthGate(tester, auth, db, harness);

    db.profile('a');
    await _flush(tester);
    expect(find.text('auth / epoch_a_1'), findsOneWidget);
    final old = harness.leases.single;

    auth.switchTo(null);
    await _flush(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('auth / epoch_a_1'), findsNothing);
    expect(old.isCurrent, isFalse);
    expect(old.entries, isEmpty);
    expect(old.buildReport(), isNull);

    auth.switchTo('a');
    await _flush(tester);
    db.profile('a');
    await _flush(tester);
    expect(harness.epochs, 2);
    expect(find.text('auth / epoch_a_2'), findsOneWidget);
    expect(find.text('auth / epoch_a_1'), findsNothing);
    expect(old.record(area: 'auth', code: 'late', platform: 'android'),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real same-UID SDK stream reconnect does not clear valid epoch',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final harness = _VisionGateHarness();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mountAuthGate(tester, auth, db, harness);
    db.profile('a');
    await _flush(tester);

    final first = harness.leases.single;
    expect(find.text('auth / epoch_a_1'), findsOneWidget);
    final initialRevokes = harness.revocations;

    // These are transient auth events: the SDK currentUser is still 'a'.
    auth.events.add(null);
    auth.events.add(SessionUser('a'));
    await _flush(tester);
    db.profile('a', name: 'Same User Reload');
    await _flush(tester);
    expect(first.isCurrent, isTrue);
    expect(harness.epochs, 1);
    expect(harness.revocations, initialRevokes);
    expect(find.text('auth / epoch_a_1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
