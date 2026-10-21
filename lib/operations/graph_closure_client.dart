import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

typedef GraphClosurePost = Future<http.Response> Function(Uri uri,
    {Map<String, String>? headers, Object? body});

/// Retries the exact same operation after transport/ACK uncertainty. A rejected
/// server precondition is never retried or replaced with a local schedule save.
Future<String> requestGraphClosure({
  required Uri endpoint,
  required Future<String?> Function() getIdToken,
  required GraphClosurePost post,
  required Map<String, dynamic> operation,
  Duration timeout = const Duration(seconds: 25),
}) async {
  final body = jsonEncode(operation);
  final token = await getIdToken();
  if (token == null || token.isEmpty) throw StateError('Autentifică-te înainte de STOP.');
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final response = await post(endpoint,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: body).timeout(timeout);
      if (response.statusCode >= 500) {
        if (attempt == 0) continue;
        throw StateError('STOP neconfirmat. Reconectează și reîncarcă graficul pentru verificare.');
      }
      Map<String, dynamic> data;
      try { data = jsonDecode(response.body) as Map<String, dynamic>; }
      catch (_) { throw StateError('Răspuns STOP invalid. Reîncarcă pentru verificare.'); }
      if (response.statusCode != 200 || data['closed'] != true ||
          data['receiptId'] is! String || (data['receiptId'] as String).isEmpty) {
        throw StateError(data['message'] is String ? data['message'] as String :
          'STOP respins de server. Reîncarcă graficul.');
      }
      return data['receiptId'] as String;
    } on TimeoutException {
      if (attempt == 1) rethrow;
    } on http.ClientException {
      if (attempt == 1) rethrow;
    }
  }
  throw StateError('STOP neconfirmat. Reîncarcă graficul.');
}
