import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/reports/pdf_filename_normalization.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  test('preserves legacy PDF filename normalization', () {
    const cases = <String, String>{
      'Raport 2026.pdf': 'raport_2026_pdf',
      '  RAPORT--Final  ': 'raport_final',
      'A__B...C': 'a_b_c',
      'invoice-123': 'invoice_123',
      'abc': 'abc',
      '': '',
      '---': '',
      ' Șantier București ': 'antier_bucure_ti',
      '日本語': '',
      'a/b\\c': 'a_b_c',
    };
    for (final entry in cases.entries) {
      expect(safePdfFilePart(entry.key), entry.value, reason: entry.key);
      expect(app.safePdfFilePart(entry.key), entry.value, reason: 'main.dart: ${entry.key}');
    }
  });

  test('does not trim ASCII letters or digits', () {
    expect(safePdfFilePart('a0Z9'), 'a0z9');
    expect(safePdfFilePart('___A___'), 'a');
    expect(safePdfFilePart('a---b'), 'a_b');
  });
}
