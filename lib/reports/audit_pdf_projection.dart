/// One audit event represented in its existing PDF input order.
class AuditPdfRow {
  const AuditPdfRow({
    required this.at,
    required this.actor,
    required this.action,
    required this.target,
  });

  final DateTime at;
  final String actor;
  final String action;
  final String target;
}

/// Projects audit entries without sorting, filtering, or collapsing duplicates.
List<AuditPdfRow> projectAuditPdfRows<T>({
  required Iterable<T> entries,
  required DateTime Function(T entry) dateOf,
  required String Function(T entry) actorOf,
  required String Function(T entry) actionOf,
  required String Function(T entry) targetOf,
}) {
  return [
    for (final entry in entries)
      AuditPdfRow(
        at: dateOf(entry),
        actor: actorOf(entry),
        action: actionOf(entry),
        target: targetOf(entry),
      ),
  ];
}
