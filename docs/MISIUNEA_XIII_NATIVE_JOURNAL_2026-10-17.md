# XIII — Native Transactional Journal & Cross-Device Session Fencing

Issue84, succesor independent PR83. `production_ready=false`. PR Draft85;
ramură `fix/native-journal-session-fence-mission-xiii-20261017`.

## Bază și integritate verificate din nou

HEAD real PR83 recitit prin API:7f3bbba3602e7ae109e4b678a90b2bd58431d88f,
tree117b7de466dc2b7708c9bff3cc13a9779842cda7. Verificate înainte de modificări:
Standard38900180666/Identity38900180867/Finance38900180846/
Platforms38900180921 toate completed SUCCESS pe acel SHA. Șase workflowuri
istorice SKIPPED condiționat, nu PASS. Verificare hash efectivă:116/116 +21/21
intacte. Raportul XII, interfețele V2, ChatGpt, registrul regulilor și arhitectura
Vision consultate. Nu presupunem că PASS de la XII validează codul XIII.

## Candidatul nativ livrat și limitele sale

`lib/finance/native_xiii`: wrapper FFI SQLite minimal, jurnal tranzacțional,
coordonator legat de envelope-ul persistent. Nu adăugăm dependențe în pubspec,
nu importăm candidatul în Home/AuthGate/main. `createNativeHistoryXiiiJournal()`
refuză întotdeauna cu `native_v2_platform_release_blocked`; integrarea reală cere
politici private-directory/key/backup și dovezi per platformă. Constructorul
`syntheticHostProbe` este explicit review/test-only, nu un mod de producție.

Un executabil Dart AOT real (`tool/native_xiii/probe.dart`) folosește aceleași
clase FFI/jurnal; Python numai orchestrează procese și verifică IPC. Python NU
implementează storage-ul, lockul sau tranzacția. Nu folosim Web Locks/mutex Dart
pentru a pretinde exclusivitate nativă. Fiecare proces are conexiune SQLite proprie.

### Persistență, identitate, schemă

Director existent și absolut, canonicalizat; filename SHA256 al protocol2+UID+team,
nu nume arbitrar derivat din operație. Symlink-ul DB este refuzat. O bază per scope
are application_id AND2, user_version2, exact o tabelă `journal`, exact un envelope.
Schema SQL, appid/version, quick_check, tipurile și envelope-ul sunt validate.
Triggeri/tabele/scheme străine sau WAL nu sunt adoptate. DB absent la operațiile
normale este refuzat; nu este interpretat ca prima instalare sau listă goală.
Inițializarea este metodă explicită pentru probe sintetice, fără reset/import.
Reapelarea ei peste DB existent validează inclusiv envelope-ul; corupția rămâne.

Envelope:format AndiNativeHistoryJournalV2/protocol2/UID/team/revision/listă
`FinanceSessionXiiiIntent.encode()`/SHA256 checksum. Fiecare record păstrează
EXACT bytes HistoryXiIntent și binding-ul de epoch original. Snapshotul recuperat
nu este reinterpretat V1 și nu primește epoch-ul noii sesiuni. Constructorul nou
pentru A2 poate revizui recordul A1, dar prepare(existing) întoarce false.
UID/team/operationId/target/digest/canonicalizare/unicitate sunt verificate integral.
Limite:32 pending,128KiB UTF8 envelope,16KiB raw history/intent; fără limită monetară
nouă, trunchiere, TTL, evacuare sau cancel implicit. Memoria și scanarea sunt bounded.

### Tranzacție și exclusivitate reală

Primul SQL stabilește `locking_mode=EXCLUSIVE`, apoi `busy_timeout=0`,
`synchronous=EXTRA(3)` și `trusted_schema=OFF`, toate cu readback. Pe Apple se
cer și se verifică fullfsync/checkpoint_fullfsync ON. Modul persistent este
rollback journal DELETE; o bază WAL existentă este refuzată. SQLite EXCLUSIVE
păstrează lockurile nativ și DUPĂ COMMIT până la închiderea conexiunii. Astfel
readback-ul postcommit nu deschide o fereastră de lost update. Proba distinctă
ține A după COMMIT și cere ca B să fie încă refuzat busy, înainte de readback.

