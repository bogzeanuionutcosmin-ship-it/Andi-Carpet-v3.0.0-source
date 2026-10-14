@JS()
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('andiCarpetaOcr')
external JSPromise<JSString> _andiCarpetaOcr(JSString dataUrl);

Future<String> recognizeTextFromImage(Uint8List bytes, {String? path}) async {
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  final result = await _andiCarpetaOcr(dataUrl.toJS).toDart;
  return result.toDart;
}
