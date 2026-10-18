part of '../main.dart';

Future<pw.ThemeData> _buildPdfTheme() async {
  // Reports must render offline and must not transmit export activity to a font CDN.
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final italic = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Oblique.ttf'));
  return pw.ThemeData.withFont(base: regular, bold: bold, italic: italic);
}

String _safeFilePart(String text) => safePdfFilePart(text);

String _pdfDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';


