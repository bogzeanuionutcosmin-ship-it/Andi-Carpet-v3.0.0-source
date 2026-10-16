# Misiunea XIII — inventar writeri, gate, migrare și recuperare

Data: 2026-10-17 (Europe/Bucharest). Inventar read-only pe baza PR83
`7f3bbba3602e7ae109e4b678a90b2bd58431d88f`, complet pentru writerii financiari
identificați în sursa Dart/Functions/scripts a acestei baze. Nu este inventar al
consolelor Firebase, Admin SDK extern, APK-urilor instalate sau datelor live.
`production_ready=false`. Acest document este propunere de integrare, nu autorizare
și nu modifică reguli live, Home, AuthGate, main.dart, pubspec sau configurații.
Raportul principal XIII consemnează dovezile noului candidat și CI final separat.

Surse locale: ChatGpt/START AICI și checkpoint XII, registrul regulilor,
arhitectura Vision, raportul XII, rollout proposal XI și fișierele enumerate mai
jos. Au fost căutate colecțiile literal și writerii generici `set/update/delete`,
tranzacțiile și batchurile, apoi urmărite callbackurile UI și porturile.

## Inventarul executabil al suprafețelor financiare

| Domeniu / apelant | Writer efectiv, funcție și țintă | Stare și risc de integrare |
|---|---|---|
| Încasare plecare/durante, creare/editare/închidere deplasare | `lib/expenses/expense_settlement_actions.dart`: `_money`, `_createSettlement`, `_editSettlement`, `_toggleSettlementClosed`; callbackuri `widget.saveSettlement` / `widget.saveFinance` | Apelanți reali ExpensePage; pending keys protejează instanța UI, nu dispozitive independente |
| Persistență activă Home | `lib/home/home_financial_write_actions.dart`: `_saveSettlementDirect` → `settlements/{id}`; `_saveFinanceDirect` → `finance/{teamId}` | `set(merge:true)` de model/array/totale; nu folosește jurnalul V2. HomePage construiește ExpensePage cu aceste callbackuri. Regulile pot refuza writerul vechi; nu presupunem succes din UI |
| Bootstrap legacy și valoare implicită | `lib/expenses/expense_page.dart`: getter `finance` creează `TeamFinance` în lista locală folosind `team.financialManagerId` și `settings.defaultPerDiem`; prima salvare merge prin `_saveFinanceDirect` | Nu creează singur document server. Bootstrap V2 cere sursă zero EXISTENTĂ; o instanță locală goală nu satisface această condiție |
| Configurare rată implicită | `lib/admin/admin_settings_actions.dart`: `_saveUiSettings` → `meta/uiSettings.defaultPerDiem`; restore admin poate înlocui uiSettings | Modifică baza viitoare de calcul/bootstrap; nu trebuie rescrisă retroactiv diurna istorică |
| Manager și rată | `lib/expenses/expense_per_diem_actions.dart`: `_manager`, `_perDiemRate`, `_saveFinance`; `_manager` schimbă și `team.financialManagerId` în memorie | Persistență settlement sau finance; V2 receipt-only nu suportă aceste mutații. Schimbarea ratei nu trebuie aplicată retroactiv fără contract |
| Manager/echipă și transfer | `lib/admin/admin_team_actions.dart`: `_editTeam`, `_setTeamActive`, `_deleteTeam`, `_cleanupDuplicateTeams`; `lib/home/home_audit_persistence.dart`: `_persistCoreData` | `teams` conține `financialManagerId`; batchurile actualizează `users.teamId` și membrii. Schimbă autorizarea financiară chiar fără a scrie bani; necesită bump atomic al epochului la transfer/revocare |
| Drepturi și activare cont | `lib/admin/admin_member_actions.dart`: editare funcții, atribuire și active/status; `admin_function_rights_actions.dart`: funcții/permisiuni; `lib/home/home_permission_maintenance.dart`: migrări funcții | Writeri de autoritate, nu plăți. Orice contract cross-device trebuie să îi acopere; callback local de sesiune nu îi înlocuiește |
| Bon/factură manual/OCR/confirmare | `lib/expenses/expense_document_actions.dart`: `_manual`, `_scan`, `_saveNewExpense`, `_confirmExpense` → `widget.saveExpense`; `lib/home/home_financial_write_actions.dart`: `_saveExpenseDirect` → `expenses/{id}` | Writer real, separat de receiptul de numerar. OCR/photo payload poate domina capacitatea. Nicio integrare implicită în jurnalul receipt V2 |
| Ștergere document financiar | `lib/admin/admin_operations_actions.dart`: `_deleteExpense` → `expenses/{id}.delete()` | Existența butonului/apelului nu dovedește autorizare server. Necesită politică de corecție/audit înainte de rollout financiar |
| Diurnă legacy: distribuire/supliment/confirmare/refuz | `lib/expenses/expense_per_diem_actions.dart`: `_distribute`, `_supplementaryPayment`, `_answerPerDiem`; Home `_savePerDiemDirect` | `perDiems/{id}`: create-only transaction pentru distribuire; răspunsul beneficiarului actualizează atomic documentul + `receiptAudit/{randomId}`. Nu este jurnal V2, nici operationId V2 |
| Dispută diurnă | același fișier ExpensePage: `_respondToPerDiemDifference`, `_resolvePerDiemDispute` | tranzacții directe `perDiemDisputes/{perDiemId}`, distincte de plata efectivă |
| Diurnă repository separat | `lib/finance/per_diem_firestore_repository.dart`: `declarePayment`, `acknowledge`, `dispute`; `per_diem_confirmation_card.dart` apelează `repository.acknowledge` | `per_diem_settlements_v2/{id}` + `audit/declare` sau `audit/revision-N` în tranzacție. Numele v2 NU înseamnă protocol HistoryXi V2. Nu comasați cu `perDiems` |
| Candidate intent V1 | `lib/finance/intents/finance_repository.dart`: `FinanceRepository.execute`; `firestore_finance_port.dart`: `_FirestoreFinanceTransaction.write` | target `finance`/`settlements` + child `financialIntents/{operationId}`, protocol V1. Emulator-only port; V1 poate create/edit/close/receipt, nu manager/rate arbitrary patch |
| Adapter ExpensePage și Home opțional | `finance_expense_demo_adapter.dart`: `createSettlement`, `saveSettlement`, `saveFinance`, `_save`, `_run`; `finance_home_candidate.dart`: `saveSettlement`, `saveFinance` | Candidate V1; acceptă numai tranziții recunoscute pe baseline server, recovery explicit. Propunerea Home nu este aplicată. Nu le prezentați drept integrare V2 |
| Candidate append-only V2 | `lib/finance/history/history_xi.dart`: `FinanceHistoryXiRepository.executeExplicitly`; `history_xi_firestore.dart`: `_HistoryTransaction.write` | numai `financeHistoryXi/{s_sourceId|f_teamId}` + `receipts/{operationId}`, 2 writes atomice; port numai emulator. Bootstrap doar sursă existentă cu bani/istoric/revizie zero. Nu este migrare a soldurilor vechi |
| Jurnal local și coordonator XII | `lib/finance/journal_v2/history_v2_journal.dart`: `HistoryV2Coordinator.executeExplicitly`, `reconcileExplicitly`, `_finish`; `browser_journal_v2.mjs`: `prepare`, `confirm` | scrie local envelope protocol/UID/team; nu este writer Firestore independent. Numai intenția nouă persistată permite un send. Pending existent → reconcile, fără replay automat |
| Restore demo țintit | `finance_restore.dart`: `FinanceDemoRestore.executeExplicitly`; `firestore_restore_port.dart` | `finance`/`settlements`/markers sunt numai guards. Writes numai `locations`, `cars`, `documents`; NU este restore financiar |
| Restore admin JSON/automat | `lib/admin/admin_backup_actions.dart`: `_restoreBackup`, `_restoreAutomaticBackup`, `_rejectLegacyFinancialRestore` | preflight refuză întreaga operație dacă apare `finance`/`settlements`, înainte de delete. `expenses`/`perDiems` rămân colecții înlocuibile prin delete+batch set; nu sunt acoperite de dovada restore V2 |
| Export și backup automat | același fișier `_exportBackup`; `lib/home/home_backup_maintenance.dart`: `_createAutomaticBackup`, `_pruneAutomaticBackups` | citesc top-level finance/settlements/expenses/perDiems în snapshot. Omit subcolecțiile financialIntents, receiptAudit, auditul per-diem separat, financeHistoryXi și pending local. Nu sunt backup complet financiar |
| Execuții/grafice, surse de drepturi la diurnă | `lib/home/home_operational_write_actions.dart`: `_saveScheduleDirect`, `_saveRecordDirect`; `lib/admin/admin_operations_actions.dart`: `_setScheduleClosed`, `_deleteSchedulePermanently`, `_deleteRecord` | schimbă `schedules`/`records`, de unde pot deriva calcule. Nu sunt bani jurnalizați V2; migrarea trebuie să fixeze sursele istorice, nu recalcul din snapshot curent |
| Telemetrie și audit lateral | `lib/home/home_financial_write_actions.dart` → `_writeLearningEvent`; `home_audit_persistence.dart`: `_writeAuditRemote`; ExpensePage callback `log` | scrieri separate după operație, unele unawaited. Auditul/learning nu este receipt financiar atomic și nu trebuie folosit ca dovadă de commit |

