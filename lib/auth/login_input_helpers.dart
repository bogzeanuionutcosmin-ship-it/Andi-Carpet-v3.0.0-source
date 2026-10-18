import 'package:firebase_auth/firebase_auth.dart';

String friendlyLoginError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-credential' => 'Emailul sau parola nu sunt corecte.',
        'user-not-found' => 'Nu există un cont cu acest email.',
        'wrong-password' => 'Parola nu este corectă.',
        'email-already-in-use' => 'Există deja un cont cu acest email.',
        'weak-password' => 'Parola este prea slabă. Folosește minimum 6 caractere.',
        'invalid-email' => 'Adresa de email nu este validă.',
        'too-many-requests' => 'Prea multe încercări. Încearcă din nou puțin mai târziu.',
        _ => e.message ?? 'A apărut o eroare de autentificare.',
      };
    }
    return e.toString();
  }

String normalizeLoginPhone(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
