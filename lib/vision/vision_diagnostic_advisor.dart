import 'vision_error_log.dart';

/// Deterministic, read-only interpretation of an EXISTING local error log.
///
/// Vision can recommend an inspection, but it must not claim to have diagnosed
/// the root cause, run repairs, change business data or query remote services.
class VisionDiagnosticInsight {
  const VisionDiagnosticInsight({
    required this.title,
    required this.explanation,
    required this.severity,
    required this.occurrences,
    required this.lastSeen,
    required this.repeated,
  });

  final String title;
  final String explanation;
  final VisionErrorSeverity severity;
  final int occurrences;
  final DateTime lastSeen;

  /// At least two occurrences in this local aggregate; not a time-window rate.
  final bool repeated;

  String get occurrenceLabel => repeated
      ? 'Repetată: $occurrences apariții în jurnalul local'
      : 'Observată o singură dată';
}

class VisionDiagnosticAdvisor {
  VisionDiagnosticAdvisor._();

  static List<VisionDiagnosticInsight> assess(
    VisionErrorLog log, {int maxInsights = 3}
  ) {
    if (maxInsights <= 0) return const <VisionDiagnosticInsight>[];
    // Synthetic debugging probes check local persistence; they are not faults.
    // Keep them in the journal/report but never promote them to alerts.
    final incidents = log.entries.where((item) =>
        !item.resolved &&
        !(item.area == 'vision_test' &&
          item.code == 'persistence_probe')).toList()
      ..sort((a, b) {
        final severity = b.severity.index.compareTo(a.severity.index);
        if (severity != 0) return severity;
        // At equal severity, repeat observations merit inspection before
        // one-off incidents. This is not a measured per-minute error rate.
        final repeated = (b.count > 1 ? 1 : 0)
            .compareTo(a.count > 1 ? 1 : 0);
        if (repeated != 0) return repeated;
        final when = b.lastSeen.compareTo(a.lastSeen);
        if (when != 0) return when;
        final count = b.count.compareTo(a.count);
        if (count != 0) return count;
        // Equal severity/time/repetition must yield the same top insight
        // regardless of cached insertion order or restart ordering.
        return a.fingerprint.compareTo(b.fingerprint);
      });

    return List<VisionDiagnosticInsight>.unmodifiable(
      incidents.take(maxInsights).map((item) {
        final message = _knownGuidance(item.area, item.code);
        return VisionDiagnosticInsight(
          title: message.$1,
          explanation: message.$2,
          severity: item.severity,
          occurrences: item.count,
          lastSeen: item.lastSeen,
          repeated: item.count > 1,
        );
      }),
    );
  }

  static (String, String) _knownGuidance(String area, String code) {
    // All text is predefined, never composed from exception payloads,
    // private Firestore fields, locations or user-provided event identifiers.
    if (area == 'ocr' && code == 'saved_amount_mismatch') {
      return (
        'Suma salvată necesită verificare',
        'Verificarea de pe server indică o diferență față de suma așteptată. '
            'Nu retrimite automat documentul; verifică evidența și suma '
            'înainte de orice corecție autorizată.',
      );
    }
    if (area == 'ocr' && code == 'saved_document_missing') {
      return (
        'Documentul nu a fost regăsit',
        'O verificare confirmată pe server nu a regăsit documentul așteptat. '
            'Verifică evidența înainte de a încerca din nou; nu crea duplicate.',
      );
    }
    if (area == 'ocr' && code == 'document_save_failed') {
      return (
        'Salvarea documentului necesită verificare',
        'A apărut o eroare în timpul salvării, dar documentul ar putea '
            'fi deja înregistrat. Verifică evidența înainte de orice '
            'nouă încercare și evită documentele duplicate.',
      );
    }
    if (area == 'ocr') {
      return (
        'OCR necesită verificare',
        'Verifică manual suma și data din document înainte de salvare. '
            'Vision a observat o eroare OCR, nu a validat valorile.',
      );
    }
    if (area == 'gps') {
      return (
        'Localizarea necesită atenție',
        'Verifică permisiunile și precizia GPS. Nu porni sau opri automat '
            'intervențiile pe baza acestui incident.',
      );
    }
    if (area == 'fcm') {
      return (
        'Notificările necesită atenție',
        'Verifică permisiunea de notificări și diagnosticul Push. '
            'Nu presupune că un mesaj a fost livrat.',
      );
    }
    if (area == 'finance' || area == 'per_diem') {
      return (
        'Operațiune financiară nereușită',
        'Verifică întâi evidența și confirmările, înainte de a reîncerca. '
            'Vision nu schimbă sume, diurne sau stări financiare.',
      );
    }
    if (area == 'flutter_framework' || area == 'dart_async') {
      return (
        'Eroare tehnică în aplicație',
        'Consultă jurnalul local și copiază raportul tehnic la cerere. '
            'Cauza exactă nu este determinată automat.',
      );
    }
    return (
      'Incident local observat',
      'Există un eveniment în jurnalul local. Consultă detaliile și '
          'raportul tehnic; cauza exactă nu este confirmată.',
    );
  }
}
