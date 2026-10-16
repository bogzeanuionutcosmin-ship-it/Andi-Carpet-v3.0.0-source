# Misiunea X — opt-in Home boundary / DO NOT MERGE

Issue #77. Bază verificată PR #73: 4cd6ee522534b6e5edd45d6112ddadf23c418bac.
Working tree inițial curat. production_ready=false. Nicio modificare în Home,
AuthGate, main, pini, PR73/74/75 sau producție.

## X-01 — matrice exactă de writeri

| Flux | Intrare → persistență | Identitate / stare / risc |
| --- | --- | --- |
| create | expense_settlement_actions._createSettlement → saveSettlement → Home._saveSettlementDirect | idNow; set merge; fără CAS; succes/audit după Future, nu marker |
| edit / close / reopen | _editSettlement / _toggleSettlementClosed → același callback | obiect comun optimist; rollback sigur doar la FinanceSaveRejected; eroare generică close poate inversa starea |
| receipt settlement / legacy | _money → saveSettlement / saveFinance | ID local nou; listă și agregate mutate; set merge poate pierde alt receipt |
| manager / rate | expense_per_diem_actions → saveSettlement / saveFinance | același callback, semnificație diferită; nu sunt acoperite de protocolul receipt/edit/close |
| bootstrap finance | ExpensePage finance fallback → model TeamFinance | lipsa documentului nu autorizează creare financiară implicită |
| OCR/manual expense / confirm | expense_document_actions → saveExpense → Home._saveExpenseDirect | set merge + cache după await; reguli candidate separate; fără jurnal de intenții pentru acest flux |
| perDiems distribute | savePerDiem → Home._savePerDiemDirect | create-if-absent transaction, ID nou după intenție nouă; Learning/cache după await |
| perDiems receipt/refusal | același writer → tranzacție update + receiptAudit | beneficiar UID verificat; nu unificat cu v2; avans păstrat |
| per_diem_settlements_v2 | PerDiemFirestoreRepository | revizie/audit separat; nu convertit prin noul seam |
| Admin delete / backup / restore | admin_operations_actions / admin_backup_actions | delete expense separat; gard financiar pre-write; V1 nu inventariază financialIntents |

Home instanțiază ExpensePage în home_page.dart:358; diagnosticSessionIsCurrent
folosește sesiunea Home. Gate UI nu înlocuiește ACL server. Listener-ele Home,
cache-urile și modelul mutabil nu dovedesc confirmarea unei intenții. Learning
și auditul UI rămân în afara tranzacției; nu trebuie emise la rezultat incert.
Adaptorul nou trebuie legat de UID+generation+echipă, checked secure journal,
server observation și înlocuire de model înaintea finalizării callbackului.

## Dovezi preflight

Patru workflowuri PR73 SUCCESS: Standard 38857937421, Identity 38857937361,
Finance IX 38857937305, Platforms IX 38857937304. Acestea sunt baza, nu CI X.
Fixture-uri refolosite: ExpenseDocumentFixture, FinanceAtomicFixture, probele SDK
VIII/IX, checked journal IX. Nu numărăm din nou acceptanțele IX ca remedieri X.

## X-02/03/04/09 — candidat nou, înainte de CI

FinanceHomeCandidate reutilizează coordinatorul și adaptorul existent; storage
este învelit obligatoriu în checked journal. Constructorul nu face I/O. Callbackul
saveSettlement distinge țintele observate de CREATE atomic; o țintă existentă
neobservată produce conflict, nu overwrite. UID+generation+team closure este
monotonă inclusiv la excepții. Modelul altei echipe este refuzat înainte de I/O;
jurnalul UID care conține altă echipă blochează recuperarea fără ștergere/adoptare.
Nu există fallback la legacy, timer, retry sau activare Home implicită.

