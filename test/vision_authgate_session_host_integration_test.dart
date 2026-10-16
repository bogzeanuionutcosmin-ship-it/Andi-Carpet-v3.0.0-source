import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_auth_session_host.dart';
import 'package:andi_carpeta/vision/vision_scoped_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';

Widget _sessionHome({
  required Key key,
  required FirebaseUserProfile profile,
  required bool Function() sessionIsCurrent,
  required List<VisionSessionJournalLease> issued,
}) {
  return VisionAuthSessionHost(
    key: key,
    sessionIsCurrent: sessionIsCurrent,
    builder: (context, lease) {
      if (!issued.contains(lease)) issued.add(lease);
      return Scaffold(
        body: Column(children: [
          Text('active-owner:${profile.uid}'),
          TextButton(
            onPressed: () => lease.record(
              area: 'gps',
              code: 'event_${profile.uid}',
              platform: 'android',
            ),
            child: const Text('Record scoped event'),
          ),
          TextButton(
            onPressed: () {
              if (!lease.isCurrent) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => VisionScopedDiagnosticsPage(lease: lease),
              ));
            },
            child: const Text('Open scoped Vision'),
          ),
        ]),
      );
    },
  );
}

void main() {
  testWidgets('real AuthGate builder isolates Vision A to B to A2 and old route',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    final issued = <VisionSessionJournalLease>[];
    await harness.mount(tester, auth, db,
      homeBuilder: (key, profile, current) => _sessionHome(
        key: key, profile: profile,
        sessionIsCurrent: current, issued: issued,
      ),
    );
    db.profile('a');
    await harness.flush(tester);
    expect(find.text('active-owner:a'), findsOneWidget);
    await tester.tap(find.text('Record scoped event'));
    await tester.pump();
    await tester.tap(find.text('Open scoped Vision'));
    await tester.pumpAndSettle();
    expect(find.text('gps / event_a'), findsOneWidget);
    final a1 = issued.last;

    auth.switchTo('b');
    await harness.flush(tester);
    expect(a1.isCurrent, isFalse);
    expect(a1.entries, isEmpty);
    expect(find.text('gps / event_a'), findsNothing);
    db.profile('b');
    await harness.flush(tester);
    expect(find.text('active-owner:b'), findsOneWidget);
    final b = issued.last;
    expect(b, isNot(same(a1)));
    await tester.tap(find.text('Open scoped Vision'));
    await tester.pumpAndSettle();
    expect(find.text('gps / event_a'), findsNothing);
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
    expect(a1.buildReport(), isNull);

    auth.switchTo('a');
    await harness.flush(tester);
    db.profile('a');
    await harness.flush(tester);
    expect(find.text('active-owner:a'), findsOneWidget);
    final a2 = issued.last;
    expect(a2, isNot(same(a1)));
    expect(b.isCurrent, isFalse);
    expect(b.entries, isEmpty);
    await tester.tap(find.text('Open scoped Vision'));
    await tester.pumpAndSettle();
    expect(find.text('gps / event_a'), findsNothing);
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(a2.isCurrent, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same UID profile refresh preserves lease but logout destroys it',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    final issued = <VisionSessionJournalLease>[];
    await harness.mount(tester, auth, db,
      homeBuilder: (key, profile, current) => _sessionHome(
        key: key, profile: profile,
        sessionIsCurrent: current, issued: issued,
      ),
    );
    db.profile('a');
    await harness.flush(tester);
    await tester.tap(find.text('Record scoped event'));
    await tester.pump();
    final first = issued.last;
    expect(first.entries.single.code, 'event_a');

    db.profile('a', name: 'Refreshed Profile A');
    await harness.flush(tester);
    expect(first.isCurrent, isTrue);
    expect(issued.last, same(first));
    expect(first.entries.single.code, 'event_a');

    auth.switchTo(null);
    await harness.flush(tester);
    expect(first.isCurrent, isFalse);
    expect(first.entries, isEmpty);
    expect(find.text('active-owner:a'), findsNothing);
    auth.switchTo('a');
    await harness.flush(tester);
    db.profile('a');
    await harness.flush(tester);
    final second = issued.last;
    expect(second, isNot(same(first)));
    expect(second.entries, isEmpty);
    expect(first.record(area: 'gps', code: 'late_a1', platform: 'android'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive or throwing owner callback never runs private builder',
      (tester) async {
    var called = 0;
    var allowed = false;
    bool owner() => allowed;
    Widget make() => MaterialApp(
      home: VisionAuthSessionHost(
        sessionIsCurrent: owner,
        builder: (_, lease) {
          called++;
          return const Text('PRIVATE VISION');
        },
        inactiveBuilder: (_) => const Text('ACCESS DENIED'),
      ),
    );
    await tester.pumpWidget(make());
    expect(called, 0);
    expect(find.text('PRIVATE VISION'), findsNothing);
    expect(find.text('ACCESS DENIED'), findsOneWidget);
    allowed = true;
    await tester.pumpWidget(make());
    expect(called, 1);
    expect(find.text('PRIVATE VISION'), findsOneWidget);
    allowed = false;
    await tester.pumpWidget(make());
    expect(called, 1);
    expect(find.text('ACCESS DENIED'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
      home: VisionAuthSessionHost(
        sessionIsCurrent: () => throw StateError('session revoked'),
        builder: (_, lease) => const Text('LEAK'),
      ),
    ));
    expect(find.text('LEAK'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
