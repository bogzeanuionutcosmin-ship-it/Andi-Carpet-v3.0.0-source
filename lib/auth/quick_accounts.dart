import 'dart:convert';

class QuickAccount {
  final String email;
  final String password;
  const QuickAccount({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
  static QuickAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final email = (raw['email'] ?? '').toString().trim();
    final password = (raw['password'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) return null;
    return QuickAccount(email: email, password: password);
  }
}

class QuickAccountStore {
  final Future<String?> Function() read;
  final Future<void> Function(String value) write;
  final Future<void> Function() delete;

  const QuickAccountStore({
    required this.read,
    required this.write,
    required this.delete,
  });

Future<List<QuickAccount>> load() async {
  final raw = await read();
  if (raw == null || raw.trim().isEmpty) return <QuickAccount>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <QuickAccount>[];
    return decoded.map(QuickAccount.fromJson).whereType<QuickAccount>().toList();
  } catch (_) {
    return <QuickAccount>[];
  }
}

Future<void> save(List<QuickAccount> accounts) async {
  final normalized = <String, QuickAccount>{};
  for (final account in accounts) {
    normalized[account.email.trim().toLowerCase()] = account;
  }
  final values = normalized.values.take(2).map((e) => e.toJson()).toList();
  if (values.isEmpty) {
    await delete();
  } else {
    await write(jsonEncode(values));
  }
}

}
