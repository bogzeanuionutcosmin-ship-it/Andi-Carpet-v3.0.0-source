import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Resolves aliases with the existing endpoint and timeout. No session state.
class LoginAliasResolver {
  final Future<http.Response> Function(
    Uri uri, {Map<String, String>? headers, Object? body}
  ) post;

  const LoginAliasResolver({required this.post});

  Future<String> resolve(String identifier, String pass) async {
    if (identifier.contains('@')) return identifier.trim();
    final uri = Uri.parse('https://europe-central2-andicarpet-e777e.cloudfunctions.net/resolveLoginAlias');
    final response = await post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier.trim(), 'password': pass}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'Date de autentificare incorecte.');
    }
    final data = jsonDecode(response.body);
    final resolved = data is Map ? (data['email'] ?? '').toString().trim() : '';
    if (resolved.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential', message: 'Date de autentificare incorecte.');
    }
    return resolved;
  }

}
