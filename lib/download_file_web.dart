import 'dart:html' as html;
import 'dart:typed_data';

/// Browserul gestionează descărcarea în managerul propriu de fișiere.
Future<bool> downloadFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    try {
      anchor.click();
    } finally {
      anchor.remove();
    }
    return true; // Browserul poate totuși interveni la descărcare.
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