Nouă probe Flutter candidate: 3 formate de sumă cu create/receipt/edit/close/open,
anulare/rebuild/dublu click, commit întârziat și revocare, recuperare cu obiect
nou, echipă străină și conflict pe țintă existentă neobservată. Fixture-ul este
ExpensePage real; portul acestor probe este fake determinist. O probă SDK nouă
folosește Auth/Firestore emulator + secure-storage web plugin real, create și
receipt cu ack pierdut, apoi compoziție nouă și reconciliere explicită fără send.
Controalele VIII/IX rămân în același entrypoint. Nu este restart browser/OS.

CI IX este extins DOAR la predicatul ramurii X, păstrând toate comenzile și
controalele. 199 teste Python locale PASS. Rezultatele Flutter/SDK/platforme
rămân CANDIDATE până la CI pe SHA nou.

## X-05 — matrice legacy extinsă, candidate înainte de CI

Proba IX de stale merge după commit nou este extinsă pe 4 actori ai clientului
vechi (admin, gestionar, membru, director în aceeași echipă), 2 colecții și 2
rulesets: 16 cazuri, dintre care 12 noi. Payloadul vechi încearcă să reducă
încasarea 225→25 și să golească lista fără schimbarea reviziei/markerului.
Rules main sunt snapshotul SHA-pinned IX; rules candidate sunt neschimbate.
Nu pretindem că rules live sunt identice cu vreunul dintre acestea.
Probele ACL/diurnă/marker/revizie VIII și SDK IX sunt reutilizate neschimbate.
Compatibilitatea vechi/nou rămâne BLOCKED: acceptarea scrierii vechi permite
pierderea încasării noi; refuzul ei întrerupe salvarea APK-ului vechi.

## X-06 — ce coordonează efectiv concurența

Noua probă de boundary folosește două compoziții și două jurnale independente,
cu snapshoturi revizie1: prima încasare ajunge la revizie2, a doua rămâne conflict
și nu poate suprascrie 200 sau primul marker. Este port fake, nu două telefoane.
Suitele SDK VIII/IX folosesc două FirebaseApp/Firestore independente în același
Chrome și probează server CAS; nu sunt două taburi sau procese OS distincte.

Lockul FinanceIntentJournal._queues este static în isolate, indexat pe UID.
Checked storage oferă readback, NU compare-and-swap. Două procese pot citi
jurnalul gol, apoi scrie envelope diferite, ambele valida readback la momente
diferite și pierde intenția primei instanțe din jurnal. Backend CAS protejează
ținta, dar NU restaurează ID-ul local pierdut și NU coordonează ținte diferite.
Concluzie critică: exclusivitate cross-tab/process neasigurată; activarea pe
mai multe instanțe este BLOCKED. Nu inventăm lock global sau certitudine fizică.

## X-07 — backup/restore

admin_backup_actions._exportBackup enumeră colecții de nivel superior, citește
fiecare colecție separat și serializează documentele, fără financialIntents.
Nu este snapshot global. Backupul nu include secure journal local și nu poate
fi folosit pentru ștergerea lui. Restore manual și automat refuză finance și
settlements înainte de write/delete. FinanceRestorePlan păstrează documentele
financiare/markerii numai ca precondiții, nu îi rescrie; importul financiar complet
rămâne BLOCKED. Refolosim regresiile existente de concurență, import parțial,
ack pierdut și excepție tipizată după write; nu le numărăm ca reparații noi.
O intenție incertă nu este backup regenerabil. Nu există restore live.

## X-08 — capacitate și cost

Scenariile executabile în MISIUNEA_X_CAPACITY_2026-10-16.json refolosesc modelul
VIII strict: 40 operații + 40 verificări explicite zilnic, până la 3 încercări SDK,
20 receipts/zi pe aceeași țintă, 4KiB document inițial, 1KiB/receipt (ipoteze).
Reads document+rules: până la 3960/zi, writes:80/zi; constructor/rebuild:0.
Compoziția X nu adaugă citiri/scrieri Firestore față de IX. Recuperarea locală
are o citire checked suplimentară de preflight, fără bani ori rețea.
Dimensiunea documentului modelat: 618496/3690496/7479296 bytes la 30/180/365 zile;
rezerva internă de 512KiB se atinge după 25 zile complete. 180/365 depășesc și
limita documentului de 1MiB. Markeri+istoric/index ipotetic: 3686400/22118400/
44851200 bytes. Nu trunchiem receivedEntries, nu introducem TTL financiar.
Baseline, plan eligibil, billing, index read multipliers efective și egress live
rămân UNKNOWN; modelul refuză production_ready în toate cele trei scenarii.

