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
}
