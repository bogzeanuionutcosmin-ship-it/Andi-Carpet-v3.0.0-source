part of '../main.dart';

const FlutterSecureStorage _quickAccountStorage = FlutterSecureStorage();
const String _quickAccountsStorageKey = 'andi_carpeta_quick_accounts_v1';

class _QuickAccount {
  final String email;
  final String password;
  const _QuickAccount({required this.email, required this.password});
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
  static _QuickAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final email = (raw['email'] ?? '').toString().trim();
    final password = (raw['password'] ?? '').toString();
    if (email.isEmpty || password.isEmpty) return null;
    return _QuickAccount(email: email, password: password);
  }
}

Future<List<_QuickAccount>> _loadQuickAccounts() async {
  final raw = await _quickAccountStorage.read(key: _quickAccountsStorageKey);
  if (raw == null || raw.trim().isEmpty) return <_QuickAccount>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <_QuickAccount>[];
    return decoded.map(_QuickAccount.fromJson).whereType<_QuickAccount>().toList();
  } catch (_) {
    return <_QuickAccount>[];
  }
}

Future<void> _saveQuickAccounts(List<_QuickAccount> accounts) async {
  final normalized = <String, _QuickAccount>{};
  for (final account in accounts) {
    normalized[account.email.trim().toLowerCase()] = account;
  }
  final values = normalized.values.take(2).map((e) => e.toJson()).toList();
  if (values.isEmpty) {
    await _quickAccountStorage.delete(key: _quickAccountsStorageKey);
  } else {
    await _quickAccountStorage.write(key: _quickAccountsStorageKey, value: jsonEncode(values));
  }
}