`functions/index.js` și `functions/backfill_member_directory.js` au writeri
push/SMS/memberDirectory, fără writer direct finance/settlements/perDiems/expenses
în sursa auditată. Scripturile de audit nu migrează bani. Fixture-urile sub `test/`
și `tests/` scriu synthetic demo data; ele nu sunt inventar de clienți live.
Codecurile `home_document_codecs.dart`, modelele, PDF, calculele ledger/balance și
`firestore_ledger_port.dart` sunt serializare/citire/calcule, nu writeri suplimentari.

## Gate autoritativ V1/V2 — propunere separată

Un flag UI, versiunea APK declarată de client, BroadcastChannel sau jurnalul local
nu poate opri APK vechi/alt dispozitiv/REST de la scrieri permise de server.
Propunerea folosește un document autoritativ per echipă (de exemplu
`financialProtocolGates/{teamId}`), writer numai autoritate server:
`{mode: legacy|frozen|v2, generation, migrationId, approvedSnapshotDigest}`.
Numele și schema sunt propuneri; nu există activare în producție prin acest PR.

| Mod | finance/settlements legacy + child markers | HistoryXi + receipts | Operație administrativă |
|---|---|---|---|
| legacy | numai regula V1 explicită, dacă epochul și actorul sunt autorizați | deny | fără migrare implicită |
| frozen | deny write tuturor clienților | deny write tuturor clienților | inventar și reconciliere numai prin traseu autorizat distinct |
| v2 | deny write inclusiv vechi APK/admin client | protocol2 exact + generation curentă + append atomic + current authority | fără downgrade automat |

