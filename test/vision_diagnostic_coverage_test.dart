import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/vision/vision_diagnostic_coverage.dart';

void main() {
  test('coverage inventory names only modules with reviewed instrumentation', () {
    final areas = VisionDiagnosticCoverage.areas;
    expect(areas, hasLength(7));
    expect(areas.map((area) => area.name).toSet(), hasLength(areas.length));
    expect(areas.where((area) =>
        area.state == VisionCoverageState.partial), hasLength(5));
    expect(areas.where((area) =>
        area.state == VisionCoverageState.notConnected), hasLength(2));
    expect(areas.first.statusLabel, 'Parțial instrumentat');
    expect(areas.last.statusLabel, 'Neconectat la diagnosticul local');
  });

  test('OCR and GPS limits are explicit and do not claim complete coverage', () {
    final areas = VisionDiagnosticCoverage.areas;
    final ocr = areas.singleWhere((area) => area.name == 'OCR');
    final gps = areas.singleWhere((area) => area.name == 'GPS');
    final backend = areas.singleWhere(
      (area) => area.name == 'Firebase Functions / cloud');
    expect(ocr.doesNotVerify, contains('sumei'));
    expect(gps.doesNotVerify, contains('fundalul Android'));
    expect(backend.state, VisionCoverageState.notConnected);
    expect(backend.doesNotVerify, contains('alte dispozitive'));
  });

  test('descriptions are bounded static explanations without user details', () {
    for (final area in VisionDiagnosticCoverage.areas) {
      expect(area.name, isNotEmpty);
      expect(area.observes, isNotEmpty);
      expect(area.doesNotVerify, isNotEmpty);
      expect(area.observes.length, lessThan(150));
      expect(area.doesNotVerify.length, lessThan(150));
      final combined = '${area.observes} ${area.doesNotVerify}';
      expect(combined, isNot(contains('@')));
      expect(combined, isNot(contains('token=')));
    }
  });
}
