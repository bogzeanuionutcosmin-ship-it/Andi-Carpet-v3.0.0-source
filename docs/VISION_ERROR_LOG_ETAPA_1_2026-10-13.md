# Vision / Error Log — etapa 1, colector local

**Data:** 2026-10-13  
**Ramură:** `feat/vision-error-log-core-20261013`  
**Stadiu:** PR de implementare etapizată; **nu este versiune publicată**.  
**Reguli consultate:** `ChatGpt` §154–156, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` §71–75 și `ARHITECTURA_VISION_ULTRON_JARVIS_ZERO_COST.md` §12.

## Funcționalitate implementată în acest lot

- `lib/vision/vision_error_log.dart`: colector pur Dart, independent de cloud, care păstrează **doar coduri de categorie/eroare și platformă**. Refuză mesaje brute, stack-uri, coordonate, tokenuri ori texte OCR. Identificatorii trec prin listă albă de caractere și lungime. Gruparea pe fingerprint mărește un contor în loc să copieze de 10.000 ori aceeași eroare.
- Metadate de tip `severity`, `firstSeen`, `lastSeen`, `count` și `resolved`, cu read-only snapshot. Întâmplările noi redeschid un incident rezolvat. Rezumatele expiră după **7 zile**; la fiecare scriere/citire/restaurare se curăță local înregistrările expirate; la volum se elimină mai întâi înregistrările rezolvate.
- Motorul acceptă limite până la 500 elemente / 1 MiB, configurabile; **instanța conectată la aplicație are inițial o limită mai conservatoare de 150 rezumate / 48 KiB / 7 zile**, întrucât folosește stocare securizată existentă și nu trebuie transformată în bază de loguri grea. Cota este **o limită superioară, nu o rezervare de memorie**.
- `lib/vision/vision_error_telemetry.dart`: citire/salvare rezumate în `flutter_secure_storage` deja inclus în proiect, cu scrieri serializate/coalescente la 3 secunde și încercare imediată pentru incidente critice. Dacă stocarea platformei lipsește/eșuează, aplicația pornește și rămâne funcțională, iar logurile rămân doar în memoria sesiunii.
- `lib/main.dart` instalează interceptoare pentru `FlutterError.onError` și `PlatformDispatcher.instance.onError`, **păstrând comportamentul handlerelor anterioare**. Captăm și tipul erorii inițializării Firebase. Nu ascundem crashurile și nu trimitem nimic la Firebase.
- `test/vision_error_log_test.dart`: teste logice pentru deduplicare masivă, severitate/rezolvare/redeschidere, limitare elemente/bytes, expirare, cache invalid/vechi și neacceptarea datelor sensibile.

## Limite cunoscute / ce NU trebuie afirmat că există deja

1. **Nu există încă panou Vision/Error Log** accesibil membrilor autorizați. Captura este pregătită ca bază tehnică, dar pentru inspecție operativă trebuie creată interfața cu control de acces corect.
2. **Nu se raportează toate erorile operaționale:** GPS, OCR, diurne, Mapbox, FCM și Functions vor necesita adaptoare explicit apelate din fluxurile relevante. Erorile prinse și ignorate de codul existent nu sunt automat observabile de interceptorii generali.
3. **Nu există upload/server/alertare automată**, nici funcții Cloud, TTL server, Crashlytics, API AI plătit, acces ChatGPT permanent ori stocare de loguri în Firebase. Pentru utilizare pe mai multe dispozitive va trebui stabilită o politică separată de minimizare și autorizare.
4. O terminare bruscă a procesului sau o restricție a sistemului de operare poate împiedica persistarea ultimelor evenimente. Nu garantăm observabilitate 24/7 când aplicația nu rulează.
5. Limitele de 150/48 KiB protejează inițial `flutter_secure_storage`; pentru volumul țintă 500/1 MiB, vom introduce ulterior un cache de fișiere/IndexedDB adaptat platformei, doar dacă testele de consum justifică.
6. În această etapă, **expirarea este leneșă** (pornire/citire/scriere), nu execută un job periodic care ar consuma Firebase sau baterie inutil. Nu modifică documente financiare, istoricul lucrărilor, operațiunile de business sau auditul lor.
7. Erorile sunt anonimizate la nivel de tip și categorie pentru confidențialitate. Următorul lot trebuie să adauge coduri de eveniment explicabile, emise explicit în punctele operaționale, **fără a pune `exception.toString()` în log**.

## Verificări / condiții de acceptare

- GitHub CI: Flutter web build, teste Flutter/Dart, Python, Node și emulator Firestore, după crearea PR. **Nu se pretinde SUCCESS înainte de verificarea run-ului exact.**
- La validare: unit tests noi, cold start după eroare Firebase, Firefox/Chrome/Android secure storage, comportamentul la error callback recursiv, offline, stres, limite/7 zile.
- Apoi: panou read-only pentru utilizatorul propriu și consolă administrativă doar cu autorizare validată, integrare adaptori GPS/OCR și teste instrumentate.
- **Fără deploy, merge, APK, schimbări Firebase Rules, date reale ori activare facturare** prin prezentul PR.
