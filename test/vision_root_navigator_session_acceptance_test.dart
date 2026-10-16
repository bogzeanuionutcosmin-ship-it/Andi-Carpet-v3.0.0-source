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

/// Real AndiCarpetaApp root with fake SDK streams. This test intentionally
/// does not modify the protected AuthGate/Home implementation.
class _VisionRouteHost extends StatefulWidget {
  const _VisionRouteHost({
    super.key,
    required this.uid,
    required this.sessionIsCurrent,
    required this.journal,
    required this.onLeaseCreated,
  });

  final String uid;
  final bool Function() sessionIsCurrent;
  final VisionSessionJournal journal;
  final void Function(VisionSessionJournalLease) onLeaseCreated;

  @override
  State<_VisionRouteHost> createState() => _VisionRouteHostState();
}

class _VisionRouteHostState extends State<_VisionRouteHost> {
  late final VisionSessionJournalLease lease;

  @override
  void initState() {
    super.initState();
    lease = widget.journal.startSession(
      isSessionCurrent: widget.sessionIsCurrent,
    );
    widget.onLeaseCreated(lease);
    lease.record(
      area: 'auth',
      code: 'session_${widget.uid}',
      platform: 'android',
    );
  }

  @override
  void dispose() {
    if (lease.isCurrent) widget.journal.revoke();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text('home:${widget.uid}'),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VisionScopedDiagnosticsPage(lease: lease),
                ),
              ),
              child: const Text('Deschide Vision test'),
            ),
          ],
        ),
      );
}

Future<void> _mount(
  WidgetTester tester,
  SessionAuth auth,
  SessionFirestore db,
  VisionSessionJournal journal,
  void Function(VisionSessionJournalLease) onLeaseCreated,
) async {
  await tester.pumpWidget(AndiCarpetaApp(
    settings: AppSettings()..brandingBackgroundId = 'none',
    authSources: AuthGateSources(
      currentUser: () => auth.currentUser,
      authStateChanges: auth.authStateChanges,
      uiSettingsSnapshots: () =>
          db.collection('meta').doc('uiSettings').snapshots(),
      profileSnapshots: (uid) =>
          db.collection('users').doc(uid).snapshots(
                includeMetadataChanges: true,
              ),
    ),
    homeBuilder: (key, profile, isCurrent) => _VisionRouteHost(
      key: key,
      uid: profile.uid,
      sessionIsCurrent: isCurrent,
      journal: journal,
      onLeaseCreated: onLeaseCreated,
    ),
  ));
  await _flush(tester);
}

void main() {
  testWidgets('real root discards open Vision route A on B and again on A2',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final journal = VisionSessionJournal();
    final leases = <VisionSessionJournalLease>[];
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mount(tester, auth, db, journal, leases.add);

    db.profile('a');
    await _flush(tester);
    expect(find.text('home:a'), findsOneWidget);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_a'), findsOneWidget);
    final a1 = leases.single;

    auth.switchTo('b');
    await _flush(tester);
    expect(find.text('auth / session_a'), findsNothing);
    expect(find.byType(VisionScopedDiagnosticsPage), findsNothing);
    expect(a1.isCurrent, isFalse);
    expect(a1.entries, isEmpty);
    expect(a1.buildReport(), isNull);

    db.profile('b');
    await _flush(tester);
    expect(find.text('home:b'), findsOneWidget);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_b'), findsOneWidget);
    final b = leases.last;

    auth.switchTo('a');
    await _flush(tester);
    expect(find.text('auth / session_b'), findsNothing);
    expect(find.byType(VisionScopedDiagnosticsPage), findsNothing);
    expect(b.isCurrent, isFalse);
    db.profile('a', name: 'Returning A');
    await _flush(tester);
    expect(find.text('home:a'), findsOneWidget);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_a'), findsOneWidget);
    expect(leases.length, 3);
    expect(a1.isCurrent, isFalse);
    expect(b.isCurrent, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real root removes open Vision route on logout and same UID relogin',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final journal = VisionSessionJournal();
    final leases = <VisionSessionJournalLease>[];
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mount(tester, auth, db, journal, leases.add);
    db.profile('a');
    await _flush(tester);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_a'), findsOneWidget);
    final old = leases.single;

    auth.switchTo(null);
    await _flush(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(VisionScopedDiagnosticsPage), findsNothing);
    expect(old.isCurrent, isFalse);
    expect(old.buildReport(), isNull);

    auth.switchTo('a');
    await _flush(tester);
    db.profile('a');
    await _flush(tester);
    expect(find.text('home:a'), findsOneWidget);
    expect(leases.length, 2);
    expect(identical(old, leases.last), isFalse);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_a'), findsOneWidget);
    expect(old.record(area: 'gps', code: 'late', platform: 'android'),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('same UID transient stream reconnect keeps currently open Vision route',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    final journal = VisionSessionJournal();
    final leases = <VisionSessionJournalLease>[];
    addTearDown(auth.events.close);
    addTearDown(db.close);
    await _mount(tester, auth, db, journal, leases.add);
    db.profile('a');
    await _flush(tester);
    await tester.tap(find.text('Deschide Vision test'));
    await tester.pumpAndSettle();
    expect(find.text('auth / session_a'), findsOneWidget);
    final old = leases.single;

    // Fake auth-stream null is not logout: currentUser remains UID 'a'.
    auth.events.add(null);
    auth.events.add(SessionUser('a'));
    await _flush(tester);
    expect(find.text('auth / session_a'), findsOneWidget);
    expect(leases.length, 1);
    expect(old.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