BEGIN IMMEDIATE → verifică schemă → read/decode → validate/modify → UPDATE
parametrizat → readback în tranzacție → guard → COMMIT → guard → readback committed
exact → guard → close. Excepțiile înainte de commit fac rollback; eroarea commit
sau după commit nu autorizează send. Nu continuăm unlocked la busy/timeout.
Blocarea în memoria instanței previne numai reentrant calls; nu este dovada de
exclusivitate. Garanția cross-process vine din SQLite/VFS și este probată cu
procese executabile independente, inclusiv faza după commit.

SQL valoric este bind-uit cu SQLITE_TRANSIENT, fără interpolare de payload.
C ABI explicit, allocator/free SQLite comun, stmt finalizat în finally, pointeri
eliberați și pe OOM, nulul text refuzat, text→bytes în ordinea cerută de API.
Engine length limit512KiB, SQL static≤4096bytes, query≤40rows. Version minimum
3.31 pentru trusted_schema și threadsafe!=0; capacitățile reale sunt verificate.
Acesta nu este un audit complet de securitate al motorului SQLite de sistem.

### De ce DELETE/EXTRA, nu WAL presupus sigur

Surse primare SQLite consultate în sesiune indică un advisory WAL-reset pentru
motoare nepatchuite, cu trigger concurent write/checkpoint. Candidatul XIII evită
WAL complet și cere rollback journal DELETE+EXTRA. Propunerea XII WAL/FULL este
istorică. EXTRA solicită și sincronizarea directorului la unlinkul jurnalului;
aceasta nu demonstrează că hardware-ul respectă flush sau că power-loss este sigur.
https://sqlite.org/pragma.html ; https://sqlite.org/lockingv3.html ;
https://sqlite.org/wal.html ; https://sqlite.org/c3ref/column_blob.html .

## Fencing și coordonatorul corect

Nu folosiți coordonatorul generic XII pentru nativul fenced: interfața sa raw nu
poate verifica epoch-ul repository-ului. `NativeSessionXiiiCoordinator` persistă,
recitește wrapperul frozen și construiește FinanceSessionXiiiPort din ACEL record;
nu acceptă un repository separat deja legat de alt epoch. Fresh prepare permite
un singur submit; existing pending cere reconcile explicit, fără replay automat.
Recovery folosește `pendingBound()` și epoch-ul istoric. Rezultatul confirmed nu
este înlocuit de eșecul cleanup; pending rămâne pentru review dacă storage eșuează.

Permisul imuabil server este comis atomic cu summary+receipt. Citirea fence-ului
în tranzacție produce retry/denial când revocarea se ordonează înainte de commit.
Dacă append-ul s-a comis înainte de revocare, efectul rămâne: nu promitem anulare
retroactivă. ACK pierdut se reconciliază folosind același operationId/digest/epoch,
fără alte writes financiare. Dreptul actual de read/review este verificat separat.

Documentație detaliată: MISIUNEA_XIII_SESSION_FENCE_2026-10-17.md. Fencing-ul trebuie
legat de identitatea autentificată semnată, nu numai de epoch-ul clientului.
Altfel A1 poate citi noua generație și fabrica permit A2. Emiterea autoritativă,
reauth și revocarea refresh/ID tokenurilor sunt contract de backend, nu o garanție
a BroadcastChannel sau a unei valori globale de custom claims actualizate tacit.
Provisionerul live/AuthGate sunt BLOCKED; fixture-urile sunt numai demo/emulator.

## Probe executabile și nivelul dovezii

`tool/native_xiii/adversarial_test.py` orchestrează executabilele compilate:
- două PID-uri independente; A a citit și deține tranzacția, B este busy; după
  release A+B rămân exact în jurnal;
- B refuzat și cât A deține conexiunea DUPĂ COMMIT/before readback;
- terminare forțată după begin/read/validate/write, înainte de commit, după commit,
  înainte/după readback; restart pe ACEEAȘI bază;
