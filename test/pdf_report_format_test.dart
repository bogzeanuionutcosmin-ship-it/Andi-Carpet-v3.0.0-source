import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:andi_carpeta/reports/pdf_report_format.dart';

class _RecordingFonts implements PdfFontProvider {
  final calls = <String>[];
  @override
  Future<pw.Font> regular() async { calls.add('regular'); return pw.Font.helvetica(); }
  @override
  Future<pw.Font> bold() async { calls.add('bold'); return pw.Font.helveticaBold(); }
  @override
  Future<pw.Font> italic() async { calls.add('italic'); return pw.Font.helveticaOblique(); }
}

class _FailingFonts implements PdfFontProvider {
  final calls = <String>[];
  @override
  Future<pw.Font> regular() async { calls.add('regular'); return pw.Font.helvetica(); }
  @override
  Future<pw.Font> bold() async { calls.add('bold'); throw StateError('font failed'); }
  @override
  Future<pw.Font> italic() async { calls.add('italic'); return pw.Font.helveticaOblique(); }
}

void main() {
  test('PDF theme requests fonts sequentially and in the legacy order', () async {
    final fonts = _RecordingFonts();
    final theme = await buildPdfTheme(fonts);
    expect(fonts.calls, ['regular', 'bold', 'italic']);
    expect(theme, isA<pw.ThemeData>());
    final document = pw.Document(theme: theme)..addPage(pw.Page(build: (_) => pw.Text('test')));
    expect((await document.save()).take(4).toList(), [37, 80, 68, 70]);
  });

  test('font loading errors propagate and later fonts are not requested', () async {
    final fonts = _FailingFonts();
    await expectLater(buildPdfTheme(fonts), throwsStateError);
    expect(fonts.calls, ['regular', 'bold']);
  });

  test('filename cleanup preserves the old lowercase ASCII contract', () {
    for (final entry in {
      ' Grafic 01/2026 ': 'grafic_01_2026',
      'Șantier & TEST.pdf': 'antier_test_pdf',
      'a---b': 'a_b',
      '___': '',
      'MiXeD_1': 'mixed_1',
    }.entries) {
      expect(safePdfFilePart(entry.key), entry.value);
    }
  });

  test('date formatting keeps the legacy day.month.year output', () {
    String two(int value) => value.toString().padLeft(2, '0');
    final date = DateTime(2026, 10, 5);
    expect(formatPdfDate(date, two), '05.10.2026');
  });
}
