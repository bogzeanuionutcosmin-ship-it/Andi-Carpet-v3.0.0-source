# Andi Carpet v3.0.1 — Consolidare securitate 06

## Modificări
- O singură funcție `projectMember` în `functions/member_directory_projection.js`, folosită atât de triggerul `syncMemberDirectory`, cât și de migrarea `scripts/backfill_member_directory.js`.
- Eliminată duplicarea listei de câmpuri publice, reducând riscul ca migrarea să expună câmpuri private.
- Adăugate trei teste Node care execută proiecția reală, inclusiv ascunderea contului Admin și excluderea câmpurilor private.
- Adaptate testele Python de contract la noul modul comun.

## Validare executată
- `python -m unittest discover -s test -p '*test.py' -q`: 25/25 OK.
- `node --test test/member_directory_projection.test.js`: 3/3 OK.
- `node --check functions/index.js` și `node --check scripts/backfill_member_directory.js`: OK.
- ZIP validat după creare.

## Nevalidate / fără deploy
- Flutter SDK nu este disponibil în mediul curent: nu s-a compilat APK-ul.
- Firebase Emulator nu este disponibil: regulile Firestore și fluxul de migrare nu au fost testate end-to-end.
- Nicio migrare executată; nicio modificare în GitHub sau Firebase.

## Ordine recomandată pentru lansare
1. Teste Flutter și Firebase Emulator cu rolurile admin/membru/inactiv.
2. Deploy trigger Cloud Functions și verificarea sincronizării.
3. Dry-run migrare; apoi migrare controlată cu backup și verificarea directorului.
4. Publicarea clientului compatibil și coordonarea regulilor restrictive Firestore.
