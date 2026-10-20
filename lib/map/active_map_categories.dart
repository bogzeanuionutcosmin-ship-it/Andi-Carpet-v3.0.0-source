/// Returns active map categories sorted by their case-insensitive display name.
///
/// Accessors keep this policy independent of the application's category model.
List<T> activeMapCategoriesSorted<T>(
  Iterable<T> categories, {
  required bool Function(T) isActive,
  required String Function(T) nameOf,
}) {
  final active = categories.where(isActive).toList();
  active.sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
  return active;
}
