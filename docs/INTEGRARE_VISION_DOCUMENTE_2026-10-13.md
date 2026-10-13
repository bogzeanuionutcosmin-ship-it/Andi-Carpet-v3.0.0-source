# Verificare independentă — combinație Vision + Documente (2026-10-13)

**Stadiu: PR de integrare de test, NU release.** Nicio schimbare în `main`, Firebase de producție, reguli de securitate, billing ori APK instalat.

## Origine verificată

- PR #19 / `d4da2872a566eba258e82b8597c023e03ceb9b56`: Vision Error Log offline, integrarea erorilor OCR/GPS/FCM/diurne, OCR sumă fără ghicire; CI 5/5 și compilare debug Android separate verzi.
- PR #20 / `7823a54b95aa26de382209847e61ad0fe65a910f`: salvare nativă a PDF-urilor cu selector, partajare separată, PV Magic și Million, PDF original de 1.399.921 octeți, test de integritate în APK/web; CI 5/5 și compilare debug Android separate verzi.
- Ambele ramuri pornesc din `main` la `377f1fd5`. Ambele sunt Draft. Fișiere suprapuse: `lib/main.dart`, `ChatGpt`, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, `ARHITECTURA_VISION_ULTRON_JARVIS_ZERO_COST.md`.
- În ramura aceasta codul `main.dart` unește importurile și handler-ele fără înlocuirea comportamentului existent, iar documentația include integral secțiunile ambelor PR-uri. Secțiunile PR #20 sunt renumerotate, fără ștergerea conținutului.

## Criterii de acceptare

1. Flutter unit/widget tests (`flutter test test/`) incluzând OCR, Vision, clasificare PV și integritatea fișierului Million.
2. Python contracte + inventar securitate, Node, Firebase Functions, emulator Firestore fără date producție.
3. Build **web** incluzând byte-for-byte PDF original Million și build **Android debug** cu același PDF.
4. Teste reale Android separat: selector salvare PDF (nu share), buton Magic/Million, jurnal după repornire, OCR pe documente anonimizate; validarea doar în CI nu dovedește comportamentul UI pe telefon.
5. Verificarea documentației, regresii și a comparației `main` înainte de integrare. Fără niciun merge, deploy, release sau APK fără acord separat.

**Notă educațională:** faptul că PR #19 și PR #20 sunt separat verzi nu este dovada compatibilității. De aceea această ramură compune explicit conținutul și verifică întregul proiect.
