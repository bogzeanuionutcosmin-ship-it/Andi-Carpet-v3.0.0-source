# Misiune extinsă III — PR #28

Mandat: comentariul [6169977253](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/28#issuecomment-6169977253). Reluare GitHub/local/origin din cdb687060a39064ade930274fdfd221d7652610c, checkout curat. CI existent 38544701066 / 38544701283 SUCCESS, fără rerulare. Loturile 1–32 rămân închise.

## Lot 34 — porturi Admin și preflight fără mutații

AdminPanelPage primește backupFirestore și backupFiles opționale. DB implicit este același FirebaseFirestore.instance, ales lazy. AdminBackupFiles este contract Dart pur pentru pickJson/saveJson, cu un fișier care păstrează byte-read ca await separat. Adaptorul implicit FilePicker păstrează type.custom, allowlist json și saveFile cu aceleași argumente. Cele cinci singleton accesses din actions/panel și cele două operații de fișier folosesc porturile; toate query-urile, UI, await-urile, allowlist-urile și regulile rămân în același loc. Source inversion reconstruiește byte-exact cele trei module Admin anterioare.

### Inventarul I/O existent

| Traseu | Citiri și confirmare | Comenzi și limite |
|---|---|---|
| Panel | meta/backup snapshots; backups orderBy(createdAt desc)/limit(1) snapshots | Nicio comandă numai prin afișare |
| Export | meta/uiSettings get; 16 colecții în ordinea existentă; saveFile | meta/backup lastExportAt numai dacă salvarea fișierului nu întoarce null |
| Manual restore | pickFile → readAsBytes → JSON → preflight formatV1/allowlist/ID/map/uiSettings → confirmare | Pentru fiecare grup prezent: get → delete400 → set400; settings merge:false; marker/log după completare |
| Automatic restore | Confirmare înainte de get parent; status complete → items → preflight ID/map/duplicate/allowlist/settings | Numai grupurile prezente: get → delete300 → set8; settings merge:false; marker/log după completare |

Restaurările nu sunt tranzacționale între batchuri sau colecții. Confirmarea este un avertisment general, nu un nou UX de preview/dry-run. Anularea nu reprezintă rollback. Manual JSON decode și unele citiri sunt în afara blocului de tratare a erorilor; comportamentul nu este schimbat.

### Probe noi

Opt teste folosesc AdminPanel real, Firestore strict sintetic, streams urmărite și FilePicker fake. FirebasePlatform sentry cere zero acces la SDK real:

- Picker cancel: zero byte-read/get/write, exact două abonări de panel păstrate.
- Format viitor V2: refuz înainte de confirmare și DB.
- V1 valid pentru expenses/perDiems/locations/settings: preflight și cancel fără citire/deletare live; payload original nemutat.
- Grupuri nepermise users/visionJournal ignorate; cancel fără comenzi.
- ID invalid în ultimul grup: tot preflight-ul respins înainte de comenzi.
- Automatic cancel: zero get parent/items și zero comenzi.
- Panel stale complete, parent autoritativ failed: un singur get parent, refuz fără items/write.
- Export cancel: exact 17 reads ordonate și un save-file fake; zero marker/log de succes.

Nu s-a efectuat nicio restaurare reală. Aserțiunile zero I/O înseamnă zero comenzi, peste cele două subscriptions de afișare explicit urmărite.

Local: 157 Python PASS, source inversion și 116 protected hashes PASS. Inventar: 213 Dart, 59 parts, 154 biblioteci totale, 81 independente în lib; fără missing/orphan/duplicate/cycles. Flutter/Dart lipsesc local; CI pe SHA lot se verifică după publicare înainte de lotul următor.

## Limite și următorii pași

Accept/partial/batch-failure/retry/concurrency vor rula numai pe fake store; nu se inventează atomicitate. Migration, FCM/GPS, matrice OCR suplimentară și auditul read-only sunt următoarele loturi. P1 AuthGate și defectele cunoscute rămân nereparate. Fără main/merge/rebase/deploy/APK/producție/Firebase rules/config/billing/versiune sau modificări PR #33/#34/#29.

Lot 34 inițial 76522cb / CI 38577042832: 242 teste Flutter existente PASS, noul fișier nu compilează; celelalte 4 joburi și identity 38577042721 SUCCESS. Două erori proprii de fixture: câmpul String parent suprapunea getterul DocumentReference.parent și lipsea importul Material pentru SizedBox. Corecție numai în fixture: parentPath și import Material. Nicio aserțiune sau sursă runtime schimbată. CI corectiv pe SHA propriu urmează.


## Lot 35 — execuție restore, eșecuri și concurență în fake store

Lot 34 corectiv a1c3dc341e86e4901d743730718b54270fc4757b: standard 38577689381 5/5 SUCCESS și identity 38577689350 SUCCESS; 250 Flutter. Nu se repetă scenariile lotului 34.

Opt widget tests noi folosesc aceleași porturi, cu un model durabil strict sintetic pentru batch commands (rejection înainte de aplicare, nu ambiguitate de rețea). Runtime lib/ neschimbat: snapshot automat parțial înlocuiește numai expenses, păstrează perDiems/locations/users omise; duplicate-ID preflight refuză înainte de get/delete operațional; unknown-only manual accept scrie marker de succes fără date operaționale (KNOWN DEFECT); manual insert reject după delete păstrează golirea, eroare unawaited, fără rollback/retry automat, iar retry manual recreează 400+1; JSON invalid scapă din catch înainte de DB (KNOWN DEFECT); automatic last insert reject după delete și primele 8 replacements păstrează stare parțială fără marker; două handler calls concurente înainte de modal frame trec ambele, repetă comenzile și scriu două marker/logs (KNOWN DEFECT); automatic complete ignoră metadata cu format/schema viitoare și înlocuiește grupul valid (KNOWN DEFECT).

Număr exact reads/commits/deletes/markers și store final asserted; nicio restaurare sau I/O real, fără roluri/finanțe mutate în producție. Original snapshots/payloads sunt păstrate în fixture; comenzile simulate pot șterge date din grupurile allowlisted doar după accept. Nu se confundă acestea cu garanția că datele reale ar fi sigure. 157 Python local PASS; inventar 215 Dart /59 parts /156 libraries /81 independente lib. CI pe SHA lot urmează.

## Lot 36 — callbackuri SDK și două migrări concurente

Lot 35 e2a71369fa527c29e17cb29b504feae5ed80ce8b: standard 38578844848 5/5 SUCCESS, identity 38578844948 SUCCESS; 258 Flutter.

Patru probe noi, fără schimbări runtime sau porturi noi:

1. FCM refresh-write reject scapă din callback-ul unawaited. Zone de test cere un singur StateError exact; niciun retry automat. Un nou eveniment refresh poate scrie din nou fără reatașare de listener.
2. Token A întârziat reușește după Home keyed B și atașează ambele listeners după dispose A. După dispose B, refresh încă scrie A. Este o singură probă într-un fișier/isolate separat; cleanup închide sursele sintetice refresh/opened și livrează done prin pump, fără a susține că runtime a anulat listenerul A. Nu se închide niciun SDK real sau bus utilizat de alte teste.
3. GPS service check reușit, dar checkPermission este blocat: permisiunea completată după dispose atașează stream. Dovada diferă de service-enabled gate din lot25. Aserțiunea starts1/cancels0 înainte de cleanup rămâne; fixture-ul anulează manual subscription. Fără poziții/HTTP/liveLocations.
4. Două State Home Admin distincte, aceeași metadata legacy blocată și același DB fake: ambele pregătesc delete/functions/admin/users/marker înainte de primul commit. Două commits execută aceeași ștergere și golire a atribuiri. Snapshoturile sursă nemutate, fără pretenția de integritate DB. Nu repetă badge_v3 sau failure350.

Toate sunt KNOWN DEFECT, nu remedieri sau acceptanță #33. Timeout60s pentru probele de cleanup/concurență. 157 Python local PASS; 218 Dart /59 parts /159 biblioteci /81 independente lib. CI pe SHA lot urmează. Rută chat live, Web700, GPS poziție/geocoding/boost250 și backend real rămân NEEXECUTATE; nu adăugăm guards funcționale.

## Lot 37 — matrice OCR suplimentară, numai widget/fixtures

Lot 36 b9a99f89d7542973c29604a056de1be769a57a21: standard 38580073519 5/5 SUCCESS, identity 38580073605 SUCCESS; 262 Flutter.

Zece probe noi prin parser/form/Expense reale și save fake, fără runtime changes:

| Caz | Rezultat caracterizat |
|---|---|
| TOTAL 1 234,56 | 1,00 lei; KNOWN DEFECT space grouping |
| TOTAL 1234,56 | 1234,56 lei, 123456 bani |
| TOTAL 1.234 | 1,23 lei; KNOWN DEFECT regex truncation |
| TOTAL 238 urmat de SUBTOTAL 200 | 200 lei; KNOWN DEFECT subtotal selectat |
| TOTAL 238 urmat de TOTAL TVA 38 | 38 lei; KNOWN DEFECT TVA selectată |
| Două bonuri în același text | nr/data primului și totalul celui de-al doilea; KNOWN DEFECT amestec documente |
| Litri/preț cu 3 zecimale | prefill rotunjit la 2 zecimale; override manual păstrează 3, suma exactă independentă |
| Două facturi consecutive | imagini/fingerprinturi/ID-uri distincte, două obiecte păstrate, 2135 și 3147 bani |
| Cache local mutat apoi save throw | rândul rămâne vizibil, fără success log/retry; KNOWN DEFECT, nu dovadă server |
| Manual Back și redeschidere | input vechi abandonat; formular gol nou, un singur save, fără OCR/fingerprint |

Fixture-ul primește numai imageOverride și updateLocallyBeforeFailure opționale, implicit identic; snapshot mutate-after-failure este model sintetic de efect optimist, nu Firestore persistence. Cele două grouping tests din lot31 nu se repetă. Parserul, business flow ExpensePage, drepturile și comparatorul Vision nu sunt modificate/importate.

157 Python local PASS, 219 Dart /59 parts /160 biblioteci /81 independente lib; CI exact urmează. Camera/MLKit, server evidence, drepturile Issue32 și integrarea UID #33 rămân NEEXECUTATE.

## Lot 38 — read boundaries și quality gates; checkpoint final

Lot 37 535f3c52fccb75a9ed79fc4b7d8e0951047e1117: standard 38581225548 5/5 SUCCESS, identity 38581225528 SUCCESS; 272 Flutter.

Două probe Admin suplimentare: items TimeoutException scapă înainte de preflight fără comenzi destructivе; items resolve după page dispose continuă delete/set/marker/log, fără success UI (KNOWN DEFECT). Fake store păstrează grupurile omise, nu pretinde anulare/rollback. Contractul file are closure Python fără Flutter/SDK/main și smoke Dart execută citirea lazy/await bytes fără motor Flutter. 158 Python local PASS; 219 Dart =140 lib+78 test/support+1 script, 59 parts, 160 biblioteci totale, 81 independente lib. 116 protected hashes intacte, inventar regenerat fără missing/orphan/duplicate/cycles. Audit lexical, nu dovadă de cod mort.

### Loturi validate până la checkpoint

| Lot | SHA final | Standard CI | Identity CI | Flutter |
|---|---|---|---|---|
|34 porturi/preflight|a1c3dc341e86e4901d743730718b54270fc4757b|38577689381 SUCCESS5/5|38577689350 SUCCESS|250|
|35 execuție restore|e2a71369fa527c29e17cb29b504feae5ed80ce8b|38578844848 SUCCESS5/5|38578844948 SUCCESS|258|
|36 SDK/concurență|b9a99f89d7542973c29604a056de1be769a57a21|38580073519 SUCCESS5/5|38580073605 SUCCESS|262|
|37 OCR suplimentar|535f3c52fccb75a9ed79fc4b7d8e0951047e1117|38581225548 SUCCESS5/5|38581225528 SUCCESS|272|

Checkpointul lot38 are SHA/CI propriu raportat în PR după completare. Totalul final așteptat este274 Flutter (32noi față de242) și158 Python (1nou); nu se declară validate înainte de logul final. 3Node, Functions syntax, financial10+identity5 emulator, smokeDart și web se reconfirmă pe SHA final prin CI, fără rerularea HEAD-urilor vechi.

Singurul eșec intermediar: lot34 inițial76522cb/38577042832 compile fixture, cele242teste existentePASS și4altejoburiSUCCESS; identity38577042721SUCCESS. Corectivul parentPath/import Material nu modifică runtime sau assertions. Celelalte loturi au trecut fără corecții.

## Starea celor șase etape

| Etapă | Executat efectiv | NEEXECUTAT / limită |
|---|---|---|
|A Admin ports/restore|porturi minimale,8preflight/cancel/export +8execuție/race/retry +2read/dispose widget tests|FilePicker/hardware și Firestore live; preview UX nou nu există |
|B backup/migration|partial commits și retry manual în fake store; două migrări concurente/stale metadata; propunere de protecții|network ambiguity, recovery/compensation, server idempotency/ACL și rollback |
|C FCM/GPS|unawaited refresh reject, late-success attach/orphan refresh, permission await după dispose|chat route live/Web700/GPS position/geocoding/boost250; current harness nu izolează DB/HTTP pe GPS success |
|D OCR|10noi widget cases, total/subtotal/TVA/space/compact/dot/mixed docs/quantities/two invoices/local failure/manual Back|MLKit/camera/Firestore persistence/rights Issue32/UID integrare |
|E security overlap|SHAs și4perechi conflicts; plan12acceptance+8controls, PDFhash, Vision diffs|zero portare/testare/CI arbore combinat |
|F quality gates|port closure, plainDart smoke, inventory/hashuri/source inversion, checkpoint și documente separate|59partsState păstrate; fără conversii forțate sau ștergere presupus codmort |

Noile biblioteci runtime sunt numai AdminBackupFiles și adaptorul SDK, plus optionals/getters/substituții Admin/main; în total6fișiere lib modificate față de baseline. Algorithm/preflight/order/batches/rights sunt identice prin inversion. Finanțe, parser, AuthGate, SDK guards, assets, Functions, rules/config, versiune și workflow-urile protejate rămân intacte.

## Riscuri și reluare precisă

Known defects demonstrate nu sunt remediate: restore/migrare destructive non-atomice, markers/commands duplicate, timeout/JSON uncaught și continuare după dispose; token/listener A tardiv, GPS attach tardiv; OCR totaluri/date amestecate sau trunchiate și local evidence după save failure; AuthGate P1/controller Admin istorice. Fake errors sunt înainte de commit, iar un rând local nu dovedește server persistence.

La reluare verificăHEADreal/CI/checkout, citește acest checkpoint și PR description; nu repeta1–37. Următoarea infrastructură posibilă: fake low-level chat route/Firestore read și GPS DB/locality seams strict limitate, ori teste emulator pentru operation identity numai cu scope clar. Remediile funcționale se propun separat conform docs/PROTECTII_BACKUP_MIGRARE_PROPUNERE_2026-10-14.md. Portarea securității are planul docs/PLAN_PORTARE_TESTE_SECURITATE_PR33_2026-10-14.md; niciun scope de integrare primit aici.

Fără main/merge/rebase/deploy/APK/restaurare reală/producție/billing/versiune sau editări PR33/34/29. Checkout final curat/sync după publicare; PR rămâne Draft/Open. Nicio acțiune promisă în fundal.
