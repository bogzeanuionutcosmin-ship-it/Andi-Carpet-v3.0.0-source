import 'app_enums.dart';

String defaultCategoryIdForType(LocationType type) => switch (type) {
  LocationType.magic => 'magic',
  LocationType.million => 'million',
  LocationType.horeca => 'horeca',
  LocationType.other => 'cazari',
};
LocationType legacyTypeForCategory(String categoryId) => switch (categoryId) {
  'magic' => LocationType.magic,
  'million' => LocationType.million,
  'horeca' => LocationType.horeca,
  _ => LocationType.other,
};