Missing/invalid gate = deny, nu fallback legacy. La create/read de sursă absentă
nu se creează implicit gate. Fiecare family financiar trebuie tratată explicit:
receipt de cash, cheltuială, diurnă legacy, diurnă repository, dispută, corecție,
manager/rate/bootstrap și restore. Dacă un family nu are implementare nouă validă,
fie rămâne într-un namespace/scope separat aprobat, fie blochează promovarea
întregii echipe; nu lăsați writerul vechi să modifice aceeași autoritate monetară.

Important: Firestore rules sunt OR între matchuri. Un `allow false` într-un nou
match NU neutralizează un catchall admin permisiv. La baza auditată catchallul
exclude numai `finance`, `settlements`, `expenses`; viitoarele gates, session epoch,
`financeHistoryXi`, `perDiems`, `perDiemDisputes`, `per_diem_settlements_v2` și
copiii lor cer excluderi explicite și teste adversariale admin/REST/SDK.
Admin SDK ocolește rules: restaurările/migrările privilegiate trebuie să citească
și verifice gate/epoch/CAS în același serviciu/tranzacție, cu IAM și audit proprii.

Gate și autoritatea sesiunii sunt citite în aceeași tranzacție cu CAS și receiptul,
iar rules verifică starea autoritativă la commit. Se păstrează strict revizia și
bindingul UID/team/protocol; clientul nu poate atribui propria generație nouă.
Revocarea concurentă are ordine de commit: înainte de revocare plata poate fi
comisă și doar ACK-ul poate veni târziu; după revocare o cerere veche este refuzată.
Nu promitem anulare retroactivă. Missing receipt după eroare nu dovedește anulare;
intenția rămâne uncertain pentru reconciliere autorizată și audit.

