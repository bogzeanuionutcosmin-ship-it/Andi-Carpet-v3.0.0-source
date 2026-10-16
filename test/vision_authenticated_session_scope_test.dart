import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_authenticated_session_scope.dart';
import 'package:andi_carpeta/vision/vision_scoped_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';

void main() {
  Widget screen({
    required bool Function() owner,
    required Object epochToken,
    required void Function(VisionSessionJournalLease?) observe,
  }) {
    return MaterialApp(
      home: VisionAuthenticatedSessionScope(
        sessionEpochKey: epochToken,
        sessionIsCurrent: owner,
        builder: (context, lease) {
          observe(lease);
          return lease == null
              ? const Scaffold(body: Center(child: Text('Acces blocat')))
              : VisionScopedDiagnosticsPage(lease: lease);
        },
      ),
    );
  }

  testWidgets('authorized callback exposes only its new local lease',
      (tester) async {
    final epoch = Object();
    VisionSessionJournalLease? captured;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => true,
      observe: (lease) => captured = lease,
    ));
    expect(captured, isNotNull);
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
    expect(captured!.record(
      area: 'ocr', code: 'synthetic', platform: 'android',
    ), isTrue);
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => true,
      observe: (lease) => captured = lease,
    ));
    expect(find.text('ocr / synthetic'), findsOneWidget);
  });

  testWidgets('A to B to returning A2 discards both prior epochs',
      (tester) async {
    final epochs = [Object(), Object(), Object()];
    var uid = 'A';
    var generation = 1;
    VisionSessionJournalLease? a1;
    VisionSessionJournalLease? b;
    VisionSessionJournalLease? a2;
    await tester.pumpWidget(screen(
      epochToken: epochs[0],
      owner: () => uid == 'A' && generation == 1,
      observe: (lease) => a1 = lease,
    ));
    expect(a1, isNotNull);
    a1!.record(area: 'ocr', code: 'only_a1', platform: 'web');

    uid = 'B';
    generation = 2;
    await tester.pumpWidget(screen(
      epochToken: epochs[1],
      owner: () => uid == 'B' && generation == 2,
      observe: (lease) => b = lease,
    ));
    expect(a1!.entries, isEmpty);
    expect(a1!.record(area: 'ocr', code: 'late_a1', platform: 'web'), isFalse);
    expect(find.text('ocr / only_a1'), findsNothing);
    expect(b, isNotNull);
    expect(b!.entries, isEmpty);
    b!.record(area: 'gps', code: 'only_b', platform: 'android');

    uid = 'A';
    generation = 3;
    await tester.pumpWidget(screen(
      epochToken: epochs[2],
      owner: () => uid == 'A' && generation == 3,
      observe: (lease) => a2 = lease,
    ));
    expect(b!.entries, isEmpty);
    expect(b!.record(area: 'gps', code: 'late_b', platform: 'android'), isFalse);
    expect(a2, isNotNull);
    expect(a2!.entries, isEmpty);
    expect(find.text('ocr / only_a1'), findsNothing);
    expect(find.text('gps / only_b'), findsNothing);
  });

  testWidgets('same UID new generation never reopens its old lease',
      (tester) async {
    final epochs = [Object(), Object()];
    var generation = 5;
    VisionSessionJournalLease? original;
    VisionSessionJournalLease? renewed;
    await tester.pumpWidget(screen(
      epochToken: epochs[0],
      owner: () => generation == 5,
      observe: (lease) => original = lease,
    ));
    original!.record(area: 'fcm', code: 'previous', platform: 'web');
    generation = 6;
    await tester.pumpWidget(screen(
      epochToken: epochs[1],
      owner: () => generation == 6,
      observe: (lease) => renewed = lease,
    ));
    expect(original!.isCurrent, isFalse);
    expect(renewed, isNotNull);
    expect(renewed, isNot(same(original)));
    expect(renewed!.entries, isEmpty);
  });

  testWidgets('harmless widget rebuild preserves active epoch journal',
      (tester) async {
    final epoch = Object();
    var generation = 1;
    VisionSessionJournalLease? original;
    VisionSessionJournalLease? after;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => generation == 1,
      observe: (lease) => original = lease,
    ));
    original!.record(area: 'ocr', code: 'kept', platform: 'web');
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => generation == 1,
      observe: (lease) => after = lease,
    ));
    expect(after, same(original));
    expect(after!.entries.single.code, 'kept');
  });

  testWidgets('revoked owner yields only blocked page, never global history',
      (tester) async {
    final epoch = Object();
    var authorized = true;
    VisionSessionJournalLease? stale;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => authorized,
      observe: (lease) => stale = lease,
    ));
    stale!.record(area: 'gps', code: 'private', platform: 'android');
    authorized = false;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => authorized,
      observe: (_) {},
    ));
    expect(find.text('Acces blocat'), findsOneWidget);
    expect(find.text('gps / private'), findsNothing);
    expect(stale!.buildReport(), isNull);
    authorized = true;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => authorized,
      observe: (lease) => stale = lease,
    ));
    expect(find.text('Acces blocat'), findsOneWidget);
  });

  testWidgets('disposal revokes lease and delayed callback cannot write',
      (tester) async {
    final epoch = Object();
    VisionSessionJournalLease? original;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => true,
      observe: (lease) => original = lease,
    ));
    expect(original, isNotNull);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Logged out')),
    ));
    expect(original!.isCurrent, isFalse);
    expect(original!.record(
      area: 'ocr', code: 'late', platform: 'android',
    ), isFalse);
    expect(find.text('Logged out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ownership callback throwing fails closed',
      (tester) async {
    final epoch = Object();
    VisionSessionJournalLease? observed;
    await tester.pumpWidget(screen(
      epochToken: epoch,
      owner: () => throw StateError('AuthGate disposed'),
      observe: (lease) => observed = lease,
    ));
    expect(observed, isNull);
    expect(find.text('Acces blocat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
