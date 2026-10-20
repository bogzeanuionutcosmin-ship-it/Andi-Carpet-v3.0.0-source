import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/models/app_enums_permissions.dart';
import 'package:andi_carpeta/models/default_categories_functions.dart';

void main() {
  test('default categories retain their established IDs, labels, and colors', () {
    final categories = defaultLocationCategories();
    expect(categories.map((item) => item.id).toList(),
        ['million', 'magic', 'horeca', 'cazari']);
    expect(categories.map((item) => item.name).toList(),
        ['Million', 'Magic', 'HoReCa', 'Cazări']);
    expect(categories.map((item) => item.colorValue).toList(),
        [Colors.red.value, Colors.black87.value, Colors.amber.value, Colors.indigo.value]);
  });

  test('default Admin permissions remain exhaustive and ID lookup is unchanged', () {
    final definitions = defaultFunctionDefinitions();
    expect(definitions, hasLength(1));
    final admin = definitions.single;
    expect(admin.id, 'admin');
    expect(admin.name, 'Admin');
    expect(admin.iconKey, 'badge_admin');
    expect(admin.badgeKeys, ['badge_admin']);
    expect(admin.permissions, FunctionPermission.values.map((value) => value.name).toSet());
    expect(functionPermissionId(FunctionPermission.manageSettings), 'manageSettings');
    expect(functionById(definitions, 'admin'), same(admin));
    expect(functionById(definitions, 'missing'), isNull);
  });
}
