import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/models/location_status_and_functions.dart';
import 'package:andi_carpeta/models/default_categories_functions.dart';
import 'package:andi_carpeta/models/location_category_helpers.dart';
import 'package:andi_carpeta/models/permission_status_labels.dart';
import 'package:andi_carpeta/main.dart' as legacy;

void main() {
  test('main exports the same model and enum identities for existing consumers', () {
    expect(identical(LocationType.magic, legacy.LocationType.magic), isTrue);
    final LocationCategory category = legacy.LocationCategory(
      id: 'custom', name: 'Custom', colorValue: Colors.indigo.value,
    );
    final legacy.FunctionDefinition function = FunctionDefinition(
      id: 'driver', name: 'Driver', iconKey: 'badge_driver', colorValue: 0,
    );
    expect(category.color.toARGB32(), Colors.indigo.toARGB32());
    expect(function.badgeKeys, ['badge_driver']);
  });

  test('legacy type mappings and unknown categories preserve their fallback', () {
    expect(defaultCategoryIdForType(LocationType.other), 'cazari');
    expect(legacyTypeForCategory('unknown'), LocationType.other);
    expect(categoryName([], 'unknown'), 'Altele');
    expect(categoryName([], 'unknown', fallbackType: LocationType.magic), 'MAGIC');
  });

  test('fixed brand colors still override editable category colors', () {
    final categories = [
      LocationCategory(id: 'million', name: 'Custom Million', colorValue: Colors.green.value),
      LocationCategory(id: 'magic', name: 'Custom Magic', colorValue: Colors.green.value),
    ];
    expect(categoryColor(categories, 'million'), Colors.red);
    expect(categoryColor(categories, 'magic'), Colors.black87);
    expect(categoryName(categories, 'million'), 'Custom Million');
    expect(categoryColor([], 'unknown', fallbackType: LocationType.horeca), Colors.amber);
  });

  test('function badge normalization and default mutable collections are unchanged', () {
    final definition = FunctionDefinition(
      id: 'mixed', name: 'Mixed', iconKey: 'legacy',
      badgeKeys: [' ', 'first', 'second', 'third', 'fourth'], colorValue: 0,
    );
    expect(definition.badgeKeys, ['first', 'second', 'third']);
    expect(definition.iconKey, 'first');
    final other = FunctionDefinition(id: 'other', name: 'Other', iconKey: 'fallback', colorValue: 0);
    definition.permissions.add('custom');
    expect(other.permissions, isEmpty);
    expect(other.active, isTrue);
    expect(other.badgeKeys, ['fallback']);
  });

  test('default catalogs remain fresh objects and admin keeps the exact permission set', () {
    final first = defaultLocationCategories();
    final second = defaultLocationCategories();
    expect(first.map((e) => e.id), ['million', 'magic', 'horeca', 'cazari']);
    first.first.name = 'Edited';
    expect(second.first.name, 'Million');
    final admin = defaultFunctionDefinitions().single;
    expect(admin.permissions, FunctionPermission.values.map((e) => e.name).toSet());
    expect(functionById([admin], 'admin'), same(admin));
    expect(functionById([admin], 'absent'), isNull);
    for (final permission in FunctionPermission.values) {
      expect(functionPermissionId(permission), permission.name);
      expect(functionPermissionGroup(permission), isNotEmpty);
      expect(permission.label, isNotEmpty);
    }
    expect(PerDiemStatus.confirmed.label, 'Confirmată');
    expect(PerDiemPaymentMethod.cash.label, 'Numerar');
    expect(LocationStatus.temporarilyClosed.icon, Icons.pause_circle_outline);
  });
}
