/// Returns active graph IDs once each, preserving their first schedule order.
List<String> activeMapRouteGraphIds<T>(
  Iterable<T> schedules, {
  required String? teamId,
  required String Function(T) graphIdOf,
  required String Function(T) teamIdOf,
  required bool Function(T) startedOf,
  required bool Function(T) closedOf,
}) {
  final active = schedules.where((schedule) =>
      startedOf(schedule) &&
      !closedOf(schedule) &&
      (teamId == null || teamIdOf(schedule) == teamId));
  final graphIds = <String>[];
  for (final schedule in active) {
    final graphId = graphIdOf(schedule);
    if (!graphIds.contains(graphId)) graphIds.add(graphId);
  }
  return graphIds;
}

/// Keeps an explicitly requested route when active, otherwise uses the first
/// active route. Returns null when there is no active route.
String? selectedActiveMapRouteGraphId(
  List<String> activeGraphIds,
  String? requestedGraphId,
) {
  if (activeGraphIds.isEmpty) return null;
  return requestedGraphId != null && activeGraphIds.contains(requestedGraphId)
      ? requestedGraphId
      : activeGraphIds.first;
}

/// Returns the active days for one graph, sorted by their existing date field.
List<T> mapRouteDays<T>(
  Iterable<T> schedules, {
  required String graphId,
  required String Function(T) graphIdOf,
  required bool Function(T) startedOf,
  required bool Function(T) closedOf,
  required DateTime Function(T) dateOf,
}) =>
    schedules
        .where((schedule) =>
            graphIdOf(schedule) == graphId &&
            startedOf(schedule) &&
            !closedOf(schedule))
        .toList()
      ..sort((a, b) => dateOf(a).compareTo(dateOf(b)));
