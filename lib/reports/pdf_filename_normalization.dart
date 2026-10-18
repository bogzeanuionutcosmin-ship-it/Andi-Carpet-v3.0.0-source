/// Legacy ASCII-only file-name segment normalization for PDF exports.
///
/// Intentionally retains lowercasing, underscore collapsing, and the
/// existing behavior for accented and non-Latin characters.
String safePdfFilePart(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');
