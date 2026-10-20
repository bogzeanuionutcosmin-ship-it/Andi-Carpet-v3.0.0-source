import '../models/app_enums_permissions.dart';

/// A filtered PDF projection row that retains the original record and its
/// effective event date without depending on the app's part-only model library.
class CentralizerPdfProjectionRow<T> {
  final T record;
  final DateTime date;

  const CentralizerPdfProjectionRow({
    required this.record,
    required this.date,
  });
}

/// Filters and orders intervention records for the Centralizator PDF.
///
/// Accessors keep this helper independent from models declared as parts of
/// main.dart. The caller supplies the exact event-time policy used by its
/// record model.
List<CentralizerPdfProjectionRow<T>> projectCentralizerPdfExecutionRows<T>({
  required List<T> records,
  required LocationType type,
  String? teamId,
  DateTime? from,
  DateTime? to,
  String search = '',
  WorkAttemptStatus? statusFilter,
  required LocationType Function(T record) typeOf,
  required String Function(T record) teamIdOf,
  required WorkAttemptStatus Function(T record) statusOf,
  required String Function(T record) locationNameOf,
  required String Function(T record) addressOf,
  required DateTime Function(T record) eventDateOf,
}) {
  final q = search.trim().toLowerCase();
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final finish = to == null ? null : DateTime(to.year, to.month, to.day + 1);

  final rows = records.where((record) {
    if (typeOf(record) != type) return false;
    if (teamId != null && teamId.isNotEmpty && teamIdOf(record) != teamId) {
      return false;
    }
    if (statusFilter != null && statusOf(record) != statusFilter) return false;
    final eventDate = eventDateOf(record);
    if (start != null && eventDate.isBefore(start)) return false;
    if (finish != null && !eventDate.isBefore(finish)) return false;
    if (q.isNotEmpty &&
        !locationNameOf(record).toLowerCase().contains(q) &&
        !addressOf(record).toLowerCase().contains(q)) {
      return false;
    }
    return true;
  }).map((record) => CentralizerPdfProjectionRow<T>(
        record: record,
        date: eventDateOf(record),
      )).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return rows;
}