## X-10 — diff protejat propus, NEAPLICAT

MISIUNEA_X_PROPOSED_HOME.patch este un diff textual minim pentru review, generat
din exacta bază locală. Adaugă import/injecție opțională și două callbackuri de
rutare; flagul rămâne FALSE. Când TRUE, un candidat absent/expirat refuză în loc
să cadă în legacy. Disposal și înlocuirea proprietarului închid candidatul.
Nu s-a aplicat în main.dart/Home/AuthGate și nu s-a schimbat niciun SHA-pin.
Patchul singur NU este o integrare completă sau gata de activare.

Înaintea aprobării aplicării: factory externă pe sesiune AuthGate cu UID+epoch
și echipă curentă, notificare/dispose sincron la transfer/revocare, observer
Source.server+metadata, înlocuire de modele verificată, recovery UI fără date
între conturi, toate operațiile manager/rate/bootstrap/OCR/perDiem explicit
acoperite sau rutate prin contract distinct aprobat. Nu se creează intenții la
login/rebuild. Nu este propus patch AuthGate speculativ înainte de acest contract.

Rollout pregătit: (1) teste și review deprotejare nominală; (2) staging separat
cu toți writerii și dispozitive vechi inventariate; (3) upgrade/min-version gate
aprobat și testat, recuperarea intențiilor nerezolvate; (4) rules compatibile cu
același contract, fără fereastră de downgrade; (5) activare controlată numai după
acceptanțe. Fiecare trecere necesită mandat separat. Rollbackul după marker nu
poate reactiva scrierea legacy sau rules permisive; păstrează jurnal/marker și
oprește operațiile noi până la recuperare. Fără migrare sau backfill implicit.

## X-11/12 — handoff și verdict

PR Draft #78, ramură fix/finance-home-boundary-mission-x-20261016.
Nu se închid issues #32/#53/#54/#72/#77. production_ready=false.

| Lot | Rezultat sigur livrat | Limită obligatorie |
| --- | --- | --- |
| X-01 | Matrice writeri și risc pe fiecare callback | Home implicit neschimbat |
| X-02 | FinanceHomeCandidate, checked journal obligatoriu, callbackuri originale, team/session gate | exclusiv opt-in, port SDK numai demo |
| X-03 | ExpensePage original create/receipt/edit/close/open, 3 formate sumă, anulare/rebuild/dublu click | manager/rate refuzate la boundary, nu implementate |
| X-04 | recreare compoziție și recovery fără send, probele crash/corupere IX reutilizate | restart OS, fsync și secure storage Android UNKNOWN |
| X-05 | 16 cazuri legacy actors × rules × collection; ACL/diurnă VIII reutilizate | rollout APK vechi BLOCKED |
| X-06 | două compoziții/jurnale distincte pe port fake; SDK multi-client VIII reutilizat | cross-tab/process lock BLOCKED; telefoane UNKNOWN |
| X-07 | audit exact export/restore/jurnal; regresiile existente păstrate | restore complet/global snapshot BLOCKED |
| X-08 | scenarii 30/180/365 cu model executabil existent | baseline/index/egress/billing live UNKNOWN |
| X-09 | revocare monotonă, commit întârziat, zero audit/UI vechi, refuz cert vs pending | factory Home/AuthGate neactivată |
| X-10 | patch textual minim cu flag FALSE și porți rollout/rollback | NEAPLICAT; review și mandat distinct necesare |
| X-11 | predicate CI X fără relaxarea testelor; Standard/Identity/Finance/Platforms solicitate | CI final se citește pe SHA exact în PR |
| X-12 | ChatGpt, raport, diff protejat, riscuri și handoff | nu reprezintă acceptanță de lansare |

