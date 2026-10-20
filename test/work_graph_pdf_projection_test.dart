import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/reports/work_graph_pdf_projection.dart';

class _Item {
  const _Item(this.order, this.name);

  final int order;
  final String name;
}

class _Day {
  const _Day(this.date, this.items);

  final DateTime date;
  final List<_Item> items;
}

void main() {
  test('orders copied graph days by date and each day items by their order', () {
    final lateDay = _Day(
      DateTime(2026, 10, 16),
      const [_Item(2, 'late item'), _Item(1, 'early item')],
    );
    final earlyDay = _Day(
      DateTime(2026, 10, 15),
      const [_Item(3, 'last'), _Item(1, 'first'), _Item(2, 'middle')],
    );
    final sourceDays = [lateDay, earlyDay];
    final sourceItemOrder = [
      lateDay.items.map((item) => item.name).toList(),
      earlyDay.items.map((item) => item.name).toList(),
    ];

    final projection = projectWorkGraphPdfDays<_Day, _Item>(
      days: sourceDays,
      dateOf: (day) => day.date,
      itemsOf: (day) => day.items,
      orderOf: (item) => item.order,
    );

    expect(
      projection.map((row) => row.day.date),
      [DateTime(2026, 10, 15), DateTime(2026, 10, 16)],
    );
    expect(
      projection.map((row) => row.items.map((item) => item.name).toList()),
      [
        ['first', 'middle', 'last'],
        ['early item', 'late item'],
      ],
    );
    expect(sourceDays, [lateDay, earlyDay]);
    expect(
      [
        lateDay.items.map((item) => item.name).toList(),
        earlyDay.items.map((item) => item.name).toList(),
      ],
      sourceItemOrder,
    );
  });

  test('keeps empty days and empty item lists in the projection', () {
    final empty = _Day(DateTime(2026, 10, 15), const []);
    final projection = projectWorkGraphPdfDays<_Day, _Item>(
      days: [empty],
      dateOf: (day) => day.date,
      itemsOf: (day) => day.items,
      orderOf: (item) => item.order,
    );

    expect(projection, hasLength(1));
    expect(identical(projection.single.day, empty), isTrue);
    expect(projection.single.items, isEmpty);
  });
}
