import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  app.Location location(
    String id, {
    required String name,
    required String address,
    required String categoryId,
  }) =>
      app.Location(
        id: id,
        name: name,
        address: address,
        type: app.LocationType.magic,
        categoryId: categoryId,
      );

  test('creates ordered schedule snapshots and preserves selected facade flags', () {
    final first = location(
      'first',
      name: 'Prima locație',
      address: 'Strada 1',
      categoryId: 'cat-first',
    );
    final second = location(
      'second',
      name: 'A doua locație',
      address: 'Strada 2',
      categoryId: 'cat-second',
    );

    final items = app.createProgramScheduleItems(
      locations: [first, second],
      firstOrder: 7,
      facadePlannedLocationIds: {'second'},
    );

    expect(items.map((item) => item.locationId), ['first', 'second']);
    expect(items.map((item) => item.order), [7, 8]);
    expect(items.map((item) => item.locationNameSnapshot), [
      'Prima locație',
      'A doua locație',
    ]);
    expect(items.map((item) => item.addressSnapshot), ['Strada 1', 'Strada 2']);
    expect(items.map((item) => item.typeSnapshot), [
      app.LocationType.magic,
      app.LocationType.magic,
    ]);
    expect(items.map((item) => item.categoryIdSnapshot), [
      'cat-first',
      'cat-second',
    ]);
    expect(items.map((item) => item.facadePlanned), [false, true]);
    expect(items.every((item) => !item.transferred), isTrue);
    expect(first.name, 'Prima locație');
    expect(second.address, 'Strada 2');
  });

  test('empty additions produce no schedule items', () {
    expect(
      app.createProgramScheduleItems(
        locations: const <app.Location>[],
        firstOrder: 1,
        facadePlannedLocationIds: const <String>{},
      ),
      isEmpty,
    );
  });
}
