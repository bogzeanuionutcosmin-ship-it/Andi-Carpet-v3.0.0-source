import 'package:flutter/material.dart';

import 'app_enums_permissions.dart';
import 'location_category_and_function_definition.dart';

String functionPermissionId(FunctionPermission p) => p.name;

List<LocationCategory> defaultLocationCategories() => <LocationCategory>[
  LocationCategory(id: 'million', name: 'Million', colorValue: Colors.red.value),
  LocationCategory(id: 'magic', name: 'Magic', colorValue: Colors.black87.value),
  LocationCategory(id: 'horeca', name: 'HoReCa', colorValue: Colors.amber.value),
  LocationCategory(id: 'cazari', name: 'Cazări', colorValue: Colors.indigo.value),
];

List<FunctionDefinition> defaultFunctionDefinitions() => <FunctionDefinition>[
  FunctionDefinition(
    id: 'admin',
    name: 'Admin',
    iconKey: 'badge_admin',
    badgeKeys: const <String>['badge_admin'],
    colorValue: Colors.red.value,
    permissions: FunctionPermission.values.map((e) => e.name).toSet(),
  ),
];

FunctionDefinition? functionById(List<FunctionDefinition> defs, String id) {
  for (final f in defs) { if (f.id == id) return f; }
  return null;
}

