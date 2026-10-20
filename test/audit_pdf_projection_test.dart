import 'package:flutter_test/flutter_test.dart';

import 'package:andi_carpeta/reports/audit_pdf_projection.dart';

class _AuditEntry {
  const _AuditEntry(this.at, this.actor, this.action, this.target);

  final DateTime at;
  final String actor;
  final String action;
  final String target;
}

void main() {
  test('keeps source order, duplicate rows, and the exact selected fields', () {
    final late = _AuditEntry(
      DateTime(2026, 10, 20, 12),
      'Ana',
      'updated',
      'location-2',
    );
    final early = _AuditEntry(
      DateTime(2026, 10, 19, 8),
      'Ion',
      'created',
      'location-1',
    );
    final entries = [late, early, late];

    final rows = projectAuditPdfRows<_AuditEntry>(
      entries: entries,
      dateOf: (entry) => entry.at,
      actorOf: (entry) => entry.actor,
      actionOf: (entry) => entry.action,
      targetOf: (entry) => entry.target,
    );

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.at), [late.at, early.at, late.at]);
    expect(rows.map((row) => row.actor), ['Ana', 'Ion', 'Ana']);
    expect(rows.map((row) => row.action), ['updated', 'created', 'updated']);
    expect(
      rows.map((row) => row.target),
      ['location-2', 'location-1', 'location-2'],
    );
    expect(entries, [late, early, late]);
  });

  test('returns no rows for an empty audit input', () {
    final rows = projectAuditPdfRows<_AuditEntry>(
      entries: const [],
      dateOf: (entry) => entry.at,
      actorOf: (entry) => entry.actor,
      actionOf: (entry) => entry.action,
      targetOf: (entry) => entry.target,
    );

    expect(rows, isEmpty);
  });
}
