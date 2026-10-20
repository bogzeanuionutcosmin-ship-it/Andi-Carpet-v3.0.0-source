import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  app.ScheduleItem item(String id, int order) => app.ScheduleItem(
        locationId: id,
        locationNameSnapshot: 'Locația $id',
        addressSnapshot: 'Adresa $id',
        typeSnapshot: app.LocationType.magic,
        categoryIdSnapshot: 'categoria-$id',
        order: order,
        transferred: id == 'b',
        facadePlanned: id == 'd',
      );

  List<String> ids(List<app.ScheduleItem> items) =>
      items.map((item) => item.locationId).toList();

  test('moving down follows ReorderableListView newIndex convention', () {
    final source = [item('a', 7), item('b', 8), item('c', 9), item('d', 10)];

    final result = app.reorderScheduleItems(source, 1, 4)!;

    expect(ids(result), ['a', 'c', 'd', 'b']);
    expect(result.map((item) => item.order), [1, 2, 3, 4]);
    expect(ids(source), ['a', 'b', 'c', 'd']);
    expect(source.map((item) => item.order), [7, 8, 9, 10]);
    expect(identical(result[3], source[1]), isFalse);
    expect(result[3].locationNameSnapshot, 'Locația b');
    expect(result[3].addressSnapshot, 'Adresa b');
    expect(result[3].typeSnapshot, app.LocationType.magic);
    expect(result[3].categoryIdSnapshot, 'categoria-b');
    expect(result[3].transferred, isTrue);
    expect(result[3].facadePlanned, isFalse);
  });

  test('moving up renumbers items and preserves their snapshots and flags', () {
    final source = [item('a', 1), item('b', 2), item('c', 3), item('d', 4)];

    final result = app.reorderScheduleItems(source, 3, 1)!;

    expect(ids(result), ['a', 'd', 'b', 'c']);
    expect(result.map((item) => item.order), [1, 2, 3, 4]);
    expect(ids(source), ['a', 'b', 'c', 'd']);
    expect(result[1].locationNameSnapshot, 'Locația d');
    expect(result[1].facadePlanned, isTrue);
  });

  test('boundary move to end uses the raw newIndex before decrement', () {
    final source = [item('a', 1), item('b', 2), item('c', 3)];

    final result = app.reorderScheduleItems(source, 0, 3)!;

    expect(ids(result), ['b', 'c', 'a']);
    expect(result.map((item) => item.order), [1, 2, 3]);
    expect(ids(source), ['a', 'b', 'c']);
  });

  test('invalid indexes are rejected without changing source items', () {
    final source = [item('a', 1), item('b', 2), item('c', 3)];

    expect(app.reorderScheduleItems(source, -1, 0), isNull);
    expect(app.reorderScheduleItems(source, 3, 0), isNull);
    expect(app.reorderScheduleItems(source, 0, -1), isNull);
    expect(app.reorderScheduleItems(source, 0, 4), isNull);
    expect(app.reorderScheduleItems(<app.ScheduleItem>[], 0, 0), isNull);
    expect(ids(source), ['a', 'b', 'c']);
    expect(source.map((item) => item.order), [1, 2, 3]);
  });

  test('effective no-op indexes return null and preserve the source', () {
    final source = [item('a', 1), item('b', 2), item('c', 3)];

    expect(app.reorderScheduleItems(source, 1, 1), isNull);
    // Moving one position down reports newIndex as oldIndex + 1.
    expect(app.reorderScheduleItems(source, 1, 2), isNull);
    expect(ids(source), ['a', 'b', 'c']);
  });
}
