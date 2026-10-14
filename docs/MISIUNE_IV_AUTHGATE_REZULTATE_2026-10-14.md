# MISIUNEA IV — AuthGate P1 în structura modularizată

## Reluare după deblocarea identity — 14.10.2026

Comentariul #6172527943 și PR #36 au deblocat verificarea identity. Lotul RED nu a fost repetat. Secțiunile istorice de mai jos descriu oprirea inițială; blocajul lor este depășit prin mandatul nou al proprietarului.

### Loturi de remediere

| Commit | Modificare | Standard CI | Identity CI | Arbore testat |
|---|---|---|---|---|
| ac717fceabc3ba1cb5a55a0b0f0715244fbce717 | AuthGate UID/profile/session generations, reset ROOT Navigator și Messenger, reset numai preferințe personale | 38594719265: 287 Flutter PASS / 7 FAIL; 4 alte joburi SUCCESS | 38594719236 SUCCESS | f6c7301ccd36eee75d3dd0f08313cf0d89c89178 |
| e30a5a12569f1cb9557e8a2cdfee80f2ad2daff7 | Ownership în Home modularizat, callbacks/listeners/post-frame și guarduri FCM/GPS după await | 38595363094 SUCCESS 5/5; 294 Flutter PASS | 38595362938 SUCCESS | 2f3b586f1d0fd48b120ce5548955434d865d9810 |

Cele 7 eșecuri intermediare au fost explicate înainte de lotul următor: A08/A09/A10 și C05 necesitau Home guards; alte 3 teste istorice cereau încă retenția profilului/State Home A. Nu au existat erori de compilare. A01–A07/A11/A12 și 7 controale erau deja PASS după primul lot.

### GREEN verificat pe e30a5a1

Standard 38595363094 COMPLETED/SUCCESS 5/5: 294 Flutter PASS / 0 FAIL, smoke Dart PASS, build web PASS, Python 158, Node 3, Functions dependencies/syntax și financial emulator 10 PASS. Identity 38595362938 SUCCESS: 5 PASS / 0 FAIL. Job IDs: Flutter 115960564054, Python 115960563784, Node 115960563274, Functions 115960563884, financial 115960563853, identity 115960564495. Logurile checkout confirmă merge SHA d69f304 pentru ambele workflow-uri; arborele este identic cu e30a5a1. Cele 116 hashuri protejate trec, fără schimbarea manifestului.

| ID | Scenariu | RED b20ca3b | GREEN e30a5a1 |
|---|---|---|---|
| A01 | Pending A dispare înainte de profil B | FAIL | PASS |
| A02 | Eroare B/global rebuild nu readuc A | FAIL | PASS |
| A03 | Home/listeners A dispuse înainte de B | FAIL | PASS |
| A04 | Rută privată A eliminată | FAIL | PASS |
| A05 | Dialog root A eliminat | FAIL | PASS |
| A06 | Logout/login nu reînvie ruta A | FAIL | PASS |
| A07 | A→B→A respinge prima epocă A | FAIL | PASS |
| A08 | Post-frame personal respins după dispose | FAIL | PASS |
| A09 | FCM delayed: zero attempted write/late attach | FAIL | PASS |
| A10 | GPS delayed: zero late subscription | FAIL | PASS |
| A11 | SDK B/auth error elimină ruta A | FAIL | PASS |
| A12 | SnackBar A nu trece în B loading/Home | FAIL | PASS |
| C01 | Same UID/null/profile reconnect păstrează profil/rută | PASS | PASS |
| C02 | Same SDK UID/auth error păstrează fallback | PASS | PASS |
| C03 | Reset exclusiv personal la UID diferit | FAIL | PASS |
| C04 | Scope financiar propriu și ledger B gol | FAIL | PASS |
| C05 | Guard invalid înainte de dispose respinge own-profile | FAIL | PASS |
| C06 | FCM activ token/refresh/cancel normale | PASS | PASS |
| C07 | GPS nativ activ attach/cancel normale | PASS | PASS |
| C08 | System Back legitim same UID | PASS | PASS |

**Verdict:** P1 client AuthGate/UI demonstrabil remediat în #35 pentru toate cele 12 acceptanțe și 8 controale, în arhitectura modularizată. Nu este încă remediat în aplicația publicată; nu s-a făcut merge sau deploy. Checkpointul documentar are SHA/CI propriu, raportat în descrierea PR după verificare, fără autoreferință în fișier.

