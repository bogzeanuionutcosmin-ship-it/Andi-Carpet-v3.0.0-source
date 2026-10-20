/// One work-graph day and its ordered items as presented in the PDF.
class WorkGraphPdfDayProjection<TDay, TItem> {
  const WorkGraphPdfDayProjection({
    required this.day,
    required this.items,
  });

  final TDay day;
  final List<TItem> items;
}

/// Copies and orders graph days and their items for PDF presentation.
///
/// The selector callbacks keep this projection independent from app-part model
/// declarations. The source lists are never mutated.
List<WorkGraphPdfDayProjection<TDay, TItem>>
    projectWorkGraphPdfDays<TDay, TItem>({
  required List<TDay> days,
  required DateTime Function(TDay day) dateOf,
  required List<TItem> Function(TDay day) itemsOf,
  required int Function(TItem item) orderOf,
}) {
  final orderedDays = [...days]
    ..sort((left, right) => dateOf(left).compareTo(dateOf(right)));

  return orderedDays.map((day) {
    final orderedItems = [...itemsOf(day)]
      ..sort((left, right) => orderOf(left).compareTo(orderOf(right)));
    return WorkGraphPdfDayProjection<TDay, TItem>(
      day: day,
      items: orderedItems,
    );
  }).toList();
}
