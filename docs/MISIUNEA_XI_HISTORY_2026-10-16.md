# Misiunea XI — append-only candidate / DRAFT ONLY

Issue #79. Bază PR78 reală 291b10ac74d1c0f58d3e44416cf2f48ef8dc347b,
tree d7cbee9e3af6dfe84b8ace251feeb8a9d4d5a77a, checkout curat.
CI bază: Standard38878283734/Identity38878283790/Finance38878283763/
Platforms38878283794 SUCCESS. Nu sunt rezultatele XI.
Ramură nouă fix/finance-history-legacy-safety-mission-xi-20261016.
PR75 observat read-only 48235b14fa7345c454882960aecb0ba66ba1b596;
PR78/75/73/74/main rămân nemodificate. production_ready=false.

## XI-01 — capacitate adversarială

Testele noi măsoară exact numărul octeților UTF8 ai canonicalFinanceJson pe
1000/7300/21900 receipts sintetice și payer ASCII vs Unicode. Dimensiunea după
formula Firestore existentă este etichetată separat: NU este dimensiune wire,
index sau factură măsurată. Două timestamps diferite cu o nanosecundă rămân
JSON distincte, dar au aceeași dimensiune de stocare Firestore (8 bytes/valoare).
Scenariul X 20 receipts/zi × 1KiB +4KiB reproduce 25 zile complete în rezerva
512KiB; ipoteza 1KiB nu înlocuiește măsurarea payloadurilor concrete.
Nu se trunchiază istoric și nu se modifică bani, Home sau vreun pin.

## XI-02 — contract V2 candidat, independent

Namespace demo financeHistoryXi/s_<settlementId> sau f_<teamId>. Summary mic:
protocol2/team/source/revision/totals/lastOperationId. receipts/<operationId>
este simultan rând append-only ȘI markerul imuabil de idempotency (digest V2,
actor, team, target, base/revision, payload). Două writes atomice, fără array,
fără colecție marker duplicată. Nu conectăm Home sau jurnalul V1 la V2.
Envelope protocol2 are digest separat de FinanceIntent V1; nu se importă pending
vechi. Factory SDK este exclusiv demo/loopback. Inițializarea refuză surse legacy
cu bani/istoric/revizie nenulă; bootstrap sintetic zero nu este migrare.

Model/port independente și probe fake: replay, intenții egale distincte,
concurență CAS, ack pierdut și reconcilere explicită, lipsă/conflict marker,
revocare monotonă și consistență completă pe pagini pinned. Sumarul nu este
certificat printr-o pagină parțială. Reordonarea sau diferențele de aritmetică
floating la suma inversă refuză dovada; nu rotunjim bani pentru un PASS.
Rules noi sunt exclusiv fixture emulator separată. Nicio regulă live sau
firestore.rules existent nu este modificat. Validarea CI urmează pe SHA nou.

## XI-03/04 — probe SDK candidate

JS SDK real: reguli standalone pe demo-history-xi și main SHA-pinned pe alt
proiect demo. Matrice pozitivă/negativă pentru două echipe, două instanțe, replay,
ID/digest diferit, două intenții egale, concurrent CAS, ack pierdut, read-only
Director, worker/outsider refuzați, admin fără bypass, rezumat/marker orphan,
ștergere/update receipt refuzate, revocare, query pinned și limită20.

Chrome entrypoint XI înregistrează integral IX (18 controale), apoi adaugă
3 probe genuine Dart Auth/Firestore pentru portul nou: timestamps nanosecunde,
replay cu contori, lost ACK + envelope recreat + reconciliere, două instanțe
SDK și signout→same UID re-login fără reactivarea repo vechi. NU două telefoane.
Fixture-ul XI este inserat în memorie numai în rules ale emulatorului demo;
catch-all Admin este exclus și pentru noul namespace. firestore.rules rămâne
nemodificat. Controalele vechi nu sunt omise sau relaxate. CI urmează pe SHA nou.

