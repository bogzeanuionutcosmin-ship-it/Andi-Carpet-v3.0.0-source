import 'vision_error_log.dart';

/// A small, explicit, device-only diagnostic handoff.
/// No names, UIDs, phone numbers, raw exceptions, GPS, OCR text or tokens.
class VisionDiagnosticReport {
  VisionDiagnosticReport._();

  static const int maxEvents = 100;
  static const int maxCharacters = 16000;

  static String build(VisionErrorLog log, {DateTime? generatedAt}) {
    final entries = log.entries;
    final at = (generatedAt ?? DateTime.now()).toUtc();
    final report = StringBuffer()
      ..writeln('AndiCarpet Vision - raport tehnic local')
      ..writeln('Generat UTC: ${at.toIso8601String()}')
      ..writeln('Sursa: exclusiv acest dispozitiv; fara upload automat.')
      ..writeln('Continut: doar coduri tehnice validate, fara date personale.')
      ..writeln('Incidente locale: ${entries.length}');

    if (entries.isEmpty) {
      report.writeln('Nu exista incidente in jurnalul local.');
      report.writeln('Absenta incidentelor nu dovedeste lipsa defectelor.');
      return report.toString();
    }

    var included = 0;
    for (final entry in entries.take(maxEvents)) {
      // The in-memory model can also be injected by tests. Validate again
      // at the export boundary rather than trusting arbitrary string fields.
      final area = VisionErrorLog.safeCode(entry.area);
      final code = VisionErrorLog.safeCode(entry.code);
      final platform = VisionErrorLog.safeCode(entry.platform);
      final line = '${entry.lastSeen.toUtc().toIso8601String()} | '
          '$area/$code | $platform | ${entry.severity.name} | '
          'repetari=${entry.count < 0 ? 0 : entry.count} | '
          '${entry.resolved ? 'rezolvat' : 'deschis'}\n';
      if (report.length + line.length + 120 > maxCharacters) break;
      report.write(line);
      included++;
    }
    if (included < entries.length) {
      report.writeln('Nota: raport limitat la $included incidente din '
          '${entries.length}; restul nu sunt incluse.');
    }
    report.writeln('Nu sunt colectate mesaje brute sau fisiere.');
    return report.toString();
  }
}
