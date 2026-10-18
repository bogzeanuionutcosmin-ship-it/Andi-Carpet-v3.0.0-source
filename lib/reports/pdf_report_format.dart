import 'package:pdf/widgets.dart' as pw;

/// Platform adapter for OpenSans or another application-provided PDF font set.
abstract interface class PdfFontProvider {
  Future<pw.Font> regular();
  Future<pw.Font> bold();
  Future<pw.Font> italic();
}

Future<pw.ThemeData> buildPdfTheme(PdfFontProvider fonts) async {
  final regular = await fonts.regular();
  final bold = await fonts.bold();
  final italic = await fonts.italic();
  return pw.ThemeData.withFont(base: regular, bold: bold, italic: italic);
}

String safePdfFilePart(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String formatPdfDate(DateTime d, String Function(int) two) =>
    '${two(d.day)}.${two(d.month)}.${d.year}';