### Corecții ale fixture-urilor după primul CI
19884cd: 219 Dart PASS/1 FAIL în proba concurentă. Așteptarea conflict era prea
puternică după o încercare care programase deja write: protocolul păstrează
uncertain conservator. Proba cere acum exact un confirmed și un uncertain,
aceleași două writes și aceeași încasare200; conflictul cert înainte de write
rămâne probat separat. Nu este relaxare a unei respingeri certe în runtime.
Fixture-ul rules nu compila literalul exponențial; finiteMoney folosește acum
aceeași identitate n-n==0 ca regulile VIII, fără plafon monetar nou.
Rezultatele acestor corecții necesită CI nou; primul eșec nu este PASS.

## XI-05 — compatibilitate și poarta de versiune

Matricea nouă separă schema append-only de rooturile legacy. Cu rules main,
membrul nu poate citi namespace V2, dar APK vechi poate scrie în continuare
settlements; Admin catch-all poate altera markerul V2. Cu fixture XI standalone,
legacy writes și marker overwrite sunt refuzate chiar Adminului. Totalul V2
poate fi200 în timp ce cititorul vechi vede0 sau scrie25 în alt document: simpla
păstrare a schemei vechi NU este compatibilitate financiară transparentă.

Imposibilitate fără gate: vechiul set(merge:true) nu transmite operationId,
digest, baseRevision sau protocol. Nu putem distinge două intenții egale de
retransmiterea aceleiași tentative după ACK pierdut. A permite write fără acestea
elimină invarianta; a cere dovezile respinge vechiul client. Nu activăm niciun gate.
Propunere staged: inventar clienți și intenții pending → update/reconciliere
explicită → gate server pentru writeri vechi și contract source→protocol unic →
seed/migrare aprobată și validată separat → activare controlată. Un prompt UI
singur nu obligă un APK vechi să se oprească. Rollback păstrează dovezi și poate
opri operații noi; nu redeschide legacy writes peste ledger și nu șterge bani.
Fixture-ul Chrome combinat este numai test; V1 și V2 coexistente acolo NU sunt
un rollout sigur. Alegerea exclusivă a protocolului per source rămâne BLOCKED.

## XI-06 — readback nu este CAS

Witness nou pe FinanceCheckedJournalStorage real și două RMW independente:
A.read=null, B.read=null; A.write envelopeA + readback PASS; A commit server +
ACK pierdut; B.write envelopeB bazat pe snapshotul său vechi + readback PASS.
Jurnalul recuperat conține numaiB, deși markerulA este comis. Două write-uri,
zero delete. Testul modelează procese independente fără _queues comun; NU este
probă de plugin în două taburi, restart OS sau securitate fizică.

Web Locks analizat conceptual din specificația primară:
https://w3c.github.io/web-locks/ (consultată 2026-10-16).
Contract posibil: navigator.locks.request cu același nume de resursă pentru
întreaga operație read→validate→modify→write→readback, nu doar pentru setItem.
Coordonare cooperantă în același storage bucket; nu toate profilele, clienții
legacy, Android/iOS/Windows sau fsync. Fără steal sau timeout care ar autoriza
continuarea fără lock. API absent/revocat → fail-closed. Alternativă: store local
tranzacțional cu CAS pe revizie și rollback atomic al envelope-ului. Niciuna nu
este implementată/activată în aplicație; nu introducem dependențe noi. BLOCKED.

## XI-07 — snapshot/restore, fără scrieri financiare

HistoryXiSnapshotReview produce numai o dovadă locală pentru prefixul imuabil
1..N al UNEI surse: header autoritativ pinned, pagini descendente≤20, exact N
rânduri, digesturi/binding/totaluri verificate și checksum ordonat al exportului.
Memoria rămâne bounded; nu reține toate rândurile. Checksumul nu este semnătură
sau autorizare de restore. Rândul receipt este markerul: lipsa lui lasă gap;
orphan cu revizie/digest diferit otrăvește review-ul. Nu este inventar global.

Probe noi: export în pagini în timpul commituluiN+1 (prefixulN rămâne valid,
restore pe summary curent este refuzat), snapshot parțial/crash, orphan și
cache/pending. Zero writes din review. O eventuală restaurare operațională
ar trebui să compare headerul în aceeași tranzacție cu toate scrierile sale;
un matchesCurrent citit separat nu este lock. Nicio API de restore financiar
nu este livrată și nu se șterge jurnalul local pending. Import global pentru
surse multiple și alte subcolecții rămâne BLOCKED fără inventar/strategie aprobată.

