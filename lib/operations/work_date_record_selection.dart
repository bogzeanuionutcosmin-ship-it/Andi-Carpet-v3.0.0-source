/// Selects records for one team, location, and caller-defined work date.
///
/// The predicate and accessors keep this list policy independent of the
/// application record model and its operational-date implementation.
List<T> selectWorkDateRecords<T>(
  Iterable<T> records, {
  required String teamId,
  required String locationId,
  required String Function(T) teamIdOf,
  required String Function(T) locationIdOf,
  required bool Function(T) belongsToWorkDate,
}) {
  return records
      .where((record) =>
          teamIdOf(record) == teamId &&
          locationIdOf(record) == locationId &&
          belongsToWorkDate(record))
      .toList();
}
