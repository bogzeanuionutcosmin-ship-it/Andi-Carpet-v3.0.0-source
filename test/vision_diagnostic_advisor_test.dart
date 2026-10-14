import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_advisor.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';

void main() {
  late DateTime clock;
  late VisionErrorLog log;

  setUp(() {
    clock = DateTime.utc(2026, 10, 14, 10);
    log = VisionErrorLog(clock: () => clock);
  });

  test('no events means no recommendation and no false health claim', () {
    final insights = VisionDiagnosticAdvisor.assess(log);
    expect(insights, isEmpty);
    expect(log.length, 0);
  });

  test('real OCR save error shows safe manual verification, no retry', () {
    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    final before = log.encode();
    final insights = VisionDiagnosticAdvisor.assess(log);
    expect(insights, hasLength(1));
    expect(insights.single.title, 'Document nesalvat');
    expect(insights.single.explanation,
      contains('Verifică dacă documentul apare'));
    expect(insights.single.explanation, isNot(contains('salvez automat')));
    expect(log.encode(), before); // Advisor cannot mutate diagnostics.
  });

  test('priority is critical before error, regardless of time', () {
    log.record(area: 'gps', code: 'location_update_failed',
      platform: 'android', severity: VisionErrorSeverity.critical);
    clock = clock.add(const Duration(minutes: 1));
    log.record(area: 'fcm', code: 'token_refresh_failed',
      platform: 'android', severity: VisionErrorSeverity.error);
    final insights = VisionDiagnosticAdvisor.assess(log);
    expect(insights, hasLength(2));
    expect(insights.first.title, 'Localizarea necesită atenție');
    expect(insights.last.title, 'Notificările necesită atenție');
  });

  test('resolved events are not active recommendations', () {
    log.record(area: 'finance', code: 'received_amount_save_failed',
      platform: 'android');
    final id = log.entries.single.fingerprint;
    expect(log.resolve(id), isTrue);
    expect(VisionDiagnosticAdvisor.assess(log), isEmpty);
    log.record(area: 'finance', code: 'received_amount_save_failed',
      platform: 'android');
    expect(VisionDiagnosticAdvisor.assess(log).single.title,
      'Operațiune financiară nereușită');
  });

  test('only fixed guidance is displayed for unknown identifiers', () {
    log.record(area: 'private.customer.name@example.com',
      code: 'token=never-export', platform: 'web');
    final message = VisionDiagnosticAdvisor.assess(log).single;
    expect(message.title, 'Incident local observat');
    expect(message.explanation, isNot(contains('example.com')));
    expect(message.explanation, isNot(contains('token')));
    expect(message.explanation, isNot(contains('customer')));
  });

  test('bounded output and optional zero limit do not mutate log', () {
    for (var i = 0; i < 15; i++) {
      clock = clock.add(const Duration(seconds: 1));
      log.record(area: 'unknown', code: 'failure_$i',
        platform: 'android');
    }
    final before = log.encode();
    expect(VisionDiagnosticAdvisor.assess(log, maxInsights: 2),
      hasLength(2));
    expect(VisionDiagnosticAdvisor.assess(log, maxInsights: 0), isEmpty);
    expect(log.encode(), before);
  });

  test('single incident is identified without claiming a measured rate', () {
    log.record(area: 'gps', code: 'background_start_failed',
      platform: 'android');
    final message = VisionDiagnosticAdvisor.assess(log).single;
    expect(message.repeated, isFalse);
    expect(message.occurrenceLabel, 'Observată o singură dată');
    expect(message.occurrences, 1);
  });

  test('two or more observations are marked repeated, no auto-action', () {
    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    log.record(area: 'ocr', code: 'document_save_failed',
      platform: 'android');
    final before = log.encode();
    final message = VisionDiagnosticAdvisor.assess(log).single;
    expect(message.repeated, isTrue);
    expect(message.occurrenceLabel,
      'Repetată: 2 apariții în jurnalul local');
    expect(message.explanation, contains('Verifică dacă documentul apare'));
    expect(log.encode(), before);
  });

  test('repeated error takes priority over a newer one-off of same severity',
      () {
    log.record(area: 'ocr', code: 'recognition_failed',
      platform: 'android');
    log.record(area: 'ocr', code: 'recognition_failed',
      platform: 'android');
    clock = clock.add(const Duration(minutes: 1));
    log.record(area: 'fcm', code: 'token_refresh_failed',
      platform: 'android');
    final insights = VisionDiagnosticAdvisor.assess(log);
    expect(insights.first.title, 'OCR necesită verificare');
    expect(insights.first.repeated, isTrue);
    expect(insights.last.title, 'Notificările necesită atenție');
  });

  test('critical one-off outranks repeated warning, and resolved is ignored',
      () {
    log.record(area: 'fcm', code: 'token_refresh_failed',
      platform: 'android', severity: VisionErrorSeverity.warning);
    log.record(area: 'fcm', code: 'token_refresh_failed',
      platform: 'android', severity: VisionErrorSeverity.warning);
    clock = clock.add(const Duration(minutes: 1));
    log.record(area: 'dart_async', code: 'unknown',
      platform: 'android', severity: VisionErrorSeverity.critical);
    final insights = VisionDiagnosticAdvisor.assess(log);
    expect(insights.first.severity, VisionErrorSeverity.critical);
    expect(insights.first.repeated, isFalse);
    expect(insights.last.repeated, isTrue);
    final criticalId = log.entries.firstWhere(
      (entry) => entry.area == 'dart_async').fingerprint;
    expect(log.resolve(criticalId), isTrue);
    expect(VisionDiagnosticAdvisor.assess(log).single.title,
      'Notificările necesită atenție');
  });

  test('advice about finance remains read-only and avoids false claims', () {
    log.record(area: 'per_diem', code: 'distribution_save_failed',
      platform: 'android');
    final message = VisionDiagnosticAdvisor.assess(log).single;
    expect(message.explanation, contains('Verifică întâi evidența'));
    expect(message.explanation, contains('nu schimbă sume'));
    expect(message.occurrences, 1);
    expect(message.lastSeen, clock);
  });
}
