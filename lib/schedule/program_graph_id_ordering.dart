/// Returns each program graph ID once, ordered by its earliest scheduled day,
/// newest graph first. The callback boundary keeps this policy independent from
/// Flutter and the application's schedule model.
List<String> orderedProgramGraphIds<T>({
  required Iterable<T> schedules,
  required String Function(T schedule) graphIdOf,
  required DateTime Function(T schedule) dateOf,
}) {
  final scheduleList = schedules.toList();
  final graphIds = <String>[];
  for (final schedule in scheduleList) {
    final graphId = graphIdOf(schedule);
    if (!graphIds.contains(graphId)) graphIds.add(graphId);
  }
  graphIds.sort((a, b) {
    DateTime firstDate(String graphId) => scheduleList
        .where((schedule) => graphIdOf(schedule) == graphId)
        .map(dateOf)
        .reduce((x, y) => y.isBefore(x) ? y : x);
    return firstDate(b).compareTo(firstDate(a));
  });
  return graphIds;
}