- kill în cleanup înainte/după commit păstrează recordurile fără legătură;
- logout înainte de commit rollback, după commit păstrează uncertain evidence;
- A→B→A2, transfer de echipă, UID/team străine, epoch vechi păstrat;
- corupție, schemă/version incompatibilă, DB dispărut/malformed, foreign-scope copy;
-32 slots, UTF8 capacity, SQLITE_FULL real prin max_page_count cu rollback și
  recuperare; excepție în tranzacție;
- persist/recreate/coordinator ack loss cu server MODEL, etichetat distinct.

Pe POSIX `Popen.kill()` transmite SIGKILL; pe Windows este TerminateProcess,
nu îl etichetăm SIGKILL. Nu este power-loss. Hookurile deterministe sunt în jurul
apelurilor native, nu probe de kill la fiecare instrucțiune internă COMMIT/fsync.
Nu afirmăm acoperire a tuturor ferestrelor interne ale motorului sau defectelor
filesystem/flash. Hookurile există numai în constructorul syntheticHostProbe.

Separat, testele Firestore JS SDK folosesc emulator real și două contexte/device
independente. Proba combinată lansează executabilul nativ pentru prepare, comite
real pe Firestore cu ACK failure injectat DUPĂ commit, recuperează exact wrapperul
în proces nou, refuză resend, reconciliază read-only și curăță jurnalul. Nu este
un fake backend în această probă. Inițializare authority cu rules disabled este
fixture de test, NU implementare de serviciu de emitere epoch.

Cele7 teste Dart pentru port/session sunt modele, nu hardware/transport real.
Adaptorul Firestore Dart nou este analizat/compilat; controalele SDK XII existente
rămân23 și nu sunt relabelate ca probe ale noului adaptor fără o execuție dedicată.
Cele14 probe browser XII rămân obligatorii, inclusiv renderer PID/SIGKILL.

### Matrice și blocaje

| Platformă | Cod/probă | Limita care rămâne |
|---|---|---|
| Linux host | AOT+SQLite real,28 probe locale; CI obligatoriu pe SHA final | nu este Android; nu hardware/power loss |
| Windows | candidatul folosește winsqlite3.dll; CI compilație exe+procese reale configurat | rezultat final din CI; ACL/DPAPI/backup și Flutter Windows integration BLOCKED |
| macOS host | libsqlite3.dylib/fullfsync; CI AOT+procese reale configurat | nu este iOS; Keychain/container/hardware BLOCKED |
| Android | app factory fail-closed; build main existent compile-only | SQLite de sistem nu este presupus API NDK public; motor împachetat, bridge și Keystore/backup/hardware BLOCKED |
| iOS | loader candidat Apple, app factory fail-closed | link simboluri/entitlements, private container, Keychain/background/device/storage/backup BLOCKED |

Nu există certificare platformă doar dintr-un constructor sau din compilarea APK.
Calea Android caută numai `libandi_finance_sqlite3.so`, motor care trebuie
împachetat separat; absența lui refuză operația. Nu folosim sqlite de sistem
Android ca API NDK presupus. Nu există acel engine în acest PR și nu declarăm
Android verificat prin această ramură de resolver.
Pe toate platformele, symlink sidecars/hardlink/TOCTOU/malicious same-account
filesystem, filesystem de rețea/cloud-sync, cheia pierdută și restore rollback
rămân în afara garanției candidatului și blochează activarea.

## Threat model, backup, migrare și cost

Lockurile SQLite protejează procese cooperante pe același fișier local/VFS. Alte
baze/profile/dispozitive au jurnale diferite; CAS+permit+fence server decid efectul.
Cheia de checksum nu este secretă; checksum nu oferă criptare sau antirollback.
DB/journal/pagini libere sunt plaintext în proba sintetică. Nu ștergem jurnalul
la logout/cache cleanup și nu restabilim din backup peste pending curent.

Politica de criptare OS, keystore/keychain/DPAPI și restaurarea în quarantine sunt
propuneri în MISIUNEA_XIII_MIGRATION_WRITERS_2026-10-17.md, nu cod de producție.
Același document conține inventarul writerilor și gate exclusiv V1/frozen/V2.
Backupurile existente NU inventariază complet receipts/permits/markeri; admin
restore poate încă înlocui unele rooturi nefinanțate prin protecția actuală. Nu le
prezentăm drept recovery financiar complet. Nicio migrare/restore este executată.

