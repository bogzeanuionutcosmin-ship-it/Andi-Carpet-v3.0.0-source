import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/location_category_and_function_definition.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('location category retains mutable fields and color mapping', () {
    final category = LocationCategory(id: 'a', name: 'Initial', colorValue: 0xff123456);
    expect(category.active, isTrue);
    expect(category.color.value, 0xff123456);
    category.name = 'Updated';
    category.active = false;
    expect(category.name, 'Updated');
    expect(category.active, isFalse);
    final exported = app.LocationCategory(id: 'b', name: 'Main', colorValue: 0xffabcdef);
    expect(exported.color.value, 0xffabcdef);
  });

  test('function definition preserves legacy fallback and badge limit', () {
    final fallback = FunctionDefinition(id: '1', name: 'Role', iconKey: 'badge_driver', colorValue: 0xff123456);
    expect(fallback.badgeKeys, ['badge_driver']);
    expect(fallback.iconKey, 'badge_driver');
    expect(fallback.permissions, isEmpty);
    expect(fallback.active, isTrue);

    final multiple = FunctionDefinition(
      id: '2', name: 'Role', iconKey: 'old', colorValue: 0xff123456,
      badgeKeys: [' ', 'badge_worker', 'badge_driver', 'badge_cleaner', 'badge_extra'],
      permissions: {'read', 'write'}, active: false,
    );
    expect(multiple.badgeKeys, ['badge_worker', 'badge_driver', 'badge_cleaner']);
    expect(multiple.iconKey, 'badge_worker');
    expect(multiple.permissions, {'read', 'write'});
    expect(multiple.active, isFalse);
    expect(multiple.color.value, 0xff123456);

    final exported = app.FunctionDefinition(
      id: '3', name: 'Main', iconKey: 'badge_worker', colorValue: 0xff000000,
    );
    expect(exported.badgeKeys, ['badge_worker']);
  });

  test('function definition keeps legacy empty-list and duplicate behavior', () {
    final empty = FunctionDefinition(id: '4', name: 'Empty', iconKey: 'legacy', colorValue: 0, badgeKeys: []);
    expect(empty.badgeKeys, ['legacy']);
    final duplicates = FunctionDefinition(id: '5', name: 'Duplicates', iconKey: 'old', colorValue: 0,
      badgeKeys: ['badge_a', 'badge_a', 'badge_b', 'badge_c']);
    expect(duplicates.badgeKeys, ['badge_a', 'badge_a', 'badge_b']);
    expect(duplicates.iconKey, 'badge_a');
  });
}
