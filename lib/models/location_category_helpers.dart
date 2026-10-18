import 'package:flutter/material.dart';
import 'app_enums_permissions.dart';
import 'location_status_and_functions.dart';
import 'location_type_mapping.dart';
export 'location_type_mapping.dart';

Color categoryColor(List<LocationCategory> categories, String categoryId, {LocationType? fallbackType}) {
  // Culorile de brand stabilite inițial rămân fixe peste tot în aplicație.
  if (categoryId == 'million') return Colors.red;
  if (categoryId == 'magic') return Colors.black87;
  for (final c in categories) { if (c.id == categoryId) return c.color; }
  return (fallbackType ?? legacyTypeForCategory(categoryId)).color;
}
String categoryName(List<LocationCategory> categories, String categoryId, {LocationType? fallbackType}) {
  for (final c in categories) { if (c.id == categoryId) return c.name; }
  return (fallbackType ?? legacyTypeForCategory(categoryId)).label;
}