## Contractul de integrare jurnal–sesiune

Recordul nativ salvează `FinanceSessionXiiiIntent`, inclusiv bindingul ORIGINAL
UID/team/epoch. Recovery trebuie să consume `pendingBound()` și să construiască
portul server pentru acel binding, nu să reambaleze receiptul XI cu epochul curent.
Un epoch vechi poate avea commit înainte de revocare și trebuie reconciliat prin
permitul istoric exact, sub autorizare de citire curentă.

Interfața generică `HistoryV2Journal.pending()` proiectează numai HistoryXiIntent;
această proiecție nu este inventar suficient pentru recovery fenced. Integrarea
va verifica exact equality dintre bindingul salvat de jurnal și bindingul
intenției/portului server la primul send. Simpla egalitate ownerUid din
coordonatorul XII nu demonstrează epoch/team alignment. Nicio integrare Home
nu este autorizată de existența acestor interfețe.

## Migrare fără pierdere și fără dublare — încă neexecutabilă live

1. Inventariați mai întâi TOȚI clienții/writerii de mai sus, versiunile instalate,
   Admin SDK, jobs și reguli; staging separat și canary fără bani reali. O versiune
   instalată necunoscută este BLOCKED, nu presupusă retrasă.
2. Opriți writerii la server prin `frozen` + generație incrementată. Revocarea
   tokenului nu înlocuiește gate-ul la fiecare scriere. Verificați zero scrieri
   vechi permise, inclusiv admin catchall și sesiunile offline reconectate.
3. Drenați/reconciliați toate intențiile cunoscute V1 și V2 cu exact ID/digest;
   inventarul local al unui dispozitiv nu dovedește că nu există pending pe altul.
   Nu convertiți un V1 pending într-un V2 pending și nu retrimiteți automat.
4. Capturați un manifest read-only la revizii fixate: toate rădăcinile, toți copiii
   marker/receipt/audit, opening balances și documentele legacy fără ID-uri stabile.
   Numărați, verificați digest și legături, duplicate, gaps, orfani, nanos și Unicode.
   Query paginat fără barieră nu este snapshot global consistent.
5. Verificați banii cu reprezentare exactă și regulă aprobată explicit. Auditul XI
   bazat pe doubles poate refuza valid `0.1+0.2+0.3` în ordine inversă. Nu rotunjiți
   tacit solduri și nu deduceți încasări fictive din diferența agregatelor.
6. Planul de import trebuie să aibă mapare deterministă sursă→destinație și
   `migrationId`+digest unic, executabil idempotent pe loturi cu checkpoint CAS.
   Fiecare document importat o singură dată; sold opening separat de receipts reale.
   Nu folosiți `HistoryXiIntent` normal ca și când banii istorici ar fi nou încasați.
7. Rulați dry-run și comparație independentă integrală, apoi staging crash/resume și
   conflict pe fiecare lot. Doar după autorizare separată poate fi planificată
   migrarea live. Prezentul candidat nu oferă un motor de migrare financiară.
8. Promovați gate numai când întregul manifest corespunde și writerii noi sunt
   pregătiți. Arhiva legacy rămâne imuabilă/read-only; ID-urile și dovezile originale
   nu se șterg. Reactivarea APK-urilor vechi nu este rollback sigur.

Nu se unifică diurna `perDiems` cu `per_diem_settlements_v2` prin nume/schema.
Avansul peste cuvenit este permis în regulile produsului; nu adăugați un plafon
monetar folosind limita jurnalului și nu rescrieți responsabilitatea istorică după
transfer. Manager, rata și entitlement au nevoie de propriul contract de operație.

## Criptare, backup, restore, rollback

