part of '../main.dart';

LocationType legacyTypeForCategory(String categoryId) => switch (categoryId) {
  'magic' => LocationType.magic,
  'million' => LocationType.million,
  'horeca' => LocationType.horeca,
  _ => LocationType.other,
};
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

