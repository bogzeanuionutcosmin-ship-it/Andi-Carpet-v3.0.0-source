# Securitate Admin — consolidare integrată

## Implementat în sursă
- Profilurile `users` sunt citibile doar de proprietar sau Admin; listarea este permisă doar Adminului.
- Directorul `memberDirectory` este citibil pentru utilizatori activi și nu poate fi modificat de clienți.
- Triggerul de sincronizare citește **starea curentă** a profilului într-o tranzacție, nu starea posibil depășită a evenimentului; elimină documentul pentru Admin, profil ascuns sau utilizator șters.
- Migrarea existentă este explicită (`--apply`), în mod implicit doar simulare; șterge intrările învechite.
- Teste de contract suplimentare pentru reguli, interogarea profilurilor, trigger și migrare.

## Limitări / lansare
- Testele de contract verifică sursa, **nu** execută reguli Firestore sau aplicația Flutter.
- Nu s-au rulat Firebase Emulator, `flutter analyze`, `flutter test` sau build APK: utilitarele nu sunt instalate în acest mediu.
- Migrarea trebuie testată întâi în Emulator, apoi executată controlat înainte de activarea regulilor restrictive. În timpul migrării de producție, evitați modificarea simultană a profilurilor pentru a preveni rescrieri pe baza unui snapshot vechi.
- Aplicațiile deja instalate pot avea interogări incompatibile cu regulile noi; este necesară o publicare coordonată.
- Nu publicați doar regulile Firestore separat.

**Concluzie:** implementare consolidată în sursă, validare de producție încă nefinalizată.
