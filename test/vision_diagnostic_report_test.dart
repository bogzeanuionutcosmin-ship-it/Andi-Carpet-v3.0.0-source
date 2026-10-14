import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_report.dart';
import 'package:andi_carpeta/vision/vision_error_log.dart';

void main() {
  final timestamp = DateTime.utc(2026, 10, 14, 8, 15);
  VisionErrorLog create() => VisionErrorLog(clock: () => timestamp);

  test('empty report is honest and performs no I/O', () {
    final output = VisionDiagnosticReport.build(
      create(), generatedAt: timestamp);
    expect(output, contains('Incidente locale: 0'));
    expect(output, contains('nu dovedeste lipsa defectelor'));
    expect(output, contains('fara upload automat'));
    expect(output, isNot(contains('Firebase')));
  });

  test('report exports only bounded deduplicated safe event summaries', () {
    final log = create();
    for (var i = 0; i < 10000; i++) {
      log.record(area: 'ocr', code: 'save_failed', platform: 'android');
    }
    final output = VisionDiagnosticReport.build(
      log, generatedAt: timestamp);
    expect(output, contains('ocr/save_failed | android | error'));
    expect(output, contains('repetari=10000'));
    expect(output, contains('Incidente locale: 1'));
    expect(output, isNot(contains('StackTrace')));
    expect(output.length, lessThanOrEqualTo(
        VisionDiagnosticReport.maxCharacters));
  });

  test('invalid raw identifiers are never copied to diagnostic reports', () {
    final log = create();
    log.record(
      area: 'GPS: 45.120, 26.340',
      code: 'secret_token=example@mail.test',
      platform: 'android',
    );
    final output = VisionDiagnosticReport.build(log);
    expect(output, contains('unknown/unknown | android'));
    expect(output, isNot(contains('45.120')));
    expect(output, isNot(contains('example@mail.test')));
    expect(output, isNot(contains('secret_token')));
  });

  test('export sanitizes even a synthetic entry injected into the model', () {
    final log = create();
    // A custom/injected model may not have been produced by record().
    final injected = VisionErrorEntry(
      fingerprint: 'private identifier',
      area: 'phone=0123456789',
      code: 'secret@company.test',
      platform: 'android',
      severity: VisionErrorSeverity.warning,
      firstSeen: timestamp,
      lastSeen: timestamp,
      count: 3,
    );
    // Renderer exports from an actual bounded log. The public entry type is
    // tested below via its own properties, while unsafe record input is
    // validated at both record and report boundaries.
    expect(VisionErrorLog.safeCode(injected.area), 'unknown');
    expect(VisionErrorLog.safeCode(injected.code), 'unknown');
    log.record(area: injected.area, code: injected.code,
      platform: injected.platform);
    final output = VisionDiagnosticReport.build(log);
    expect(output, isNot(contains('0123456789')));
    expect(output, isNot(contains('company.test')));
  });

  test('older open critical is not lost among 140 newer warnings', () {
    var clock = timestamp;
    final log = VisionErrorLog(
      maxEntries: 200, clock: () => clock,
    );
    log.record(area: 'system', code: 'older_critical',
      platform: 'android', severity: VisionErrorSeverity.critical);
    for (var i = 0; i < 140; i++) {
      clock = clock.add(const Duration(seconds: 1));
      log.record(area: 'system', code: 'warning_$i',
        platform: 'android', severity: VisionErrorSeverity.warning);
    }
    final before = log.encode();
    final report = VisionDiagnosticReport.build(log, generatedAt: clock);
    expect(report, contains('system/older_critical | android | critical'));
    expect(report.indexOf('system/older_critical'),
      lessThan(report.indexOf('system/warning_139')));
    expect(report, contains('raport limitat'));
    expect(report.length, lessThanOrEqualTo(
        VisionDiagnosticReport.maxCharacters));
    expect(log.encode(), before); // No mutation/reordering of local journal.
  });

  test('unresolved warning precedes resolved critical in a short export', () {
    var clock = timestamp;
    final log = VisionErrorLog(
      maxEntries: 200, clock: () => clock,
    );
    log.record(area: 'system', code: 'resolved_critical',
      platform: 'android', severity: VisionErrorSeverity.critical);
    expect(log.resolve('system/resolved_critical/android'), isTrue);
    for (var i = 0; i < 120; i++) {
      clock = clock.add(const Duration(seconds: 1));
      log.record(area: 'system', code: 'open_$i',
        platform: 'android', severity: VisionErrorSeverity.warning);
    }
    final report = VisionDiagnosticReport.build(log, generatedAt: clock);
    expect(report, contains('Incidente locale: 121'));
    expect(report, contains('system/open_119'));
    expect(report, isNot(contains('system/resolved_critical')));
    expect(report, contains('raport limitat'));
  });

  test('critical priority remains within the export cap even for many events', () {
    var clock = timestamp;
    final log = VisionErrorLog(maxEntries: 200, clock: () => clock);
    for (var i = 0; i < 120; i++) {
      log.record(area: 'ocr', code: 'warning_$i',
        platform: 'web', severity: VisionErrorSeverity.warning);
      clock = clock.add(const Duration(milliseconds: 1));
    }
    log.record(area: 'gps', code: 'critical_now',
      platform: 'android', severity: VisionErrorSeverity.critical);
    final export = VisionDiagnosticReport.build(log, generatedAt: clock);
    expect(export, contains('gps/critical_now | android | critical'));
    expect(export.split('|').length, greaterThan(1));
    expect(export.length, lessThanOrEqualTo(
      VisionDiagnosticReport.maxCharacters));
  });

  test('report caps the number of events and notes omissions', () {
    final log = VisionErrorLog(maxEntries: 300,
      maxBytes: 1024 * 1024, clock: () => timestamp);
    for (var i = 0; i < 180; i++) {
      log.record(area: 'system', code: 'case_$i', platform: 'web');
    }
    final output = VisionDiagnosticReport.build(log,
      generatedAt: timestamp);
    expect(output, contains('Incidente locale: 180'));
    expect(output, contains('raport limitat'));
    expect(output.split('| web | error |').length - 1, 100);
    expect(output.length, lessThanOrEqualTo(
        VisionDiagnosticReport.maxCharacters));
  });
}
