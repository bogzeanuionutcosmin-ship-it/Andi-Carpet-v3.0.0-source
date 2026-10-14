# Andi Carpet v3.0.1 — Consolidare securitate 02

Bază: arhiva cumulativă SECURITATE-ADMIN-INTEGRAT.

## Corecție
Directorul `memberDirectory` nu mai proiectează `profileFields` și `hireDate` din profilurile private. Sunt păstrate datele necesare pentru afișarea și contactarea membrilor, inclusiv nume, telefon, fotografie și echipă. Conturile Admin și cele marcate ascunse rămân excluse.

## Verificări executate
- 19 teste Python de contract/sursă (5 + 4 + 7 + 3) trecute.
- `node --check functions/index.js` trecut.
- Nu s-a executat compilarea Flutter, Firebase Emulator sau migrarea reală.

## Limitări și lansare
- Aceste teste verifică prezența unor contracte în cod, nu autorizarea efectivă Firebase sau compatibilitatea tuturor ecranelor.
- Proiecțiile deja existente în Firestore vor fi actualizate de trigger la următoarea modificare a fiecărui profil; pentru curățarea imediată a documentelor existente este necesară o resynchronizare/backfill controlată. Scriptul existent de backfill trebuie verificat înainte de utilizare în producție.
- Nu publicați reguli Firestore separat de aplicația actualizată și Cloud Functions.
- GitHub, Firebase și APK nu au fost modificate.