### Implementare și integritate

AuthGate păstrează AuthGateSources și API-ul activePageBuilder cu două argumente. Builderul de sesiune furnizează ownership capturat pe generație. Invalidarea profilului/generațiilor este sincronă la UID diferit/logout, iar callbacks verifică și SDK UID; auth-stream error reevaluează currentUser. Root recreează Navigator și ScaffoldMessenger la UID diferit/logout, păstrând aceeași infrastructură la same UID. theme/fontFamily/personalBackgroundId sunt resetate; branding, fundaluri globale, Learning și setări financiare rămân.

Home păstrează toate porturile SDK/query/DB și cele 59 parts. Niciun Home monolitic nu a fost copiat. Guardurile preced proiectarea/mutarea cache-urilor și setările personale în stream callbacks, setState/post-frame, routes și noile subscriptions. FCM verifică ownership după permisiuni/Web700/token/save/initial și înainte de token write/attach. GPS verifică după service/permission/request/cancel/position/geocoding/write; boost250 intră într-o metodă care reverifică sesiunea. Payloads, praguri, query scopes și formule financiare sunt păstrate.

Cele două suite RED (12 acceptanțe + 8 controale) și fixture-urile security sunt byte-identice cu b20ca3b. SHA256:
- auth_session_acceptance_test.dart: 80fcafaf6715db86d05c26cde64d7fa4893af3f7defb845197041d9e009c2c9f
- auth_session_regression_test.dart: 9f9cb117b513e80317b99128931594054cbd197d3df8f6e1bfbe2559e558953b

Caracterizările defectelor direct reparate au devenit aserțiuni pozitive stricte: zero profil/State/rută A, zero callbacks după dispose, zero attempted tokens A, zero orphan refresh, zero GPS late attach. Proba rutei vechi folosește acum AndiCarpetaApp real deoarece root reset aparține aplicației, nu unui MaterialApp extern din fixture. Niciun test nu a fost șters. Proba standalone Home cu AppSettings partajate este etichetată explicit ca fiind fără AuthGate: resetarea personală aparține ownerului sesiunii și este acoperită separat în C03. Cazurile backup/migrare/OCR/controller Admin și refresh-write unawaited rejection sunt păstrate, fără remediere tacită.

### Proveniența CI

Ramura #36 a fost avansată numai fast-forward la fiecare HEAD #35, fără force/rebase și fără commituri proprii. Pull-request trigger a lansat automat atât standard cât și identity. În această sesiune browserul nu avea autentificarea anterioară; nu s-a pretins un workflow_dispatch manual. Am verificat în schimb echivalența exactă a arborilor testată de ambele workflow-uri prin bridge-ul autorizat:

- ac717fc: merge-ref #36 84859e81e75a62ae3ab339cc73c35609c0c81394 → tree f6c7301ccd36eee75d3dd0f08313cf0d89c89178, identic cu HEAD #35.
- e30a5a1: merge-ref #36 d69f304683a55a7f0375e1e76a7316a6d74d1484 → tree 2f3b586f1d0fd48b120ce5548955434d865d9810, identic cu HEAD #35.

#35 păstrează BASE #28; #36 este Draft CI-only DO NOT MERGE cu BASE main. Niciuna dintre ramurile sursă/main nu a fost editată. Standard CI rulează după fiecare lot pe exact aceleași fișiere, chiar dacă SHA de checkout este un merge-ref temporar. Nu se atribuie această dovadă unui dispatch neexecutat.

### Limite și riscuri distincte

Fixul nu anulează writes deja expediate/confirmate, nu revocă tokenuri deja stocate sau notificări OS expediate, nu purjează cache persistent SDK. Maintenance/restore/migrare deja pornite, OCR și autorizarea/revocarea drepturilor în aceeași sesiune necesită misiuni separate. Fără teste pe Android/GPS/FCM hardware ori Firebase live. Probele GPS Web700/boost250/HTTP sunt revizuite în sursă, fără nouă certificare hardware. Injected startup futures externe nu sunt anulate fictiv; efectele reale guardate verifică ownerul.

Fără merge/deploy/APK/producție, schimbări rules/config/finanțe/roluri/parser/backup/Vision sau editări #28/#33/#34/#29/main. #34 a avansat extern la 79507f914551482df1e2f1e60d5b136c87b1c223; nu este lucrarea acestei misiuni.

---

## Istoric RED și oprirea inițială

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
