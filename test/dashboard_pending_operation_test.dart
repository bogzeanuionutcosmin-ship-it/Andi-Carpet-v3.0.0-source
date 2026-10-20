import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../lib/dashboard/dashboard_pending_operation.dart';

void main() {
  test('ignores a duplicate key until the first asynchronous action completes', () async {
    final pending = <String>{};
    final firstAction = Completer<void>();
    var calls = 0;

    final first = runDashboardPendingOperation(
      pending: pending,
      key: 'location-a',
      action: () {
        calls++;
        return firstAction.future;
      },
    );
    await runDashboardPendingOperation(
      pending: pending,
      key: 'location-a',
      action: () async => calls++,
    );

    expect(calls, 1);
    expect(pending, <String>{'location-a'});

    firstAction.complete();
    await first;
    expect(pending, isEmpty);
  });

  test('different keys and independent start/finish sets can run concurrently', () async {
    final starts = <String>{};
    final finishes = <String>{};
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    var calls = 0;

    final start = runDashboardPendingOperation(
      pending: starts,
      key: 'location-a',
      action: () {
        calls++;
        return firstGate.future;
      },
    );
    final otherStart = runDashboardPendingOperation(
      pending: starts,
      key: 'location-b',
      action: () {
        calls++;
        return secondGate.future;
      },
    );
    final finish = runDashboardPendingOperation(
      pending: finishes,
      key: 'location-a',
      action: () async {
        calls++;
      },
    );

    await finish;
    expect(calls, 3);
    expect(starts, <String>{'location-a', 'location-b'});
    expect(finishes, isEmpty);

    firstGate.complete();
    secondGate.complete();
    await Future.wait(<Future<void>>[start, otherStart]);
    expect(starts, isEmpty);
  });

  test('releases the key after failure and propagates the original error', () async {
    final pending = <String>{};
    final failure = StateError('write failed');

    await expectLater(
      runDashboardPendingOperation(
        pending: pending,
        key: 'record-a',
        action: () async => throw failure,
      ),
      throwsA(same(failure)),
    );
    expect(pending, isEmpty);

    var retryCalls = 0;
    await runDashboardPendingOperation(
      pending: pending,
      key: 'record-a',
      action: () async => retryCalls++,
    );
    expect(retryCalls, 1);
    expect(pending, isEmpty);
  });
}
