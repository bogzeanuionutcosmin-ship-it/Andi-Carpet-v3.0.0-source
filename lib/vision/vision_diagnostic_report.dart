import 'vision_error_log.dart';

/// A small, explicit, device-only diagnostic handoff.
/// No names, UIDs, phone numbers, raw exceptions, GPS, OCR text or tokens.
class VisionDiagnosticReport {
  VisionDiagnosticReport._();

  static const int maxEvents = 100;
  static const int maxCharacters = 16000;

  // The offline persistence probe is evidence of a test, not a malfunction.
  // Only this exact fixed tuple is excluded from real incident counts.
  static bool _isPersistenceProbe(VisionErrorEntry entry) =>
      entry.area == 'vision_test' && entry.code == 'persistence_probe';

  static String build(VisionErrorLog log, {DateTime? generatedAt}) {
    // A human handoff must not bury an older critical open incident below
    // 100 recent warnings. Sort a copy: the local journal is never mutated.
    final entries = log.entries.toList()
      ..sort((a, b) {
        // Export real faults before test probes, regardless of severity.
        final aProbe = _isPersistenceProbe(a);
        final bProbe = _isPersistenceProbe(b);
        if (aProbe != bProbe) return aProbe ? 1 : -1;
        if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
        final severity = b.severity.index.compareTo(a.severity.index);
        if (severity != 0) return severity;
        final lastSeen = b.lastSeen.compareTo(a.lastSeen);
        if (lastSeen != 0) return lastSeen;
        return a.fingerprint.compareTo(b.fingerprint);
      });
    final probes = entries.where(_isPersistenceProbe);
    final probeCount = probes.length;
    // A single fingerprint can aggregate many manual taps. Count occurrences
    // separately, including probes omitted by the 100-line export cap.
    final probeOccurrences =
        probes.fold<int>(0, (total, entry) => total + entry.count);
    final incidentCount = entries.length - probeCount;
    // Use fingerprint counts for state and severity, not occurrence totals.
    // A single repeated event remains one incident in the summary.
    final realIncidents = entries.where((entry) => !_isPersistenceProbe(entry));
    final openIncidents = realIncidents.where((entry) => !entry.resolved);
    final openCritical = openIncidents
        .where((entry) => entry.severity == VisionErrorSeverity.critical).length;
    final openErrors = openIncidents
        .where((entry) => entry.severity == VisionErrorSeverity.error).length;
    final openWarnings = openIncidents
        .where((entry) => entry.severity == VisionErrorSeverity.warning).length;
    final openCount = openCritical + openErrors + openWarnings;
    final resolvedCount = incidentCount - openCount;
    // Counts are already bounded by the log; report all occurrences even
    // when individual lines are omitted from the limited export.
    final incidentOccurrences = entries
        .where((entry) => !_isPersistenceProbe(entry))
        .fold<int>(0, (total, entry) => total + entry.count);
    final at = (generatedAt ?? DateTime.now()).toUtc();
    final report = StringBuffer()
      ..writeln('AndiCarpet Vision - raport tehnic local')
      ..writeln('Generat UTC: ${at.toIso8601String()}')
      ..writeln('Sursa: exclusiv acest dispozitiv; fara upload automat.')
      ..writeln('Continut: doar coduri tehnice validate, fara date personale.')
      ..writeln('Incidente locale: $incidentCount')
      ..writeln('Aparitii ale incidentelor: $incidentOccurrences')
      ..writeln('Incidente deschise: $openCount '
          '(critice: $openCritical, erori: $openErrors, '
          'avertizari: $openWarnings)')
      ..writeln('Incidente rezolvate: $resolvedCount');
    if (probeCount > 0) {
      report.writeln('Probe locale (nu sunt erori): $probeCount tipuri');
      report.writeln('Aparitii ale probelor locale: $probeOccurrences');
    }

    if (incidentCount == 0) {
      report.writeln('Nu exista incidente in jurnalul local.');
      report.writeln('Absenta incidentelor nu dovedeste lipsa defectelor.');
      if (entries.isEmpty) return report.toString();
    }

    var included = 0;
    for (final entry in entries.take(maxEvents)) {
      // The in-memory model can also be injected by tests. Validate again
      // at the export boundary rather than trusting arbitrary string fields.
      final area = VisionErrorLog.safeCode(entry.area);
      final code = VisionErrorLog.safeCode(entry.code);
      final platform = VisionErrorLog.safeCode(entry.platform);
      final probe = _isPersistenceProbe(entry);
      final kind = probe ? 'test' : entry.severity.name;
      final state = probe
          ? 'proba_locala'
          : (entry.resolved ? 'rezolvat' : 'deschis');
      final line = '${entry.lastSeen.toUtc().toIso8601String()} | '
          '$area/$code | $platform | $kind | '
          'repetari=${entry.count < 0 ? 0 : entry.count} | $state\n';
      if (report.length + line.length + 120 > maxCharacters) break;
      report.write(line);
      included++;
    }
    if (included < entries.length) {
      report.writeln('Nota: raport limitat la $included evenimente din '
          '${entries.length}; restul nu sunt incluse.');
    }
    report.writeln('Nu sunt colectate mesaje brute sau fisiere.');
    return report.toString();
  }
}