Candidatul SQLite tranzacțional nu este implicit criptat. SQLite EXTRA/rollback
journal nu înlocuiește SQLCipher sau criptare AEAD verificată. Checksum SHA256 nu
este MAC, nu ascunde nume/sume și nu detectează reîncărcarea unei copii vechi valide.
Fișierul DB, sidecarul journal/WAL, paginile libere, temp files și logurile se
tratează toate drept date sensibile. Backup numai prin API consistent verificat,
nu copiere DB deschisă fără sidecare. Nu trimiteți jurnalul către Vision/loguri.

Propunere pentru integrarea ulterioară: cheie aleatoare per instalare protejată
Android Keystore / iOS Keychain / Windows DPAPI; proveniență și rotație de cheie,
key version în envelope autentificat, UID/team/protocol și database incarnation
legate criptografic. Modulul de criptare se selectează după review de platformă;
nu implementați criptografie proprie pentru a evita o dependență. Pubspec este
înghețat și nu s-a adăugat pachet SQLite/SQLCipher în această misiune.

Politica minimă înainte de lansare:

- DB în director privat de aplicație, cu permisiuni/ACL, cale stabilă canonică și
  aceeași bibliotecă SQLite/VFS pentru toți writerii. Nu network share/FAT/export
  arbitrar; aliasuri/hardlinkuri/symlinkuri nu trebuie să creeze două lock domains.
- Excluderea backupului OS pentru pending+chei până există restaurare proiectată;
  Keystore/Keychain/DPAPI și backup au politici diferite. Reinstall/profile reset,
  cont OS nou sau key loss nu creează automat un jurnal gol declarat sigur.
- Restore numai într-o bază de carantină, fără writer activ; verificare integrală,
  proveniență/anti-rollback și reconciliere server a fiecărui operationId. Union
  fără duplicare și fără schimbarea ID-urilor; conflict de digest → BLOCKED.
- Un snapshot server nu conține pending nestrimis; DB locală nu conține toate
  receipts de pe alte dispozitive. Sunt necesare ambele inventare, nu un singur
  checksum de prefix. Missing DB și prima instalare sunt indistincte fără o
  evidență externă/provisioning autoritativ.
- Rollback de cod oprește send, păstrează DB/schemă și permite doar review/reconcile.
  Nu downgrade schema, gate sau epoch și nu reface solduri vechi peste receipts
  noi. Corecția contabilă este operație nouă aprobată, niciodată delete istoric.
- Eșec/full/corupție/versiune necunoscută: fail-closed; păstrați fișierele și pending,
  fără clear-cache/reset/TTL. Exportul de investigație cere protejarea datelor.

## Costuri și capacitate

Jurnal local: zero apeluri Firebase la pending/prepare/confirm. Limita de produs
rămâne 32 intenții și 128KiB envelope UTF8 (16KiB/intentie), nu limită de bani.
Limita pe envelope nu plafonează numărul de scope-uri UID/team, mărimea fizică DB,
sidecar, freelist sau backup; înainte de lansare sunt necesare quota totală și
politică de retenție pentru scope-urile GOALE, fără evacuarea pending. SQLite EXTRA
poate face sync per commit; latența și energia trebuie măsurate pe hardware.
Un checksum O(bytes) al envelope-ului și readback complet nu sunt gratuite ca IO.

Baseline XI per append: 2 document reads + 2 writes, încă 1 read la bootstrap;
reconcile: 2 server reads, 0 writes; replay: 0 writes. SDK max3 încercări poate
repeta reads. Un gate+epoch în două documente adaugă până la 2 citiri de autoritate
per încercare, înainte de rules dependent accesses/cache; documentul unic comun
poate reduce acest număr, cu contention diferit. Exemplu aritmetic de planificare:
1000 appends fără retry/bootstrap: 2000 writes, ~4000 reads cu cele două guards;
1000 reconciliations: 2000 reads, plus guards dacă politica le cere. Nu este o
factură, nu include listener/index/network/storage/rules sau migrare și nu dovedește
încadrarea în quota contului real.

Firestore taxează documente citite/scrise/șterse, unele index reads, storage cu
indexuri/metadata și trafic. Reads dependente ale rules pot fi facturate și la
refuz; retry-urile și listener reconnect cresc consumul. Nu avem măsurători live,
regiune, plan ori tarif validat pentru acest cont; nu promitem 0 lei nelimitat.
Backup/PITR/restore managed sunt operațiuni cu tarif separat și nu sunt activate.
Sursa primară: https://firebase.google.com/docs/firestore/pricing (consultat
2026-10-17); costurile se recalculează înainte de lansare, fără schimbare billing.