Un prepare local scanează≤32 records/128KiB, o tranzacție SQLite+commit+readback,
fără Firebase calls/background listener/timer. Un DB perUID/team poate acumula
multe scope-uri istorice: limita128KiB NU este o limită globală a discului. Nu
ștergem scope-uri unresolved pentru cotă. IO/flush latența și battery sunt UNKNOWN
hardware; quick_check este pe DB mic, dar freelist-ul poate rămâne după cleanup.

Fenced server append3writes (summary,row,permit),4reads/5bootstrap;
replay4reads/0writes; reconcile4serverreads/0writes. SDK retries≤3 și rules reads
pot crește costul. Nu sunt factură live sau garanție Spark zero-cost. Permisul
suplimentar are retenție legată de receipt, nu TTL arbitrar. Nicio schimbare
billing/serviciu plătit/Functions sau consum Firebase de producție.

## Eșecuri și handoff

Primul harness nativ:23/24PASS, cleanup-after-commit proba de fapt read-only
pendingBound anterior lui confirm. Corectat fixture să citească lookup prin altă
instanță fără hook, apoi să suspende tranzacția confirm reală;24/24PASS. Primele
fixture-uri Rules au depășit limita1000expressions; mutual forcing bine delimitat
și probe negative suplimentare au produs16/16PASS, inclusiv flux combinat nativ.
Auditul ulterior a cerut binding al epoch-ului la identitatea autentificată,
nu doar comparație între două date client/server; rezultatele finale ale acestei
întăriri și CI se consemnează în PR85, fără PASS inventat sau verde de la bază.

Următorul pas: motor nativ împachetat și criptare/root policy pe platforme, issuer
server cu identitate de sesiune nereutilizabilă și reauth/revocation, apoi hardware
kill/background/backup/key tests și staging separat. După acestea rămân gate APK
vechi, migrare auditată, toate writerii și aritmetica monetară exactă/global restore.
SHA/tree/CI exacte și matricea finală sunt în PR85 după ultimul commit verificat.

Fără modificări PR82/Shiva/PR83/PR80/main, fișiere protejate,116hashuri/21pini,
Firebase live/rules/date/billing. Fără merge/deploy/migrare/restore live sau APK
instalat/distribuit. Niciun candidat nu este activat de această misiune.

### Întărire de autorizare după primul checkpoint

Fixture-ul final leagă write-urile de token.financeEpoch semnat, permit.epoch și
fence.epoch. Vechiul token nu poate fabrica noua generație citind documentul de
fence. Read-ul financiar cere și generația curentă a CITITORULUI; noul A2 poate
verifica permitul istoric A1, dar vechiul A1 revocat nu poate citi/curăța dovezi.
Proba locală consolidată:19/19 genuine JS/SDK, zero fail/skip, inclusiv nativ+
Firestore. Emiterea autentică a capabilității rămâne BLOCKED, nu este un serviciu
Firebase implementat sau o garanție obținută prin custom claims globale mutabile.

### Runner nativ izolat

Matricea Linux/Windows/macOS compilează Dart3.13.5 dintr-un runner de test pur,
cu crypto3.0.7 deja folosit de aplicație. Configul de package este generat în
runner/.dart_tool, fără modificarea root pubspec/lock/protectedconfig. Astfel
nu rezolvăm inutil pluginurile Flutter de platformă pentru executabilul de probă.
Pubspec-ul secundar este numai harness, nu nouă dependență de producție.
Primul checkpoint CI a trecut244Dart, dar gate-ul analyze a eșuat pe4lintinfo;
corectate în surse, nu eliminate din criterii. Linux/macOS24probe au trecut pe
checkpoint; Windows a fost cancelat în vechiul pubget, fără pretenție de PASS.
Finalul rulează28probe/OS și19fixtureSDK; toate rezultatele exacte se citesc din
CI pe HEAD final în PR85. APK main rămâne numai compile-only.