### Matrice flux / tip de dovadă

| Flux | Dovadă și rezultat |
| --- | --- |
| candidat create→receipt→edit→close→open și 200/200.00/200,00 | ExpensePage real + fake atomic/jurnal injectat; CI separat |
| candidat create→receipt ack pierdut→recreare→reconcile | Chrome plugin secure-storage real + Auth/Firestore SDK emulator; 18 SDK totale pe 33ac5df, inclusiv 1 nouă X |
| UI VIII create/edit/close/receipt / A→B→A2 / cleanup / offline | controale SDK existente păstrate în suita IX; nu sunt remedieri noi X |
| manager/rate / bootstrap finance | refuz boundary; neintegrate; nu se inventează contract |
| expense OCR/manual/confirm / perDiems/v2 | căile legacy și testele anterioare păstrate; nu sunt convertite de candidate |
| Home implicit | KNOWN UNSAFE: set merge fără protocolul nou |
| reguli main vs candidat | martor risc, respectiv refuz; niciun verdict despre rules live |
| cross-device SDK | două FirebaseApp în browser, nu două telefoane; backend marker/revision testat |
| cross-tab / cross-process / restart hardware / iOS / Windows | UNKNOWN; exclusivitatea jurnalului nu este garantată |
| backup financiar complet | BLOCKED, V1 omite markerii și jurnalul local |

### Commituri noi ale misiunii

- 5420be2 — X-01 matrice Home și preflight.
- 33ac5df — X-02/03/04/09 compoziție și probe integrate; CI Finance IX
  38877619264 SUCCESS: 204 Dart, 51 JS emulator, 18 SDK + raw Timestamp PASS.
  Identity 38877619366 SUCCESS. Standard/Platforms erau încă în lucru la checkpoint.
- ebaf3cd — manifest recovery verificat la adoptare (inclusiv schimbare după
  preflight), manager/rate refuzate și două jurnale independente.
- e932e7c — matrice legacy extinsă 4→16 cazuri, fără modificarea rules.
- Commitul acestui handoff — raport, scenarii și patch propus; SHA/tree final și
  workflow IDs/conclusions se consemnează în descrierea PR78 după CI final.

Suitelor li se suprapun probele; NU se însumează drept teste unice. Cele 11 probe
candidate de boundary după continuare adaugă 3 la cele 204 Dart de mai sus.
JS emulator țintă după extindere: 63 (51+12). 199 Python locale și 3 Node PASS.
Nu numim aceste ținte PASS înainte de CI pe HEAD final.

### Pași rămași înainte de lansarea noii versiuni

1. Contract manager/rate/bootstrap și toți writerii finanțe, integrare Home cu
   mandate nominale pentru sursele înghețate; jurnal durabil + model autoritativ.
2. Exclusivitate ori CAS durabil cross-process, probe două taburi/OS/hardware și
   politică explicită pentru pending după transfer de echipă. Nu ștergem jurnalul.
3. Upgrade gate compatibil, ACL fără bypass legacy și rollout staged aprobat;
   păstrarea avansurilor, istoricului și markerilor în rollback.
4. Restore financiar complet cu inventar consistent, coordonare și recovery al
   eșecurilor parțiale; schema de istoric pentru documente care cresc.
5. Teste fizice Android/iOS/Windows/offline/restart, staging și buget real verificat.
6. Audit independent al integrării cu ramura Vision, fără a modifica PR75;
   aprobări distincte pentru merge/deploy/producție/distribuție.

Nicio operație în producție, migrare, backfill, deploy, merge sau distribuție APK
nu s-a executat. Android debug rămâne compile-only, fără instalare/publicare.
