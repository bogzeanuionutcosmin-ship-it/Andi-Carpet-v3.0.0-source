# MISIUNEA VIII — Issue #54 / #53 — DRAFT, DO NOT MERGE

## VIII-01 — bază, autorizație și inventar

Bază PR50 verificată: f809b494417af2e7fedea0178a96a8da7b13ede7,
tree6b555df1dcc3b2d36046e3c5f445069db03a2ffc; checkout curat.
Standard38698568154 SUCCESS5/5, identity38698568139 SUCCESS5,
finance38698568211 SUCCESS175execuții, platforme38698568183 SUCCESS
(604Flutter/177Python,168financeChrome,APKdebug real). Nu repetăm III–VII.

Mandatul nou al proprietarului și Issue54 autorizează acum cod financiar și rules
numai în ramură Draft/emulator. Interdicția anterioară de implementare din Issue53
este înlocuită în acest domeniu de instrucțiunea expresă actuală. Fără billing,
Blaze, Functions noi, migrare/date reale, deploy, merge sau publicare.
PR50/51/52 și cele patru loguri schedule protejate rămân read-only.
PR52 observat la950f736a4e2e32799db5c61ccd8388fe1acae70e, neintegrat.

| Writer | Comportament actual | Risc / constrângere |
|---|---|---|
| Home._saveSettlementDirect | set merge al întregului model | liste/totaluri/closed fără revizie; rezultat incert |
| Home._saveFinanceDirect | set merge, cache + Learning după write | suprascriere legacy; efectele nu sunt atomice |
| Home._saveExpenseDirect | codec fără distributedBy | create legitim respins; update excesiv permis în rules |
| perDiems | tranzacție existentă + receiptAudit | schemă distinctă; nu se rescrie pentru comoditate |
| per_diem_settlements_v2 | registru existent cu audit/revizie | nu se unifică cu noile intenții |
| Admin restore manual/automat | șterge și înlocuiește colecții | nu poate ocoli protocolul sau regresa reviziile |
| Home financial listeners | snapshots fără metadata de confirmare | nu reprezintă dovadă pentru intenția proprie |

## Alegere și cost Spark

Alegere etapizată C: marker imuabil per intenție + document financiar cu revizie,
scrise împreună în tranzacție; deduplicarea citește markerul stabil. B cu numai
lastOperationId economisește un write dar pierde dovada unei operații vechi după
operații ulterioare; o listă bounded permite reaplicarea după evacuare. C este
preferat pentru corectitudine; zero ștergere automată/TTL a markerilor.

Surse oficiale verificate15.10.2026:
https://firebase.google.com/docs/firestore/pricing
https://firebase.google.com/docs/firestore/manage-data/transactions
https://firebase.google.com/docs/firestore/security/rules-conditions
Free quota: o DB eligibilă,1GiB,50000read/zi,20000write/zi,20000delete/zi,
10GiB outbound/lună. TTL/PITR/managedbackup/restore/clone nu sunt în free quota.
Tranzacția poate relua callbackul; toate readurile preced writeurile, offline
nu confirmă tranzacția. Nu punem UI/audit side effects în callback.

Model conservator executabil `scripts/finance_spark_budget.py`: maximum3încercări,
2citiri client + pânăla20rules accesses pe încercare,2write la succes;
reconciliere explicită:1read marker + pânăla10rules accesses. Fără presupunere de
cache între reguli/încercări. Acestea sunt limite de model, NU factură măsurată
în emulator. Emulatorul nu măsoară billingul real. Queryuri noi:zero; index-query
reads noi:zero; listeners/polling/delete noi:zero.

| Intenții și verificări/zi | Reads/zi model | Writes/zi | Markeri după1an la2KiB |
|---|---|---|---|
|40 +40 (2echipe×20)|3080|80|29900800bytes|
|200 +200|15400|400|149504000bytes|
|1000 +1000|77000|2000|747520000bytes|

