# Andi Carpet v3.0.1 — consolidare 01

## Modificare realizată
- `lib/main.dart`: eliminat switch-ul din profilul Admin care permitea dezactivarea ascunderii contului.

## Probleme rămase (nu sunt reparate)
- `firestore.rules`: `users` permite citirea tuturor profilurilor de către orice utilizator activ, inclusiv profilurile Admin ascunse.
- Interogările nefiltrate `collection('users')` trebuie migrate înainte de restricționarea regulilor, altfel vor eșua.
- Monitorizarea Mapbox este locală, nu centralizată.
- Tranzacțiile `per_diem_settlements_v2` sunt blocate intenționat până la validare.

## Verificări
- `python -m unittest discover -s test -p '*test.py' -q`: 11 teste trecute.
- Nu au fost rulate Flutter, Firebase Emulator sau teste pe dispozitiv.
- Nu s-a făcut deploy GitHub/Firebase/APK.

## Următorul pas tehnic
- Migrarea citirilor `users` către o colecție publică minimală, fără date private și fără contul Admin; reguli Firestore + teste emulator; migrarea datelor existente.