## XI-08 — interfețe neacoperite, contract separat obligatoriu

| Writer | Interfață propusă, NEIMPLEMENTATĂ | Autoritate / blocaj |
| --- | --- | --- |
| manager | proposeManagerChange(target, expectedRevision, nextManager, scope) | actor administrativ desemnare; sursa canonică, membership și precondiție de echipă trebuie revizuite; nu este receipt |
| rate | proposePerDiemRateChange(target, expectedRevision, rate, scope) | regula existentă de editare trebuie transpusă server; zero recalcul istoric implicit |
| bootstrap finance | createEmptyFinance(team, serverAbsenceProof, scope) | numai document absent, actor permis, fără sold inventat; V2 demo cere sursă zero existentă |
| OCR/manual | proposeExpenseDraft(expenseId, expectedRevision, author, scope) | confirmed=false, autor/team reale, confirmare gestionar separată; amount confirmat nu devine overwrite |
| confirm expense | confirmExpense(expenseId, expectedRevision, scope) | gestionar/admin server, audit și conflict; nu același drept ca viewOwnDecont |
| perDiems distribution | proposeDistribution(stableId, beneficiary, declaredAmount, scope) | avans permis, create-if-absent și identitate durabilă, fără plafon nou |
| perDiems receipt/refusal | acknowledgeDistribution(id, expectedRevision, actual, scope) | numai beneficiar; păstrează declaratul și auditul existent |
| per_diem_settlements_v2 | API existent cu revizie/audit | schemă separată; niciun adaptor automat către historyXi |

Aceste semnături sunt propuneri de review, nu porturi care oferă drepturi noi.
HistoryXiIntent acceptă exclusiv receipt; celelalte acțiuni nu pot fi convertite
prin schimbarea kind-ului sau prin amestecarea câmpurilor. Home congelat mută
manager/rate înainte de callback și nu are rollback complet pentru acestea;
refuzul noului receipt port NU certifică acel UI. Martorii X existenți nu sunt
numărați din nou. Patchul Home X rămâne neaplicat; activarea necesită contractul
fiecărui writer și mandat pentru sursele freeze. BLOCKED integrarea implicită.

## XI-09 — audit read-only Vision

HEAD PR75 citit 48235b14fa7345c454882960aecb0ba66ba1b596, fără checkout/
cherry-pick/merge. Public: VisionScopedSignalSink.emit(VisionDiagnosticSignal,
platform:VisionSignalPlatform); catalogue financeOperationUncertain și
financeRevisionConflict, fără argument pentru UID/sume/digest/payload. Scope:
VisionAuthenticatedSessionScope(sessionEpochKey, sessionIsCurrent, builder),
VisionSessionLifecycleCoordinator.replaceSession/clear/dispose; UID-only nu este
suficient. Aceste simboluri suplimentare NU sunt în baza X și NU sunt importate.

Port local independent observeHistoryXiResult: numai enum anonim uncertain/
conflict; nu transmite result.code arbitrar, nu inventează permissionRejected,
nu emite succes, nu atinge storage/SDK. Returnează identic obiectul rezultatului
inclusiv dacă sinkul aruncă. Probe noi pe commit+ACK pierdut cer status uncertain,
exact1apel/2writes, fără resubmit și fără conversie în confirmed. Mappingul către
catalogul PR75 este doar propus în docs, nu conectat la singletonul Vision.

### Măsurări concrete și corecția batch fixture

Primul capacity test a măsurat exact UTF8 JSON ASCII/Unicode și formula storage:
1000:213037/277037/261093 bytes; 7300:1554937/2022137/1905393;
21900:4664737/6066337/5715993. Nu sunt wire bytes/index/billing.
Probă SDK suplimentară: serializare JSON exactă a snapshotului Unicode1000,
precizie timestamp observată și refuz server pentru document UTF8 >1MiB.

