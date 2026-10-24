/// Default values for a manually entered execution, based on its start time.
///
/// Keeping the selected date aligned with START makes the default safe across
/// midnight: a 00:15 entry starts at 23:15 on the preceding calendar day.
class ManualExecutionDefaults {
  const ManualExecutionDefaults({
    required this.date,
    required this.startTime,
    required this.finishTime,
  });

  final DateTime date;
  final String startTime;
  final String finishTime;
}

ManualExecutionDefaults createManualExecutionDefaults(DateTime now) {
  final start = now.subtract(const Duration(hours: 1));
  String formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return ManualExecutionDefaults(
    date: DateTime(start.year, start.month, start.day),
    startTime: formatTime(start),
    finishTime: formatTime(now),
  );
}
