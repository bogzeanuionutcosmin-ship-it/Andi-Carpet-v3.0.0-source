part of '../main.dart';

Future<pw.ThemeData> _buildPdfTheme() async {
  final regular = await PdfGoogleFonts.openSansRegular();
  final bold = await PdfGoogleFonts.openSansBold();
  final italic = await PdfGoogleFonts.openSansItalic();
  return pw.ThemeData.withFont(base: regular, bold: bold, italic: italic);
}

String _safeFilePart(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _pdfDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';