306b89b emulator:71PASS/5FAIL; cele cinci batchuri negative foloseau referințe
de document din instanțe Firestore diferite. Fixture corectat pentru aceeași
instanță per batch. Asserțiile refuzului, integritatea și drepturile rămân
neschimbate; aceste FAIL nu sunt prezentate ca vulnerabilități server remediate.

### Compoziție rules în fixture SDK

Fixture-ul Chrome combinat a eșuat înainte de pornirea probelor. Cauza: textul
regex din rules conține secvența dollar+apostrof, interpretată de String.replace
ca substituție a sufixului și multiplicând codul sursă. Inserția folosește acum
callback de replacement, păstrând fragmentul literal exact o singură dată.
Verificare locală de lungime compoziție; rules de pe disc/producție nemodificate.
Nu eliminăm controale pentru a masca acest eșec de infrastructură de test.

### Divergență timestamp reală observată și reprezentare V2 exactă

05a49f7: SDK a măsurat268010bytes JSON pentru1000rânduri Unicode; timestampul
nativ123456789ns s-a citit123456000ns. Numărul bytes nu dovedește egalitatea
valorilor. Firestore a refuzat documentul supradimensionat cu invalid-argument,
mesajul exact «property payload is longer than1048487bytes»; predicatele probei
sunt corectate pe codul/mesajul real, fără acceptarea unei scrieri mari.

Candidatul V2 normalizează DateTime în secunde+nanosecunde și stochează data
receipt ca hartă de DOI întregi, nu Timestamp nativ. Rules verifică intervalele;
digestul/replay/reconcile și auditul folosesc exact această reprezentare. Nicio
schimbare în codec-ul V1 sau istoricul existent. Noua probă Dart SDK cere
123456789 exact în hartă și confirmare după ACK pierdut, nu acceptă uncertain
în locul controlului pozitiv. Nu se pretinde că SDK păstrează Timestamp nativ.

### Owner expirat după replay și limita aritmeticii de audit

Revocarea după întoarcerea tranzacției de replay produce uncertain, niciodată
rejectedBeforeWrite pentru banii deja comiși. Refuzul inițial înainte de apel
rămâne separat. Martor nou: replay fără writes, owner revocat înainte de return,
exact2apeluri/2writes totale, suma200 păstrată.

Auditul invers poate refuza legitimul0.1+0.2+0.3 deoarece double addition nu este
asociativă. Probă strictă: refuz proof, zero rotunjire, zero modificare a totalului
server. Acesta este un BLOCKER pentru certificarea universală a snapshotului;
o reprezentare monetară exactă/ordine de audit necesită contract revizuit înainte
de activare. Nu impunem tacit două zecimale sau bani întregi peste datele existente.

## XI-10 — handoff și status pe fiecare lot

PR Draft80. production_ready=false. Propunerea de integrare/rollout este în
MISIUNEA_XI_ROLLOUT_PROPOSAL_2026-10-16.md, NEAPLICATĂ. PR75/78/73/74/main
și toate116surse/21pini se verifică distinct; nu schimbăm pini pentru CI.

| Lot | Progres real | Limită rămasă |
| --- | --- | --- |
| XI-01 | JSON UTF8 exact ASCII/Unicode1000/7300/21900; măsurare snapshot SDK și refuz document mare; sumar V2 constant după formula storage | formula storage nu este wire/index/billing |
| XI-02 | model/port receipt V2 independent, sumar mic + receipt/marker imuabil | neactivat; fără migrare sau jurnal V2 de producție |
| XI-03 | fixture rules + SDK JS și Dart autentice, replay/CAS/ack/roles/timestamps | rezultatele exacte se citesc din CI pe HEAD final în PR80 |
| XI-04 | consistență pinned paginată și completitudine fail-closed | audit reverse double poate refuza legitim; contract exact necesar |
| XI-05 | matrice namespaceV2 vs client vechi/main/fixture strict, dovadă incompatibilitate și gate propus | fără gate server sau upgrade live |
| XI-06 | intercalare deterministă pe checked storage real, pierdere intent după două readbacks reușite | MODEL procese independente; Web Locks conceptual; BLOCKED cross-tab/OS |
| XI-07 | prefix snapshot review bounded, checksum, partial/crash/orphan/concurrent N+1 | nu este inventar global sau API financiar restore |
| XI-08 | contracte writeri separate + porți de autorizare | manager/rate/bootstrap/OCR/perDiems nu sunt convertite |
| XI-09 | audit PR75 read-only și observer anonim local fără I/O/retry/conversie rezultat | fără integrare între ramuri |
| XI-10 | filtre XI păstrând toate controalele, documente/ChatGpt și raport PR | final CI exact obligatoriu; hardware/live UNKNOWN |

