# Vision — corpul grafic static, fără animație / fără integrare în producție

**Data:** 15 octombrie 2026 · **Autor:** Shiva · **Tip:** lot independent, PR Draft, bazat pe [PR #52](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/52) HEAD `950f736a4e2e32799db5c61ccd8388fe1acae70e`.

## Decizia și scopul

Proprietarul dorește un asistent vizibil, în stilul unei mici mascote, cu corp înainte de animarea mișcărilor. Această etapă livrează **numai corpul vizual static**, testabil separat de conturile și fluxurile reale. Nu pretinde că AI-ul rulează autonom în aplicație și nu pornește Vision în fundal.

## Implementat

- `lib/vision/vision_assistant_avatar.dart` — componenta `VisionAssistantAvatar`, pictată vectorial prin `CustomPainter` fără asset imagini, fonturi extra, pluginuri ori dependențe plătite. Are cap, față, două ochiuri, zâmbet, antenă, brațe și picioare; scalare prin dimensiune logică, culorile temei și eticheta pentru cititorul de ecran `Vision, asistent grafic`.
- `test/vision_assistant_avatar_test.dart` — 4 teste Flutter: semantică/accesibilitate și lipsă gesturi din subarbore, 36/48/96/180dp fără overflow, teme light/dark, absență timere/UI diagnoză/animații în proba de 8 secunde.
- `test/vision_avatar_source_contract_test.py` — 4 verificări Python: dependență exclusiv Flutter material, fără import/call Firebase/auth/network/clipboard/diagnostic, fără gesturi/timere/overlay/navigare, etichetă semantică și painter existent.
- Workflow Android compile-only existent este activat pentru această ramură; `flutter build apk --debug --target lib/main.dart`, fără distribuție/upload.

## Constrângeri și siguranță

- **Zero integrare** în `main.dart`, `VisionDiagnosticsPage`, Home sau Navigator. Nu schimbă ecranele utilizatorilor autentificați și nu deschide jurnalul device-wide care trebuie să rămână fail-closed până la izolare explicită per sesiune.
- Nu există acces la log, UID, conversații, GPS/FCM, OCR, date financiare sau costuri Firestore. Fără interacțiuni, animații, sunete, notificări, solicitări către rețea ori upload.
- Nu schimbă reguli funcționale, importuri din fișiere înghețate, hashuri protejate, Firestore rules, finanțe, versiune/dependențe, manifest Android ori asseturi. Nu închide Issue #32/#53 și nu interferă cu [Misiunea VIII Luna, Issue #54](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/issues/54).
- Redesenarea la schimbarea temei este suportată; nu există încă expresii animate, gesturi, corp care se mișcă, proces AI sau panou public.
- Condiție de acceptare: **standard CI 5/5**, teste Flutter + Python, Identity și Android compile-only pe **ultimul SHA**. Fără presupunerea că buildul APK ar valida animațiile/UX pe hardware.

## Pași ulteriori (nu incluși automat)

1. Review vizual al corpului pe telefon și web, inclusiv dimensiuni și accesibilitate; ajustări numai după feedback.
2. Stabilirea poziției/rutei mascotă în aplicație, a drepturilor, UX și diferenței dintre avatar și jurnalul privat. Nu se adaugă buton public de diagnostic până când ACL și izolarea UID/epoch sunt demonstrate.
3. Stări și animații reduse la minimum, respectând accesibilitatea/reduced motion și fără bucle permanente care consumă bateria; separat, cu teste și decizie.

**Checkpoint:** rezultatele CI, HEAD final și statusul Android se consemnează în PR Draft după rulare. Nu se autorizează merge/deploy/APK publicat sau Firebase în producție.
