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
