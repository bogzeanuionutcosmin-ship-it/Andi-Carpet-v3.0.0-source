/// Filters map locations by selected categories, statuses and GPS availability.
/// A category can optionally be restricted for a grouped location panel.
List<T> filterMapLocations<T, S>(
  Iterable<T> locations, {
  required Set<String> selectedCategoryIds,
  required Set<S> selectedStatuses,
  required String Function(T) categoryIdOf,
  required S Function(T) statusOf,
  required bool Function(T) hasCoordinatesOf,
  required bool hasCoordinates,
  String? categoryId,
}) =>
    locations
        .where((location) =>
            selectedCategoryIds.contains(categoryIdOf(location)) &&
            selectedStatuses.contains(statusOf(location)) &&
            hasCoordinatesOf(location) == hasCoordinates &&
            (categoryId == null || categoryIdOf(location) == categoryId))
        .toList();
