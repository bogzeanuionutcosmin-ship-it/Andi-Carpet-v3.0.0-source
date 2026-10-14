# MISIUNEA IV — AuthGate modularizat: execuție

## Lot RED pregătit

Bază #35 `71369b6b0eebc7c73ddf2cb55455309b3f0e1ba8`, #28 `fd602ed4bd727e2c2b41cf24ac988a818a2564ff`; sursă #33 `a5f43ef9ce0bfedaf59766aafe18732fef7f8f47`. #34 a avansat extern (`6f57c4645cd80f7ceaef6457c7bbd6eae558d139` la preflight), #29 `545e0202755a8ee86a7b3406adccd469aac84f9e`; sursele nu sunt modificate.

12 acceptanțe și 8 controale portate din #33. Harness-ul folosește AuthGateSources #28 și State Home modularizat real; seam-uri opționale SDK FCM și startup, porturile query/sync/push/maintenance existente păstrate. ROOT primește sursele și builderul injectat; încă nu are reset de Navigator/Messenger. Builderul existent cu două argumente rămâne compatibil; un builder separat permite ownership. În acest lot ownership este doar mounted, fără remediere funcțională.

Matrice destinație: AuthGate/Sources → `lib/auth/auth_gate.dart`; ROOT → `lib/ui/app_root_theme.dart`; Home/ownership → `lib/home/home_page.dart`; FCM → `home_push_notifications.dart`; GPS → `home_live_location.dart`; deliveries/post-frame → `home_sync_listeners.dart`, `home_directory_definitions_audit_sync.dart`, `home_financial_sync.dart`; rute → `home_navigation.dart`.

Assertions #33 păstrate; două adaptări de wiring: Sources în mount și syncFirestore/pushFirestore în fixture Home. Caracterizările KNOWN DEFECT #28 rămân intacte în RED. Contractele Python actualizează numai literalii de fallback SDK/startup, păstrând ordinea și toate invariant-ele anterioare.

Local: 158 Python PASS; diff whitespace PASS. Flutter/Dart lipsesc local. Dovada RED de comportament trebuie citită din CI manual pe SHA exact înainte de fix. Nicio eroare de fixture/compilare nu va fi considerată dovadă P1.

Fără main/merge/deploy/APK/Firebase producție/finanțe/roluri/parser/backup ori editări #28/#33/#34/#29. Cele 59 parts rămân. Stadiu A01–A12/C01–C08: NEEXECUTAT până la CI; P1 încă deschis pe integrare.

## RED demonstrat și STOP infrastructură

Commit RED `3f2429976f6d14966b3c0b09570552d3f2a426d6`, dispatch standard [38589878102](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38589878102), `workflow_dispatch` pe SHA exact verificat în UI/log checkout. **279 Flutter PASS / 15 FAIL**, fără load/compile/timeout errors. Toate cele 274 teste din baza #28 trec; dintre cele 20 portate, 12 acceptanțe și 3 controale mixte cu verificări de izolare eșuează prin assertions comportamentale, 5 controale trec.

| ID | Rezultat RED | Dovadă efectivă |
|---|---|---|
| A01 | FAIL | Private Alice rămâne în pending B |
| A02 | FAIL | Profilul Alice rămâne după error B/global rebuild |
| A03 | FAIL | State Home A încă mounted înainte de profil B |
| A04 | FAIL | route:a rămâne vizibilă |
| A05 | FAIL | dialog:a rămâne vizibil |
| A06 | FAIL | route:a rămâne după logout |
| A07 | FAIL | Callback prima epocă A afișează Stale private Alice |
| A08 | FAIL | Callback post-frame executat după dispose (1, nu 0) |
| A09 | FAIL | Token A scris după dispose |
| A10 | FAIL | GPS subscription atașată după dispose (1, nu 0) |
| A11 | FAIL | SDK UID B + auth error păstrează Auth error private a |
| A12 | FAIL | Private snackbar a rămâne în B |
| C01 | PASS | Same UID/null/reconnect/profile error păstrează ruta/profilul |
| C02 | PASS | Same SDK UID/auth error păstrează fallback legitim |
| C03 | FAIL | Prima parte same UID trece; reset B eșuează: dark în loc de light |
| C04 | FAIL | Scope A propriu verificat; State A nu e dispus la B |
| C05 | FAIL | Guard încă true înainte de frame, deși SDK a trecut în B |
| C06 | PASS | FCM owner/refresh/cancel normale |
| C07 | PASS | GPS native attach/cancel normale (fake SDK, nu hardware) |
| C08 | PASS | System Back funcționează normal same session |

GREEN: **NEEXECUTAT** pentru toate A01–A12/C01–C08. Nicio protecție P1 funcțională portată încă.

Alte joburi standard: Python 158 PASS (job115941609821), Node3 PASS (115941610272), Functions npm ci/syntax PASS (115941610099), financial emulator10 PASS (115941609861). Flutter job115941610108 FAIL intenționat prin assertions; smoke Dart/web build nu rulează după eșecul testelor. Protected116 hashes trec prin contractele Python. Nu se numește CI verde.

### Blocaj real identity dispatch

`test-identity-lifecycle.yml` există și declară workflow_dispatch în #35/#28, dar **nu există în main**, SHA default branch `377f1fd5e73ae78a0df5cab58b09770c873cd167`. Verificare locală read-only: `git cat-file -e origin/main:.github/workflows/test-identity-lifecycle.yml` întoarce128/path absent. Pagina Actions identity autentificată nu afișează **Run workflow**; meniul oferă numai badge/pin/disable. Workflow activ, nu disabled. Conectorul GitHub nu expune dispatch, CLI gh/autentificare CLI nu sunt disponibile. Nu s-a trimis cerere REST dispatch; nu susținem un răspuns API404/422 neobservat.

Misiunea precizează: **«Dacă dispatch nu funcționează, STOP cu blocaj clar, nu pretinde verde.»** Se opresc loturile funcționale AuthGate/ROOT și Home/GPS/FCM. Nu schimbăm workflow-urile protejate, baza PR ori main pentru a forța execuția. Cele5 teste identity sunt **NEEXECUTATE** pe #35. Corecția necesară infrastructurii CI trebuie autorizată separat sau furnizată o cale autenticată de dispatch validă, verificabilă pe SHA #35; nu este o problemă de parolă în browser (standard dispatch a reușit).

### Reluare exactă

Păstrează lotul RED și assertions. Rezolvă accesul identity dispatch înainte de fix conform mandatului; după aceea lot2 AuthGateSources/generații/root Navigator+Messenger, lot3 ownership post-await în module existente și transformarea caracterizărilor direct reparate în acceptanțe, lot4 GREEN complet. Nu copia Home monolitic. Nu repeta testele/baza #28 și nu atribui CI #33 acestei integrări.

Hashes RED: acceptance `80fcafaf6715db86d05c26cde64d7fa4893af3f7defb845197041d9e009c2c9f`, regression `9f9cb117b513e80317b99128931594054cbd197d3df8f6e1bfbe2559e558953b`, gate fixture `2c47c2d958fef54fe5ec9e27c6f40ca38ce6c2d0e4a894eb46cc43e9949e6390`, Home fixture `f207d5b4763407bb3962baf8d50809fb3fa78a174113bd5eb45a2405781b7e57`. SHA checkpoint documentar și dispatchul lui sunt raportate separat în PR, fără autoreferință. P1 **încă deschis** în această integrare.