Limite Firestore relevante din documentația primară: document 1MiB, API request
10MiB, rules access calls 10 pentru single/query și 20 multi/transaction/batch
(păstrând și limita per operație), tranzacție cu deadline270s/idle60s. Nu proiectați
un import global într-o singură tranzacție. Formula repository pentru dimensiune
nu este wire-size, index-size sau certificat pentru photo payload. Sursa:
https://firebase.google.com/docs/firestore/quotas (consultat 2026-10-17).

Candidatul XIII folosește rollback journal `DELETE`, `synchronous=EXTRA(3)` și
`locking_mode=EXCLUSIVE` setat înainte de primul acces SQL la baza persistentă.
EXCLUSIVE păstrează lockurile până după COMMIT/readback și închiderea conexiunii.
EXTRA cere și sincronizarea directorului la ștergerea rollback journalului.
Propunerea WAL+FULL din raportul XII este istorică și este înlocuită pentru XIII;
nu există WAL activ în noul candidat. Garanțiile depind de locking VFS și de
respectarea flushului de OS/storage; EXTRA nu este o dovadă hardware de rezistență la power loss. Garanțiile și crash
stages se citesc din https://sqlite.org/atomiccommit.html și
https://sqlite.org/pragma.html#pragma_synchronous (consultate 2026-10-17).
SIGKILL, disk-full, suspend și tăiere de curent sunt probe diferite.

Audit actual de motor: https://sqlite.org/wal.html secțiunea11 descrie bugul
WAL-reset pentru versiuni până la3.51.2; fix în3.51.3+ și backporturile3.44.6/3.50.7.
Triggerul presupune conexiuni care scriu/checkpoint concurent în WAL. Candidatul
XIII a ales explicit DELETE+EXTRA și respinge baze WAL; astfel nu folosește traseul
afectat. Nu transformați un prag de capabilitate SQL într-o certificare generală
a motorului. Pentru packaging de producție se verifică versiunea/proveniența și
invarianta exclusivității. Biblioteca de sistem poate fi mai veche decât fixul. Documentație consultată2026-10-17; nicio dependență actualizată.

## Matrice de acceptanță pentru lansare

| Platformă | Ce poate proba această misiune | Ce rămâne BLOCKED înainte de activare |
|---|---|---|
| Android | contract comun Dart/FFI, teste native pe host; APK existent compile-only dacă CI trece | bibliotecă SQLite suportată/pachetată și ABI pe dispozitiv, sandbox/cale privată, două procese Android, force-stop/suspend/storage full, Keystore și backup/upgrade hardware |
| iOS | candidat și contract FFI analizabile; niciun rezultat Linux/Android nu este iOS PASS | linkarea bibliotecii aprobate și XCTest/Flutter pe macOS+iOS, Data Protection/locked-device, background kill, Keychain/restore și orice App Group aprobat |
| Windows | teste reale pe runner Windows pot valida exact binary-ul Dart/SQLite DLL folosit în CI | distribuirea verificată a DLL, version/architecture/provenance, ACL/DPAPI, două procese aplicație reală, Windows power loss/antivirus/disk full/backup hardware |
| Web | controalele XII rămân regresii Web Locks/IndexedDB pe Chrome, nu backend SQLite | sesiune comună integrată în taburi și gate server real, Safari/Firefox/partition/eviction/backup/encryption |
| Cross-device | rules+SDK emulator pot proba ordinea revocare/commit și epoch CAS | authoritatea reală de emitere/revocare, toți writerii și clients instalați, două dispozitive în staging, approval rules și cost live |

Nicio celulă condiționată de CI nu este PASS implicit. Raportul principal XIII și
PR-ul final trebuie să enumere probele efectiv executate, SHA exact, FAIL/skip și
runner/OS; o compilare APK nu execută jurnalul. Hardware și power loss sunt
BLOCKED până la dovezi separate. Următorul pas este integrarea autorității de
sesiune/gate și ambalarea nativă, în staging, după review și autorizare separată.
