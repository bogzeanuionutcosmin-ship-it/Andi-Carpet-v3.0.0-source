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