2KiB este ipoteză pentru marker mic+metadata+index, nu limită demonstrată a tuturor
payloadurilor. Contabilizarea stocării efective/indexurilor și egressului trebuie
validată înainte de release. Un buget intern de rezervă folosește maximum25000
reads/zi,10000writes/zi și256MiB total estimat, păstrând spațiu pentru aplicația
existentă. La1000intenții/zi costulread deja depășeșteSpark. Nu se declară universal
gratuit. Volumul live, planul live, DB eligibilă, stocarea/indexurile existente,
listeners/reconnect/egress și ceilalți utilizatori: **UNKNOWN**. Gate-ul static
refuză readiness dacă baseline e necunoscut; chiar un scenariu care încape nu
primește automat production_ready. Fără acces live sau activare automată.

7testePython noi de model cost;184Python localPASS. CI pe noulHEAD în așteptare.
Runtime/rules intacte înVIII01. UrmeazăVIII02 martoriRED noi și modeluloperației.

## Matrice de progres

VIII01 audit+modelcost pregătit;VIII02–14 NEFINALIZATE. Intențiile server, integrarea
UI și ACL rămân KNOWN UNSAFE în comportamentul moștenit până la probele viitoare.
Hardware/Firebase live/SDKcache real:NEEXECUTATE. UltimulSHA/tree/CI autoritativ și
comanda de reluare se actualizează în descrierea PR Draft după fiecare checkpoint.

## VIII-02 — noi acceptanțe ACL stricte, baseline RED cerut
Opt probe noi emulator:6acceptanțe de securitate încăRED (amount/confirmed,
managerId,reopen,Directorwrite,Adminbypass,expensecreate fărădistributedBy),2controale
pozitive (Adminreadlegacy,outsiderdeny). Nu importăm59probe istorice sau28testeVII.
Workflowul izolat cere exact6FAIL+2PASS în baseline, cu emulator demo, nu compileerror.
Acesta este detectorul vulnerabilității, nu remediereGREEN. Urmează verificareCI,
apoi modeluloperației. Rules/runtime încăbyte-identicePR50.


## VIII-03 — model Dart pur durabil și identitate
FinanceIntent folosește128biți Random.secure, bindingactor/team/target,baseRevision,request deepimmutable,serializareversionată+dateUTC șiSHA256canonic.14teste noi:roundtrip,imutabilitate,ordinea cheilor,intenții distincte,reutilizareIDcupayloadschimbat,ID100,NaN/Infinity,paths,diagnosticfărăpayload,version,sizefailclosed. Nu este încăexecutor sauUIintegrat. crypto3.0.7 dejaîncuiattransitiv este declaratdirect laaceeașiversiune; zeroSDK/serviciunou. Pinurile strictnecesarepubspec/lock actualizatecuold/new:
{'pubspec.yaml': ('a792bec431260e7ceb1ef3a1fa954c6f3e4d0039b04b5a7a3bf0745c08b2a441', '2bd8c7408160bf1ea72b5c5cbc55e2a45f00faaf87c3f43d0d8d33c314f1b835'), 'pubspec.lock': ('1fcaaee73e6372a2eb4b5952f528dcbe682f3b30f1f5998b282b96186283c913', 'c989d0f5793cc78bace3ad253bdb81e1732fa560126c352269700b38c2f0cc76')}
Restul114hashuri și toateassertionspăstrate; mandateIssue54permite dependenciesstrictnecesare, nuprivacy/routing changes. CIurmează peSHAexact.

## VIII-04 — port atomic și fake optimist concurent
Repository nou independent: citește marker, apoi document, verificărevizia și
aplicăsnapshotnou+marker în aceeași tranzacție; replayvalid este no-op. Conflictul
nu rebasează automat intenția. OriceeroareSDK rămâneuncertă; reconcileface numai
unreadserver explicit și respinge cache/pending/absența ca dovadă decommit.
Fake-ul are versiuni,CAS,reexecutaremax3 și commitatomic; NU esteFirestore real.
Probe:20copiiaceleiașiintenții,2intențiiconcurente,2sumelegitimeegale,timeoutînainte/
dupăcommit,restart,markerpayloadmismatch,revocareînainte/dupăwrite,istoriclegacy,
closed,Adminrevizienouă,edit/close/create. Agregatelelegacy fărăentries sunt
păstrate ca opening balances explicite, fărătransferuriinventate; istoricul
inconsistentfailclosed pentrureview. Noilecâmpuri nu sunt încălegate deUIcodec.
CI peSHAexacturmează; niciunclaimaplicațiesecurizată înainte deadapter/rules/UI.
