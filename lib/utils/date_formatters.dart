/// Pure date and duration formatters shared by the main app library.


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


String graphDefaultName(DateTime d) => 'Grafic ${d.month.toString().padLeft(2, '0')}/${d.year}';
