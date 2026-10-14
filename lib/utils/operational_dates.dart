import '../models/app_data_models.dart';

String two(int n) => n.toString().padLeft(2, '0');
String formatDate(DateTime d) {
  const days = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
  const months = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
  return '${days[d.weekday - 1]}-${d.day}-${months[d.month - 1]}-${d.year}';
}
String formatMonth(DateTime d) {
  const months = ['ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', 'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'];
  return '${months[d.month - 1]}-${d.year}';
}
String timeText(DateTime? d) => d == null ? '--:--' : '${two(d.hour)}:${two(d.minute)}';
String durationText(Duration? d) {
  if (d == null) return '--';
  final mins = d.inMinutes.abs();
  return '${mins ~/ 60}h ${two(mins % 60)} min';
}
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime operationalWorkDate(DateTime now) {
  final startTonight = DateTime(now.year, now.month, now.day, 23, 30);
  if (!now.isBefore(startTonight)) {
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }
  return DateTime(now.year, now.month, now.day);
}

DateTime workWindowStart(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day).subtract(const Duration(days: 1)).add(const Duration(hours: 23, minutes: 30));
DateTime workWindowEnd(DateTime workDate) => DateTime(workDate.year, workDate.month, workDate.day, 9, 30);
bool isInsideWorkWindow(DateTime now, DateTime workDate) => !now.isBefore(workWindowStart(workDate)) && !now.isAfter(workWindowEnd(workDate));
bool recordBelongsToWorkDate(CentralizerRecord r, DateTime workDate) {
  final t = r.startedAt ?? r.waitingStartedAt ?? r.finishedAt ?? r.waitingEndedAt;
  if (t == null) return false;
  final start = workWindowStart(workDate);
  final end = workWindowEnd(workDate).add(const Duration(hours: 3));
  return !t.isBefore(start) && !t.isAfter(end);
}

DateTime recordEventTime(CentralizerRecord r) =>
    r.finishedAt ?? r.startedAt ?? r.waitingStartedAt ?? r.waitingEndedAt ?? DateTime(1900);

