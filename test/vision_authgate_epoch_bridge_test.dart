import 'package:andi_carpeta/main.dart';
import 'package:andi_carpeta/vision/vision_authgate_epoch_bridge.dart';
import 'package:andi_carpeta/vision/vision_scoped_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_session_acceptance_test.dart' as harness;
import 'support/security_gate_fixture.dart';

void main() {
  Widget probe({
    required bool Function() owner,
    required void Function(VisionSessionJournalLease?) onBuild,
  }) {
    return MaterialApp(
      home: VisionAuthGateEpochBridge(
        sessionIsCurrent: owner,
        builder: (context, lease) {
          onBuild(lease);
          return Scaffold(body: Text(lease == null ? 'DENIED' : 'AUTHORIZED'));
        },
      ),
    );
  }

  testWidgets('profile refresh does not rotate actual AuthGate generation',
      (tester) async {
    var generation = 1;
    bool original() => generation == 1;
    VisionSessionJournalLease? before;
    VisionSessionJournalLease? after;
    await tester.pumpWidget(probe(owner: original, onBuild: (v) => before = v));
    expect(before, isNotNull);
    expect(before!.record(area: 'ocr', code: 'keep', platform: 'web'), isTrue);
    // AuthGate constructs a fresh closure for a benign profile rebuild.
    bool refreshed() => generation == 1;
    await tester.pumpWidget(probe(owner: refreshed, onBuild: (v) => after = v));
    expect(after, same(before));
    expect(after!.entries.single.code, 'keep');
    expect(find.text('AUTHORIZED'), findsOneWidget);
  });

  testWidgets('same UID new AuthGate generation revokes old lease',
      (tester) async {
    var generation = 1;
    bool a1() => generation == 1;
    bool a2() => generation == 2;
    VisionSessionJournalLease? old;
    VisionSessionJournalLease? next;
    await tester.pumpWidget(probe(owner: a1, onBuild: (v) => old = v));
    old!.record(area: 'gps', code: 'old', platform: 'android');
    generation = 2;
    await tester.pumpWidget(probe(owner: a2, onBuild: (v) => next = v));
    expect(old!.isCurrent, isFalse);
    expect(old!.entries, isEmpty);
    expect(old!.record(area: 'gps', code: 'late', platform: 'android'), isFalse);
    expect(next, isNotNull);
    expect(next, isNot(same(old)));
    expect(next!.entries, isEmpty);
  });

  testWidgets('callback false then true on same epoch cannot resurrect',
      (tester) async {
    var allowed = true;
    bool oldOwner() => allowed;
    VisionSessionJournalLease? first;
    VisionSessionJournalLease? seen;
    await tester.pumpWidget(probe(owner: oldOwner, onBuild: (v) => first = v));
    expect(first, isNotNull);
    allowed = false;
    await tester.pumpWidget(probe(owner: oldOwner, onBuild: (v) => seen = v));
    expect(seen, isNull);
    expect(first!.isCurrent, isFalse);
    allowed = true;
    await tester.pumpWidget(probe(owner: oldOwner, onBuild: (v) => seen = v));
    expect(seen, isNull);
    // A new callback alone is not proof of a new generation.
    bool harmlessRefresh() => allowed;
    await tester.pumpWidget(
      probe(owner: harmlessRefresh, onBuild: (v) => seen = v),
    );
    expect(seen, isNull);
    allowed = false;
    bool newEpoch() => true;
    await tester.pumpWidget(probe(owner: newEpoch, onBuild: (v) => seen = v));
    expect(seen, isNotNull);
    expect(seen, isNot(same(first)));
    expect(seen!.entries, isEmpty);
  });

  testWidgets('throwing stale generation fails closed until a fresh one',
      (tester) async {
    var breaks = false;
    bool previous() {
      if (breaks) throw StateError('old generation revoked');
      return true;
    }
    VisionSessionJournalLease? old;
    VisionSessionJournalLease? current;
    await tester.pumpWidget(probe(owner: previous, onBuild: (v) => old = v));
    breaks = true;
    await tester.pumpWidget(probe(owner: previous, onBuild: (v) => current = v));
    expect(current, isNull);
    expect(old!.isCurrent, isFalse);
    bool next() => true;
    await tester.pumpWidget(probe(owner: next, onBuild: (v) => current = v));
    expect(current, isNotNull);
    expect(current, isNot(same(old)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('real AndiCarpetaApp/AuthGate isolates A B A2 with bridge',
      (tester) async {
    final auth = SessionAuth();
    final db = SessionFirestore();
    addTearDown(auth.events.close);
    addTearDown(db.close);
    final issued = <VisionSessionJournalLease>[];
    await harness.mount(
      tester, auth, db,
      homeBuilder: (key, profile, current) => VisionAuthGateEpochBridge(
        key: key,
        sessionIsCurrent: current,
        builder: (context, lease) {
          if (lease == null) {
            return const Scaffold(body: Text('Vision denied'));
          }
          if (!issued.contains(lease)) issued.add(lease);
          return Scaffold(
            body: Column(children: [
              Text('owner:${profile.uid}'),
              TextButton(
                onPressed: () => lease.record(
                  area: 'gps', code: 'for_${profile.uid}', platform: 'android',
                ),
                child: const Text('Record private'),
              ),
              TextButton(
                onPressed: () {
                  if (!lease.isCurrent) return;
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => VisionScopedDiagnosticsPage(lease: lease),
                  ));
                },
                child: const Text('Open Vision'),
              ),
            ]),
          );
        },
      ),
    );
    db.profile('a');
    await harness.flush(tester);
    expect(find.text('owner:a'), findsOneWidget);
    await tester.tap(find.text('Record private'));
    await tester.pump();
    await tester.tap(find.text('Open Vision'));
    await tester.pumpAndSettle();
    expect(find.text('gps / for_a'), findsOneWidget);
    final a1 = issued.last;

    auth.switchTo('b');
    await harness.flush(tester);
    expect(a1.isCurrent, isFalse);
    expect(a1.entries, isEmpty);
    expect(find.text('gps / for_a'), findsNothing);
    db.profile('b');
    await harness.flush(tester);
    expect(find.text('owner:b'), findsOneWidget);
    final b = issued.last;
    expect(b, isNot(same(a1)));
    expect(b.entries, isEmpty);

    auth.switchTo('a');
    await harness.flush(tester);
    db.profile('a');
    await harness.flush(tester);
    final a2 = issued.last;
    expect(a2, isNot(same(a1)));
    expect(b.isCurrent, isFalse);
    expect(b.entries, isEmpty);
    expect(a1.buildReport(), isNull);
    expect(a2.entries, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(a2.isCurrent, isFalse);
    expect(tester.takeException(), isNull);
  });
}
