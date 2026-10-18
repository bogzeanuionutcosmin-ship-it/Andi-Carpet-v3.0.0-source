# Vision — punte AuthGate cu rotația sigură a epocii (Draft, 16.10.2026)

**Bază:** PR #70, HEAD `5f432ae2f9bb40c6b2914185d032765833e9eadb`. Misiunea VIII a Lunei rămâne izolată în PR #55, HEAD verificat `a95062a0f57d040cff9bd53bcced2c75c9592316`.

## Problema și schimbarea efectivă

`VisionAuthenticatedSessionScope` (PR #70) cere un obiect unic la fiecare generație de autentificare. AuthGate expune deja `activeSessionPageBuilder` cu callback ce verifică UID + generație, dar nu expune tokenul distinct. A folosi UID drept token ar expune riscul de a reutiliza istoricul la A1→A2; a folosi identitatea obiectului callback ar șterge jurnalul la simple refreshuri de profil.

`lib/vision/vision_authgate_epoch_bridge.dart` este un adaptor **opțional**, montabil sub `activeSessionPageBuilder`, care reține predicatul primei generații și emite `Object()` nou ca token **numai** dacă predicatul inițial a devenit invalid și un callback diferit, valid, dovedește o generație nouă. Un owner fals/aruncat închide monotonic vizualizarea. Callback fals→adevărat în aceeași epocă, un callback nou cu aceeași generație sau un simplu rebuild nu reactivează jurnalul. Adaptorul folosește exclusiv `VisionAuthenticatedSessionScope` existent; nu deschide jurnalul singleton persistent.

Această strategie depinde explicit de contractul existent al AuthGate: callbackul capturează `_sessionGeneration`, UID-ul profilului și `_currentUser`; după o schimbare reală a generației, callbackul vechi trebuie să rămână invalid. Nu se schimbă `lib/auth/auth_gate.dart`, `main.dart`, Navigator, Home sau fișierele protejate.

## Teste și limite

`test/vision_authgate_epoch_bridge_test.dart` acoperă:
1. refresh profil cu callback nou, aceeași generație, jurnal păstrat;
2. același UID cu generație nouă: lease anterior revocat, niciun late write;
3. false→true și callback nou fără generație nouă: niciun resurrection;
4. callback vechi care aruncă urmat de generație nouă;
5. `AndiCarpetaApp/AuthGate` reale din fixture-urile existente, cu auth/Firestore sintetice, A→B→A2, ecran și rută privată abandonate.

Adăugarea este opt-in în ramura Draft; **nu** este instalată în Home implicit, nu colectează erori reale și nu certifică comportamentul la restart/dispozitiv fizic, login mai rapid decât toate frame-urile, background OS sau combinația financiară a Lunei. Snapshoturile fixture-ului nu sunt date din Firebase producție. Pentru release rămâne obligatorie compoziția reală a Navigatorului și testarea hardware/iOS/Windows/web. `VisionErrorTelemetry.log` rămâne închis pentru istoricul de instalare.

**Cost incremental:** zero Firestore reads/writes, HTTP, polling, storage, Cloud Functions, AI API sau billing nou în acest lot. Fără schimbarea regulilor, datelor sau planului Firebase, fără merge/deploy/publicare APK. CI trebuie confirmat pe **HEAD-ul exact**: standard 5/5, Identity și Android debug compile-only; un workflow SKIPPED nu reprezintă PASS.

Issue #63 rămâne deschis; `production_ready=false`.