### Costul candidatului, separat de V1

Receiptul servește și ca marker:2writes/append,0writes/replay/reconcile. Clientul
citește receipt+summary (2reads) și sursa legacy numai la bootstrap (încă1read).
SDK max3attempts: upper model normal66document+rules reads, bootstrap69, fără
cache presupus în Security Rules. Reconciliere explicită:2serverreads + pânăla20
rules accesses. Nu sunt factură măsurată sau cota live. Prefix audit citeșteN
receipts în pagini≤20 și headerul; nu devine gratuit doar fiind paginat.

La20receipts/zi:600/3600/7300rânduri la30/180/365zile, fără ștergere/TTL; summary
nu conține array și dimensiunea sa după formula Firestore rămâne constantă pentru
aceleași bindings. Cost bytes/receipt depinde de payload/indexuri; măsurarea SDK
JSON a unui array de1000nu este estimare de indexuri V2. Planul, baseline existent,
indexuri, acces rules efectiv și egress live rămân UNKNOWN. Nu există polling,
listener sau serviciu nou în candidat. Constructorii/observerul nu produc I/O.

### Matrice de dovezi și blocaje pentru lansare

- SDK real emulator: autorizare JS, atomic summary+receipt, readback, bounded queries;
  Dart Chrome port autentificat și exact date integers. Rezultatele finale în PR80.
- Fake/model: snapshot proof, intercalare cross-process, metadata stale/cached,
  owner callbacks, crash recreare obiecte. Nu sunt certificate de două telefoane.
- KNOWN UNSAFE/BLOCKED: Home implicit și writerii neacoperiți, gate V1/V2, migrare
  sumelor/istoricului vechi, jurnal V2 fizic cu CAS/lock cross-process, restaurare
  financiară completă multi-source, audit exact pentru double neasociativ.
- UNKNOWN: Android/iOS/Windows storage/restart OS/power loss, taburi reale și
  hardware, plan/billing/quota/index/egress live. Android build este compile-only.
- Vision PR75 nu este integrat, ci auditat pe SHA explicit. Datele financiare nu
  devin telemetrie; un eveniment uncertain nu este confirmare de bani.

Nu închidem issues32/53/54/72/77/79. Fărămerge/deploy/ruleslive/config/date,
migrare/backfill,restorelive,billingnou,Functionsnoi,APKinstalat/publicat.

Lista completă de commituri, SHA/tree final, cele4workflowuri active și numerele
PASS reale sunt consemnate în descrierea PR80 după verificarea ultimului HEAD;
nu se reutilizează verdele bazei sau al unui commit anterior drept rezultat final.

### Checkpoint executat pe codul final candidat 880b9e6

Finance IX38889899336 SUCCESS3/3:230Dart,77JSemulator,21FlutterSDKreale și raw
TimestampcontrolV1 PASS. Cele3probe noi SDKXI au trecut inclusiv payload date
exact și ACKpierdut→same-intent reconcile; douăSDKinstances=un singur receipt.
Model V2 măsurat prin formula storage: summary277bytes atât la început cât și
la21900receipts, receipt sinteticUnicode608bytes (fără indexuri/billing).
600/3600/7300receipts la30/180/365zile în acest exemplu reprezintă364800/
2188800/4438400bytes receipts +277summary înainte de indexuri/metadata/egress.
Nu extrapolăm 608bytes ca maxim universal al tuturor payloadurilor.

Acest checkpoint nu substituie CI al commitului final de documentație. Final
HEAD/tree/workflowuri și concluzii sunt în PR80 după verificare, fără auto-merge.
