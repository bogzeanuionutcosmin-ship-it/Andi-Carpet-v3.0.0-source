import 'app_enums_permissions.dart';

String defaultCategoryIdForType(LocationType type) => switch (type) {
  LocationType.magic => 'magic',
  LocationType.million => 'million',
  LocationType.horeca => 'horeca',
  LocationType.other => 'cazari',
};
