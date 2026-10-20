import 'package:flutter_test/flutter_test.dart';

import '../lib/map/map_location_filters.dart';

class _Location {
  final String id;
  final String categoryId;
  final String status;
  final double? latitude;
  final double? longitude;

  const _Location({
    required this.id,
    required this.categoryId,
    required this.status,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

List<_Location> _filter(
  List<_Location> locations, {
  Set<String> categories = const {'carpet'},
  Set<String> statuses = const {'open'},
  bool hasCoordinates = true,
  String? categoryId,
}) =>
    filterMapLocations<_Location, String>(
      locations,
      selectedCategoryIds: categories,
      selectedStatuses: statuses,
      categoryIdOf: (location) => location.categoryId,
      statusOf: (location) => location.status,
      hasCoordinatesOf: (location) => location.hasCoordinates,
      hasCoordinates: hasCoordinates,
      categoryId: categoryId,
    );

void main() {
  const positionedOpen = _Location(
      id: 'positioned-open', categoryId: 'carpet', status: 'open', latitude: 1, longitude: 2);
  const missingLatitude = _Location(
      id: 'missing-latitude', categoryId: 'carpet', status: 'open', longitude: 2);
  const missingLongitude = _Location(
      id: 'missing-longitude', categoryId: 'carpet', status: 'open', latitude: 1);
  const otherCategory = _Location(
      id: 'other-category', categoryId: 'stone', status: 'open', latitude: 1, longitude: 2);
  const otherStatus = _Location(
      id: 'other-status', categoryId: 'carpet', status: 'closed', latitude: 1, longitude: 2);

  test('positioned filter applies selected categories and statuses', () {
    expect(
      _filter([positionedOpen, otherCategory, otherStatus]),
      [positionedOpen],
    );
  });

  test('unpositioned filter includes a missing latitude or longitude', () {
    expect(
      _filter([positionedOpen, missingLatitude, missingLongitude],
          hasCoordinates: false),
      [missingLatitude, missingLongitude],
    );
  });

  test('grouped panel can restrict the selected set to one category', () {
    expect(
      _filter([positionedOpen, otherCategory],
          categories: const {'carpet', 'stone'}, categoryId: 'stone'),
      [otherCategory],
    );
  });

  test('empty selections return no locations', () {
    expect(_filter([positionedOpen], categories: const {}), isEmpty);
    expect(_filter([positionedOpen], statuses: const {}), isEmpty);
  });
}
