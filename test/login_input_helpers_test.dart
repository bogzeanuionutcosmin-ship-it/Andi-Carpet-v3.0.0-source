import 'package:andi_carpeta/auth/login_input_helpers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known auth codes keep Romanian messages regardless of SDK message', () {
    const messages = {
      'invalid-credential': 'Emailul sau parola nu sunt corecte.',
      'user-not-found': 'Nu există un cont cu acest email.',
      'wrong-password': 'Parola nu este corectă.',
      'email-already-in-use': 'Există deja un cont cu acest email.',
      'weak-password': 'Parola este prea slabă. Folosește minimum 6 caractere.',
      'invalid-email': 'Adresa de email nu este validă.',
      'too-many-requests': 'Prea multe încercări. Încearcă din nou puțin mai târziu.',
    };
    for (final entry in messages.entries) {
      expect(friendlyLoginError(FirebaseAuthException(
          code: entry.key, message: 'synthetic SDK message')), entry.value);
    }
  });

  test('unknown auth errors preserve SDK fallback, including empty messages', () {
    expect(friendlyLoginError(FirebaseAuthException(code: 'network-request-failed',
        message: 'synthetic offline')), 'synthetic offline');
    expect(friendlyLoginError(FirebaseAuthException(code: 'unknown')),
        'A apărut o eroare de autentificare.');
    expect(friendlyLoginError(FirebaseAuthException(code: 'unknown', message: '')), '');
    final error = StateError('synthetic storage error');
    expect(friendlyLoginError(error), error.toString());
  });

  test('phone normalization only retains ASCII digits without changing prefixes', () {
    expect(normalizeLoginPhone('+40 (712) 345-678'), '40712345678');
    expect(normalizeLoginPhone('0040 0712/345.678'), '00400712345678');
    expect(normalizeLoginPhone('123 extension 45'), '12345');
    expect(normalizeLoginPhone(' ٠١٢ no digits '), '');
    expect(normalizeLoginPhone(''), '');
  });
}
