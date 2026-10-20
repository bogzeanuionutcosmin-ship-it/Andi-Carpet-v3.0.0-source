import 'dart:convert';

/// Returns the existing stable Firestore document ID for a push token.
///
/// The value is the unpadded Base64 URL encoding of the token's UTF-8 bytes.
String pushTokenDocumentId(String token) =>
    base64UrlEncode(utf8.encode(token)).replaceAll('=', '');
