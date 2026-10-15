import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_scoped_diagnostics_page.dart';
import 'package:andi_carpeta/vision/vision_session_journal.dart';

void main() {
  testWidgets('current lease shows its own sanitized incident and read-only tools',
      (tester) async {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    expect(lease.record(area: 'ocr', code: 'save_failed', platform: 'android'),
        isTrue);
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: lease),
    ));
    expect(find.text('ocr / save_failed'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsOneWidget);
    expect(find.byTooltip('Test local · salvare jurnal'), findsNothing);
    expect(find.textContaining('Jurnal de probă'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked lease blocks clipboard without an intervening rebuild',
      (tester) async {
    var authorized = true;
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => authorized);
    lease.record(area: 'gps', code: 'position_failed', platform: 'android');
    var copied = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = true;
        return null;
      },
    );
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, null,
        ));

    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: lease),
    ));
    expect(find.text('gps / position_failed'), findsOneWidget);
    authorized = false; // AuthGate invalidates epoch; no scheduled frame yet.
    await tester.tap(find.byTooltip('Copiază raport tehnic anonimizat'));
    await tester.pump();
    expect(copied, isFalse);
    expect(find.text('gps / position_failed'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
  });

  testWidgets('A to B to A2 screens never receive another epoch history',
      (tester) async {
    var identity = 'A';
    var epoch = 1;
    final journal = VisionSessionJournal();
    final a1 = journal.startSession(
      isSessionCurrent: () => identity == 'A' && epoch == 1,
    );
    a1.record(area: 'ocr', code: 'only_a1', platform: 'android');

    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: a1),
    ));
    expect(find.text('ocr / only_a1'), findsOneWidget);

    identity = 'B';
    epoch = 2;
    final b = journal.startSession(
      isSessionCurrent: () => identity == 'B' && epoch == 2,
    );
    b.record(area: 'gps', code: 'only_b', platform: 'android');
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(key: const ValueKey('B'), lease: b),
    ));
    expect(find.text('gps / only_b'), findsOneWidget);
    expect(find.text('ocr / only_a1'), findsNothing);

    identity = 'A';
    epoch = 3;
    final a2 = journal.startSession(
      isSessionCurrent: () => identity == 'A' && epoch == 3,
    );
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(key: const ValueKey('A2'), lease: a2),
    ));
    expect(find.text('gps / only_b'), findsNothing);
    expect(find.text('ocr / only_a1'), findsNothing);
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
    expect(a1.buildReport(), isNull);
    expect(b.buildReport(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a throwing owner predicate is always denied',
      (tester) async {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(
      isSessionCurrent: () => throw StateError('session expired'),
    );
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: lease),
    ));
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('snapshot for UI is detached from the mutable source journal', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    lease.record(area: 'ocr', code: 'original', platform: 'web');
    final view = lease.snapshotForDisplay();
    expect(view, isNotNull);
    expect(view!.entries.single.code, 'original');

    view.record(area: 'gps', code: 'view_only', platform: 'web');
    expect(lease.entries.map((e) => e.code), contains('original'));
    expect(lease.entries.map((e) => e.code), isNot(contains('view_only')));
    journal.revoke();
    expect(lease.snapshotForDisplay(), isNull);
  });

  test('owner revocation during snapshot computation denies view', () {
    var calls = 0;
    final journal = VisionSessionJournal();
    final lease = journal.startSession(
      isSessionCurrent: () => ++calls == 1,
    );
    expect(lease.snapshotForDisplay(), isNull);
    expect(lease.isCurrent, isFalse);
  });

  testWidgets('no journal survives explicit logout and subsequent new session',
      (tester) async {
    final journal = VisionSessionJournal();
    final first = journal.startSession(isSessionCurrent: () => true);
    first.record(area: 'fcm', code: 'old', platform: 'android');
    journal.revoke();
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: first),
    ));
    expect(find.text('fcm / old'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    final second = journal.startSession(isSessionCurrent: () => true);
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(key: const ValueKey('new'), lease: second),
    ));
    expect(find.text('fcm / old'), findsNothing);
    expect(find.text('Nu există erori locale în jurnal.'), findsOneWidget);
  });

  testWidgets('logout immediately hides a mounted diagnostic without tap',
      (tester) async {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    lease.record(area: 'ocr', code: 'only_before_logout', platform: 'android');
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: lease),
    ));
    expect(find.text('ocr / only_before_logout'), findsOneWidget);

    journal.revoke(); // AuthGate logout, without parent pumpWidget or tap.
    await tester.pumpAndSettle();
    expect(find.text('ocr / only_before_logout'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(find.byTooltip('Copiază raport tehnic anonimizat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new epoch automatically invalidates mounted A before B route swap',
      (tester) async {
    final journal = VisionSessionJournal();
    final a = journal.startSession(isSessionCurrent: () => true);
    a.record(area: 'ocr', code: 'only_A', platform: 'android');
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: a),
    ));
    expect(find.text('ocr / only_A'), findsOneWidget);

    final b = journal.startSession(isSessionCurrent: () => true);
    b.record(area: 'gps', code: 'only_B', platform: 'android');
    await tester.pumpAndSettle();
    expect(find.text('ocr / only_A'), findsNothing);
    expect(find.text('gps / only_B'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);

    // Same widget type, different lease: didUpdateWidget must resubscribe.
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: b),
    ));
    expect(find.text('gps / only_B'), findsOneWidget);
    journal.revoke();
    await tester.pumpAndSettle();
    expect(find.text('gps / only_B'), findsNothing);
    expect(find.textContaining('istoricul poate fi izolat sigur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed lease adapter never tries to rebuild on later logout',
      (tester) async {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    lease.record(area: 'gps', code: 'temporary', platform: 'web');
    await tester.pumpWidget(MaterialApp(
      home: VisionScopedDiagnosticsPage(lease: lease),
    ));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    journal.revoke();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('revocation listeners are single-shot and removable without timers', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    var calls = 0;
    final cancel = lease.listenRevocation(() => calls++);
    final cancelAnother = lease.listenRevocation(() => calls += 10);
    cancelAnother();
    journal.revoke();
    expect(calls, 1);
    journal.revoke();
    expect(calls, 1);
    cancel(); // Safe even after the journal discarded its listener set.
    expect(lease.isCurrent, isFalse);
  });

  test('faulty revocation subscriber cannot stop clearing the log', () {
    final journal = VisionSessionJournal();
    final lease = journal.startSession(isSessionCurrent: () => true);
    lease.record(area: 'fcm', code: 'stored_before_logout', platform: 'android');
    var success = 0;
    lease.listenRevocation(() => throw StateError('UI disposed unexpectedly'));
    lease.listenRevocation(() => success++);
    journal.revoke();
    expect(success, 1);
    expect(lease.entries, isEmpty);
    final after = journal.startSession(isSessionCurrent: () => true);
    expect(after.entries, isEmpty);
  });

  test('old lease cannot subscribe to or revoke replacement owner', () {
    final journal = VisionSessionJournal();
    final old = journal.startSession(isSessionCurrent: () => true);
    final current = journal.startSession(isSessionCurrent: () => true);
    current.record(area: 'gps', code: 'new_only', platform: 'android');
    var calls = 0;
    old.listenRevocation(() => calls++);
    expect(old.isCurrent, isFalse);
    expect(current.entries.single.code, 'new_only');
    journal.revoke();
    expect(calls, 0);
  });
}
