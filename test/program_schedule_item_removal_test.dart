import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  app.ScheduleItem item(
    String id,
    int order, {
    bool transferred = false,
    bool facadePlanned = false,
  }) =>
      app.ScheduleItem(
        locationId: id,
        locationNameSnapshot: 'Locația $id',
        addressSnapshot: 'Adresa $id',
        typeSnapshot: app.LocationType.magic,
        categoryIdSnapshot: 'categoria-$id',
        order: order,
        transferred: transferred,
        facadePlanned: facadePlanned,
      );

  List<String> ids(List<app.ScheduleItem> items) =>
      items.map((item) => item.locationId).toList();

  test('removes the matching location and renumbers the remaining items', () {
    final source = [
      item('a', 4),
      item('b', 8, transferred: true),
      item('c', 12, facadePlanned: true),
    ];

    final result = app.removeProgramScheduleItem(
      source,
      locationId: 'b',
      order: 8,
    );

    expect(ids(result), ['a', 'c']);
    expect(result.map((entry) => entry.order), [1, 2]);
    expect(result[1].locationNameSnapshot, 'Locația c');
    expect(result[1].addressSnapshot, 'Adresa c');
    expect(result[1].typeSnapshot, app.LocationType.magic);
    expect(result[1].categoryIdSnapshot, 'categoria-c');
    expect(result[1].facadePlanned, isTrue);
    expect(ids(source), ['a', 'b', 'c']);
    expect(source.map((entry) => entry.order), [4, 8, 12]);
    expect(identical(result.first, source.first), isFalse);
  });

  test('removes all entries matching both the location and order', () {
    final source = [item('a', 1), item('b', 2), item('b', 2), item('c', 4)];

    final result = app.removeProgramScheduleItem(
      source,
      locationId: 'b',
      order: 2,
    );

    expect(ids(result), ['a', 'c']);
    expect(result.map((entry) => entry.order), [1, 2]);
  });

  test('missing key preserves entries while normalizing order', () {
    final source = [item('a', 5), item('b', 9)];

    final result = app.removeProgramScheduleItem(
      source,
      locationId: 'missing',
      order: 10,
    );

    expect(ids(result), ['a', 'b']);
    expect(result.map((entry) => entry.order), [1, 2]);
    expect(source.map((entry) => entry.order), [5, 9]);
  });

  test('empty schedule returns an empty result', () {
    expect(
      app.removeProgramScheduleItem(
        <app.ScheduleItem>[],
        locationId: 'missing',
        order: 1,
      ),
      isEmpty,
    );
  });
}
