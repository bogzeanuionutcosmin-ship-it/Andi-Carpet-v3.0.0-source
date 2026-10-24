import 'package:firebase_core/firebase_core.dart';

/// Returns the existing user-facing explanation for a failed schedule save.
///
/// Kept independent of the application library so schedule error mapping can
/// be tested and reused without importing the full `main.dart` part library.
String scheduleSaveFailureMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore a respins salvarea. Verifică apartenența activă la echipă și dreptul editProgram; regulile de securitate nu au fost ocolite.';
      case 'unauthenticated':
        return 'Sesiunea a expirat. Autentifică-te din nou și reîncearcă salvarea.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Firestore nu este disponibil momentan. Modificarea nu este confirmată; verifică graficul după reconectare înainte să încerci din nou.';
      case 'failed-precondition':
        return 'Graficul s-a schimbat sau nu mai poate fi modificat în starea curentă. Reîncarcă-l și verifică dacă este închis.';
      default:
        return 'Firestore nu a confirmat salvarea (${error.code}). Reîncarcă graficul înainte de o nouă încercare.';
    }
  }
  if (error is StateError) return error.message;
  return 'Eroare la salvarea graficului: $error';
}
