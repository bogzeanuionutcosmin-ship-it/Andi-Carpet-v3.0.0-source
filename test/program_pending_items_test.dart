import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/schedule/program_pending_items.dart';

class _Record {
  const _Record(this.status);

  final String status;
}

List<String> selectPending(
  List<String> items,
  Map<String, _Record> records, {
  bool includeActive = true,
}) =>
    pendingProgramItems<String, _Record>(
      items: items,
      latestRecordForItem: (item) => records[item],
      isTerminal: (record) =>
          record?.status == 'completed' ||
          record?.status == 'refused' ||
          record?.status == 'notCompleted',
      isActive: (record) =>
          record?.status == 'running' || record?.status == 'waitingAccess',
      includeActive: includeActive,
    );

void main() {
  test('keeps items with no record and non-terminal records', () {
    final items = ['none', 'open', 'running'];

    expect(
      selectPending(items, {
        'open': const _Record('planned'),
        'running': const _Record('running'),
      }),
      ['none', 'open', 'running'],
    );
  });

  test('excludes completed, refused, and not-completed items', () {
    expect(
      selectPending(
        ['done', 'refused', 'not-done', 'open'],
        {
          'done': const _Record('completed'),
          'refused': const _Record('refused'),
          'not-done': const _Record('notCompleted'),
          'open': const _Record('planned'),
        },
      ),
      ['open'],
    );
  });

  test('includes running and waiting-access items by default', () {
    expect(
      selectPending(
        ['running', 'waiting'],
        {
          'running': const _Record('running'),
          'waiting': const _Record('waitingAccess'),
        },
      ),
      ['running', 'waiting'],
    );
  });

  test('can exclude active items while retaining other open work', () {
    expect(
      selectPending(
        ['running', 'waiting', 'open'],
        {
          'running': const _Record('running'),
          'waiting': const _Record('waitingAccess'),
          'open': const _Record('planned'),
        },
        includeActive: false,
      ),
      ['open'],
    );
  });

  test('preserves input order without mutating the source iterable', () {
    final items = ['third', 'first', 'second'];
    final before = List<String>.of(items);

    expect(selectPending(items, {}), before);
    expect(items, orderedEquals(before));
  });
}
