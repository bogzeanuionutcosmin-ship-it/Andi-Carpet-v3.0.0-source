# Vision — test autentic AuthGate → lease izolat → pagină de diagnostic

**16 octombrie 2026 · Shiva · ramură Draft izolată de PR #55 Luna**

## Bază și necesitate

PR #68, HEAD `617a1e8a013b4b5b20bc1e87c3e2d15c488efc59`, a livrat coordonatorul pur Dart `VisionSessionLifecycleCoordinator` (480 Flutter / 215 Python, CI standard 5/5, Identity și Android SUCCESS). Până acum, verificările A→B→A2 probau în principal callbackuri injectate manual, nu ciclul complet al unui AuthGate și al Navigatorului autentic.

Sursa existentă `lib/auth/auth_gate.dart` are deja closure-ul `sessionIsCurrent` ce verifică `mounted`, `_sessionGeneration`, UID-ul profilului și SDK `currentUser.uid`. `AndiCarpetaApp` oferă un `homeBuilder` injectabil pentru fixture-uri autentice. Acest lot **utilizează punctul existent fără modificarea lui `main.dart`, `auth_gate.dart` sau `home_page.dart`**, toate cu sensibilitate la integrarea financiară a Lunei.

## Nou în cod

- `lib/vision/vision_auth_session_host.dart`: `VisionAuthSessionHost`, wrapper Flutter opțional care primește closure-ul exact al AuthGate, deține un coordinator în State, validează proprietarul înainte de a invoca builderul privat, păstrează lease-ul la refresh profil pe aceeași epocă și revocă automat la dispose/root-switch. La schimbarea generației, lease-ul vechi devine fals, fiind înlocuit numai după autorizarea noului callback; dacă predicate-ul aruncă, arată doar UI indisponibil.
- `test/vision_authgate_session_host_integration_test.dart`: trei teste widget pe `AndiCarpetaApp` și `SessionAuth / SessionFirestore` fixture existente; un arbore complet AuthGate real simulat verifică A1→B→A2, ecran și Navigator distruse, copie de jurnal nepartajată, logout/relogin același UID, refresh profil fără resetare de jurnal și owner fals/throwing.
- `test/vision_authgate_session_host_contract_test.py`: cinci contracte pentru lipsa backendului/rețelei, importuri permise, callbackul autoritativ existent, revocare, utilizarea fixtureului AuthGate real.
- Workflow Android compile-only existent activat exclusiv pentru acest branch, fără deploy, semnare de release sau instalare.

## Limite, în mod intenționat

**Acest wrapper NU este montat în Home/AndiCarpetaApp pentru utilizatorii actuali.** Folosește mecanismul deja disponibil de injectare doar în test. Nu expune jurnalul persistent `VisionErrorTelemetry.log`, nu citește date din conturi, nu păstrează UID pe disc și nu automatizează GPS/FCM/OCR din lease-ul activ. Integrarea finală pentru utilizatorii reali necesită loc vizibil în Home și ownership real, cu verificare a aspectului/permisiunilor pe Android fizic, web și posibil Windows/iOS. Prevenirea unui cadru vechi în UI este dependentă de AuthGate/Root Navigator; se menține gardul de clipboard și revocare din PR-urile anterioare.

Fișierele Lunei din PR #55, `lib/main.dart`, `AuthGate`, Home, Admin Restore, `firestore.rules`, Firebase live, manifestul 116 SHA și controalele Vision imutabile rămân neatinse. Fără Firestore reads/writes suplimentare; Spark/free-friendly. Fără merge, deploy, billing, APK publicat sau configurare producție.

## Gates

Standard 5/5 (Python, Flutter, Functions, Node, emulator și build web), Identity, Android compile-only, integritatea manifestului 116 SHA. Primele red tests trebuie investigate și corectate fără ștergerea protecțiilor; rezultatul final se raportează numai pe HEAD verificat. Actualizarea `ChatGpt` conține checkpointul.
