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

Stare istorică la VIII01: audit+modelcost pregătit, VIII02–14 nefinalizate.
Pentru starea actuală folosiți matricea VIII14 de la final și checkpointul PR55.
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


### VIII-05 — emulator-only Firestore adapter (2026-10-15)
Injects an explicit FirebaseFirestore, requires a demo-* project and loopback emulator endpoint before configuration. Uses runTransaction(maxAttempts:3, timeout:30s), marker-first reads before writes, recursive Timestamp conversion, serverTimestamp for target.updatedAt / marker.createdAt, and explicit Source.server reconciliation preserving metadata. No listeners, polling, application retry, default Firebase app or production activation. Nine synthetic adapter/codec tests complement the 14 identity and 24 atomic repository tests; actual SDK/emulator end-to-end remains a separate acceptance requirement. This is a staged, unwired protocol; existing app writers and six ACL RED findings remain unchanged.
Sources: https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/FirebaseFirestore-class.html and GetOptions/SnapshotMetadata (verified 2026-10-15).


### VIII-06 — bounded private durable journal and local duplicate guard
New injected journal persists the exact immutable request before use, separates owner UID keys, serializes multiple instances in this process, refuses changed payload on reused ID, and blocks a new ID for an unresolved target. Uncertain/conflict evidence is retained; confirmed/certain prewrite rejection may release the local target, while immutable server markers remain authoritative. Bounds:32 unresolved intents /128KiB, fail closed on corruption/full/storage error, no eviction/background replay. Existing flutter_secure_storage adapter added without dependency change. Thirteen synthetic tests cover restart,20duplicate prepares,concurrent new IDs,equal legitimate successive receipts,A→B→A2,corruption,capacity and storage errors. Physical secure-storage durability, cross-process coordination and UI/coordinator wiring remain NOT ACCEPTED; this process mutex is not a distributed lock.


### VIII-07 — explicit durable execution and uncertainty coordinator
The new coordinator awaits durable preparation before any transaction, retains unresolved/conflicting intents, blocks a fresh ID on the same unresolved target, and offers explicit same-request execution or read-only reconciliation. Journal reconstruction never sends money. Server-confirmed status is preserved if local cleanup fails; journalPending reports cleanup separately. Nine deterministic tests cover persist-before-send,storage failure,lost ack/restart,new-ID denial,same-ID replay,absent marker,A→B→A2 late commit,cleanup failure and owner mismatch. Scope generation must come from the AuthGate owner; existing UI is not wired. Receipt/edit/create/close pure transitions exist, but full app codec/history/Restore acceptance is still pending.
VIII-05 CI found only a fixture signature mismatch (sslEnabled on pinned cloud_firestore6.10); ac0ab58 corrects that fixture without weakening assertions. Further CI pending.


### VIII-08 — staged financial ACL and immutable atomic marker rules
Authorised emulator-only rules now require revision+fresh immutable marker+target in one atomic commit, manager/Admin authorisation, exact receipt append and aggregate deltas, preserved openings, finite amounts and whitelisted edit/create/close fields. Director (role/function/functionIds) remains read-only, developer is never elevated. Worker expense creation uses createdBy (no erroneous distributedBy requirement); amount/confirmation updates require manager/Admin and immutable team/settlement/creator. Historical supplementary linkage condition retained. Crucial: Admin catch-all excluded for finance/settlements/expenses, otherwise overlapping OR grants would bypass all new restrictions. No client may delete financial targets/markers or regress revisions; Admin Restore must be redesigned before integration. Existing legacy UI writers are intentionally NOT compatible with these staged rules; deploying either independently is forbidden. New immutable markers contain identity/digest/revision, no duplicated money/OCR/private payload. Existing rules elsewhere and all 115 other protected hashes preserved. Rules pin explicitly updated by Issue54 mandate: 589fe5eadc06cae665eaa27e9c9df0aea54eea6dffc10994438b4d97c58367da -> 0fd4bf3c1ff5c9d094a28ea03d270d61f5639a032bad22c54d76776943ced23e. Strict eight baseline assertions kept; CI no longer accepts six failures on repaired rules. Emulator protocol tests follow.


### VIII-09 — actual Firestore emulator atomic/security acceptance suite
Added synthetic JS SDK transactions (maxAttempts3), not only a fake: both legacy finance and settlements; identical-ID replay/20concurrent copies; two devices conflicting revisions; equal legitimate receipts; simulated lost acknowledgement AFTER real emulator commit; malformed/partial writes; unauthorized worker/Director/multifunctionDirector/developer/outsider/inactive; history/opening/delta/manager tampering; nonfinite/negative money; closed settlement; valid edit/close/create; Admin Restore overwrite/delete/marker mutation denial; positive manager/Admin writes; legitimate worker expense and manager confirmation; cross-team/creator forgery and revoked identity. Runs serial file processes to avoid fixture reset races. Real offline transport/SDK cache/A→B→A2 on hardware remains NOT EXECUTED. CI assertions must all PASS; no expected-failure wrapper after ACL repair.


### VIII-10 — legacy aggregate compatibility and Restore boundary
TravelSettlement/TeamFinance now preserve explicit opening balances alongside itemised receipts; absent opening fields retain old getters exactly. Codecs retain opening balances,revision andlastOperationId for protocol documents, while legacy maps keep the previous shape. Eight positive/negative model cases and two real Home codec widget cases cover both collections; no synthetic transfer is created. Admin Restore conflict is secured on the new rules by refusing target deletion/replacement/revision regression and marker mutation, including Admin catch-all. Full manual/automatic Restore is NOT accepted: existing multi-batch workflow can partially restore other collections before financial refusal and does not export marker subcollections. A preflight/manifest-preserving Restore redesign and end-to-end client wiring remain release blockers; no claim that the existing Restore UI is repaired.


Continuation checkpoint 2026-10-15: ab518dd predicate ordering alone remainedRED. 5e1819d caches financial predicates, preserves explicit effectivePermissions and legacy fallback, and permits view-own reads of an absent settlement for real transactional creation. MissionVIII38740966147 SUCCESS:69DartPASS and44emulatorPASS/0FAIL; previous two concurrency failures plus new stale-envelope/fallback/create controls now PASS, with zero1000-expression errors in the job log. These are JS SDK emulator acceptances, not full Flutter SDK network acceptance. StandardCI/identity still awaited at this checkpoint. Local draft10 history/model/codec is now published separately; UI and full Restore remain blocked as described.


### VIII-11 — delayed reads, offline and session generation
Six new deterministic cases cover delayed marker proof after A→B→A2 (sameUID), revocation during marker/target reads, offline failure/reconnect without automatic financial retry, marker identity mismatch and revocation before an SDK contention callback. Added ownership checks immediately after each transaction read, so a stale marker completion does not even start the target read. Source journals remain scoped to the original UID/generation; no stale completion confirms a successor. Fixture gates are synthetic and explicitly do not certify real mobile transport/cache/restart. Device secure-storage and FlutterSDK+emulator offline tests remain required before client integration.


### VIII-12 — privacy compatibility and more complete Spark storage scenario
Read-only auditor against Shiva#52 950f736a: exactly2 shared paths (ChatGpt,vision_hardening_freeze),21 source pins verified per branch,116 protected catalog entries verified, both checkpoint prefixes preserved. Future union retains2finance+3privacy source pins plus explicit pubspec dependency pin. No merge/source import/privacy rewrite;4protected Routing/Learning log sites remain KNOWN UNSAFE. Existing VII auditor is unchanged; VIII has its own exact-delta policy. JSON report records the exact audited source commit.
Cost model now includes assumed receipt-history growth, not just markers. Conservative scenario:each operation appends1KiB history plus2KiB marker (both assumptions including indexes, not measured upper bounds).40ops+40checks/day:3080reads,80writes,44,851,200total additional bytes/year (29,900,800marker+14,950,400history).200/day:15400reads,400writes,224,256,000bytes/year.1000/day:77000reads,2000writes,1,121,280,000bytes/year, unsuitable.3new Python tests reject marker-only false fits and negative assumptions.187Python localPASS. Existing usage/indexes/egress unknown;1MiB single-document history capacity and long-term retention unverified; no TTL/cleanup/billing/newlistener/polling. production_ready ALWAYS false. Do not infer production readiness from emulator quota-free execution or a one-year hypothetical fit.
Unchanged legacy perDiems over-declared receipt characterization remains explicitly unsafe/decision-dependent; no new approved financial truth rule is invented. Legacy UI uncertain-state detectors and full Restore remain unresolved despite candidate protocol acceptance.


### VIII-13 — final platform regression workflow
New branch-isolated read-only CI runs AuthGate/Vision, all financial unit/widget cases plus strict repaired .red.dart witnesses, all finance Chrome probes under no_default_http_client, and actual lib/main.dart Android debug compilation with package/SDK metadata verification. No APK upload,installation,signing change or deployment. StandardCI separately runs allFlutter/Python,Functions/Node,legacy emulator and web compilation. MissionVIII emulator44 uses synthetic JS SDK+realrules; Android build alone does NOT execute new financial SDK transactions, physical secure storage,realofflineor live GPS/FCM/MLKit. Candidate protocol remains unwired to production UI. Results pending exact HEAD; skipped historical VII workflows are not counted as new PASS.


## VIII-14 — checkpoint de continuitate, 15.10.2026

PR55 Draft, ramură fix/finance-spark-safe-mission-viii-20261015.
Părinte înaintea acestui checkpoint: e2ad85a8a71a7d5fc4d7e2c728fb80a1b2f97c8e; tree c6a5ecc2e4aebcd614a1ae96ad120417a50125dc.
HEAD/tree și CI ale commitului care conține acest checkpoint se citesc din PR55
și se verifică prin git rev-parse HEAD HEAD^{tree}; nu se autocertifică un SHA viitor.

| Lot | Stare și limite |
|---|---|
|1| Audit writers și model Spark; baseline live/egress/capacitate UNKNOWN, fără readiness |
|2|6defecte ACL reproduse RED; aceleași acceptanțe ulterior PASS |
|3|ID128biți,requestimmutable,persistențăversionată,digest;tagdate protejat,encodingnumeric VM/Chrome |
|4|PortCAS și concurență deterministă,zero retry financiar automat |
|5|Adaptor explicitdemo/emulator;max3callbackSDK;FlutterSDKnetwork E2E încă neexecutat |
|6|Markerimutabil atomic + jurnalbounded;20copiiaceluiașiID aplică o dată în emulator |
|7|Create/edit/close/receipt testate în candidat;UI existent încă neconectat |
|8|6probleme ACL reparateînregulileDraft;Issue32 integral NU închis |
|9|44/44emulatorPASS pe5e1819d,zero1000-expression errors;asertările păstrate |
|10|Openingbalances și codec-uri cu teste;Restoremultibatch/exportmarkeri NEFINALIZAT |
|11|Epochguarddupăread,6probeîntârziere/offline;hardware/cache/restartreal NEEXECUTAT |
|12|Auditread-onlyShiva21pinuri/branch+116catalog,bugetcuistoric;4privacyriscuriKNOWNUNSAFE |
|13|Workflow nouAuth/Vision+financeVM/Chrome+APKmain compileonly;rezultate finale se verifică înPR |
|14|Checkpoint și matrice actualizate; misiunea NU este declarată închisă integral |

### Progres demonstrat și ce NU este reparat în aplicația existentă

Noul protocol are44acceptanțeJS SDK emulator,iar modelul/repository/jurnalul/
coordonatorul au probeDart. Noile solduri inițiale sunt citite de codec-urileHome.
Vechile callbackuriHome/ExpensePage folosesc în continuare scrieri de snapshot.
Nu activați aceste reguli în producție cu acei clienți: vor refuza writes fărămarker.
Cele28detectoareVII de timeout/duplicare/Restore ale vechiului UI rămân caracterizări
KNOWNUNSAFE. Nu le redenumim în reparații pentru că noul repository trece separat.

Restanțe tehnice: conectareUI și toatewritepaths pe protocol într-un harnessdemonstrabil
emulator-only,probeFlutterSDKnetwork de tranzacții și reconciliere,AuthGateepoch real
pentru noulcoordonator,confirmareprivatestorage peplatforme,Restorepreflight înainte
deoricebatch și export/import care păstreazămarkeri/revizii. Nu începeți restaurare
parțială și nu ștergeți dovezi pentru a ocoli regulile. Acestea sunt lucrări rămase,
nu cereri noi de autorizare: mandatul tehnic Draft/emulator este deja acordat.

RegulilefinancialeLegacyperDiem privind încasări peste suma declarată rămân o
caracterizare de risc/decizie funcțională; nu se plafonează/rotunjesc bani automat.
Problemele de date/capacitate trebuie refuzate sau marcatepentru review, nu reparate
prin inventarea de transferuri/reconciliere automată.

### Cost și retenție

40operații+40verificăriexplicite/zi,max3callback:3080reads,80writes,44,851,200bytes/an
în scenariul2KiBmarker+1KiBistoric/op.200/zi:15400reads,400writes,224,256,000bytes/an.
1000/zi:77000reads,2000writes,1,121,280,000bytes/an — scenariu nepotrivit.
Acestea sunt ipoteze, nu măsurarefacturare saugaranțiehardware. Indexurile/egress/
baseline live/capacitatea1MiBdocument/mai mulțiani nu sunt demonstrate. Retenția
markerilor este durabilă, fărăTTL/cleanup/polling/listener nou. Gateproduction_ready
rămâne false chiar dacă rezerva numerică încape. Fărăbilling/Blaze/Functions noi.

### Probe și CI

187PythonlocalPASS. Pe5e1819d MissionVIII38740966147:69Dart și44emulatorPASS;
pe1d71279 lot10 dedicatedPASS;lot11 ccec788 dedicatedDartPASS. După hardeningul
encodingului sunt87probeDart noi față dePR50 (suprapuse cu suitaFlutter integrală),
numărul final și toate workflowurile trebuie confirmate din logurile HEAD final.
Suita standard urmărește691Flutter/187Python/3Node/10emulator,Identity5;aceste
totaluri sunt ținte de verificat, nu rezultate inventate. CI actual pee2ad85a:MissionVIII
șiIdentitySUCCESS;standard/platforme înprogres la pregătirea checkpointului.
WorkflowurileVIIistorice rămân SKIPPED, nu PASS. Buildweb standard produce artifactul
CI existent; workflowul Android nou nu încarcăAPK. Niciun deploy/instalare/publicare.

### Commituri publicate înaintea acestui checkpoint

```text
49edcb15a953391e8f9f8e537edf670b9acfc2e7 docs(finance): audit Mission VIII writers and model Spark quota reserve
d3a8f41cf6db1ed7809219a50a6fba7cdf4cc789 test(finance): add strict Mission VIII ACL RED witnesses and positive controls
f2e79355e44d5fd10bcfe0ab9ea842e56f19b35d feat(finance): add immutable durable intent identity and canonical request digest
140179c9c55d27dd62879167a740cd3bd08febd3 feat(finance): add atomic intent port and deterministic concurrency and ambiguity probes
82d9a7100061b293b52bb72ded4e092b6b807d30 feat(finance): add explicitly emulator-only Firestore atomic adapter
ac0ab58fe70525aba8adcc669b5175d246707e45 test(finance): match pinned Firestore emulator API in injected SDK fixture
3ac70bcd16fa50f74f1a6efb53a428c0b83fc0c4 feat(finance): retain bounded per-owner durable intents and block unresolved local duplicates
9930acb0e1062b9134ae8e5f3a7153ddcf64631b feat(finance): coordinate durable explicit submission and read-only uncertain-result checks
497291888e97d53b095075de55ad90a34b9d2a61 fix(firestore): stage atomic financial evidence and manager ACL without Admin catch-all bypass
231059e1130d2d04c4d4441595fd5eaeb4a02609 test(firestore): verify real atomic receipts, concurrency, evidence and Restore authorization
a72223846f668f734eb5f5bced9c91833d97a0fe fix(firestore): reduce financial rules evaluation and verify SDK contention uncertainty without retry
ab518dd2796e492303681d26ebb2ab3f18a0daec fix(firestore): reject stale financial revisions before expanding costly rule predicates
5e1819d24c4cc157767ad5a4b13204acfc900001 fix(firestore): cache financial access predicates and allow transactional reads before creation
1d71279282b23cec903968cbac9dd42a3ae76596 fix(finance): preserve legacy opening balances and revision metadata in models and Home codecs
ccec7880edb520e93c3e121fda5f038c0e0f7f18 fix(finance): stop stale session reads and cover offline and delayed server evidence
0aa2803e105a8717f899c1f8ffa376ca0d536663 audit(finance): preserve Shiva pin compatibility and account for receipt history storage growth
f308283de644050d1acf7b6aff7b03620ca8e468 ci(finance): require Mission VIII AuthGate Vision Chrome and integrated Android regressions
e2ad85a8a71a7d5fc4d7e2c728fb80a1b2f97c8e fix(finance): make durable numeric encoding portable and reject date-tag aliasing
```

### Comanda de reluare

«Continuă MISIUNEA VIII în PR55 din HEAD-ul real. Citește ChatGpt, matriceaVIII14 și
descriereaPR55 cu HEAD/tree/CIfinal. Păstrează oricecommit nou și oricefișierlocal.
Nu reface probele/fixurilevalidate. Mai întâi repară oriceCIRED fără relaxare, apoi
continuă integrarea UI/FlutterSDK-emulator,Restorepreflight și capabilitateaSpark
pe scenarii documentate. PR50/51/52 read-only;zero merge/deploy/live/billing.»


### VIII-10 follow-up — real annual report regression repaired
29b855b / MissionVIII38742920846 job116448984266 reproduced exactly2RED (protocol openings in settlement annual and team all-time) with89PASS, including both legacy controls. Same4dialog tests retained. The correction adds opening balances in original settlement-start period and undated team openings only inallTime, preserving existing financial attribution. The existing undated-warning condition also includes new opening fields.
Explicit freeze pin for expense_settlement_actions:0348242c2def81ac693ded3e3a64c96b9df701fff2b0895f4e6e2b1b09bc92b8 ->2cf1a4471d6c5fc41458201d3794a919ee318be74b8bf56208e484d121a00db9. All20otherfreezeentries and116protectedmanifestentries preserved. Historical stale-close/Vision inversion assertions keep their original expected hashes: a new exact-delta helper removes only2opening additions+warning delta and verifies the full0348242 previous runtime before the old inversions run.187PythonPASS; no guard is disabled or accepted via new arbitrary expectedhashes. Final targetedDart count91/overallFlutter695 are verification targets, pendingCI.


### VIII-09/11/13 follow-up — actual Flutter SDK emulator acceptance
New isolated CI job starts Auth+Firestore locally for demo-andi-carpet, seeds only synthetic users/data, and explicitly invokes5FlutterChromeSDK scenarios. It uses the real FirestoreFinanceAtomicPort/repository, not the JS reimplementation: receipt/replay/edit/close,synthetic acknowledgement loss AFTER real commit followed by Source.server reconciliation,independent app clients racing,actual Auth emulator A→B→A2 with a delayed evidence callback and unauthorizedB write,plus view-own transaction creation. No automatic financial retry is added; SDK uncertainty remains acceptable only alongside exact server-state assertions. Cache persistence is disabled for these server-evidence cases; they do not certify real offline transport,physicalsecurestorage or fullUI/AuthGate wiring. New emulator config is separate; protected production/testconfigs unchanged. Seed requires both loopback emulator environment variables and never prints token/UID/password. Pending actual CI, not yet claimed PASS.
Official sources checked: https://firebase.google.com/docs/emulator-suite/connect_auth and https://pub.dev/documentation/firebase_auth/latest/firebase_auth/FirebaseAuth-class.html . Existing FirebaseAuth/Firestore SDKs only; no new dependency/cloud service/billing/project.


Follow-up numeric/profile guard: candidate refuses a positive receipt that cannot increase its selected floating-point aggregate (1e20+1==1e20), before client write and independently inRules; no rounding/cap/retry.1newDart+1emulator test requireunchangedhistory.2additionalRules controls cover effectivePermissions withoutlegacyfunction and nullablefunctionIds, with legacy/director checks preserved. SeeMISIUNEA_VIII_PRECISION_GUARD_2026-10-15.md forpin. Local187PythonPASS. Source58ac66d standardSUCCESS695Flutter/187Python anddedicated91Dart/44emulator;Chrome financepassed,Android/newFlutterSDKnetworkjob stillrunning before nextCI. Finalfollow-up requiresitsownCI; no priorpass inheritedasfinal.


Real Flutter SDK follow-up: fce0138/run38746250738/job116460560370 reached allscenarios withrealAuth/Firestore aftergenuinepluginregistration;4PASS/1FAIL strictlyfound callbackFinanceRefusal wrappedasgenericSDKerror. Adapterpreserves typedlocalrefusal/conflict onlywhenZEROwriteswerescheduled acrossALLcallbackattempts. AnySDKerrorwithoutthatproof,oranypriorattemptwrite,remainsuncertain. Fiveboundarytestsretainstrictrealclosed-receiptassertion. Coordinatoralso distinguishes freshjournalpreparefromexistingpending: localprewriterejection onmanualresume cannot erase anearlieruncertainattempt;newregressionretainsitsdurableintent. No automaticretry,rollback,rebase,roundingorSDKerror=no-writeassumption.98Dart/702Flutterarefinalverificationtargets;5realSDKcasesremainmandatory. Allsources savedinPR55;standaloneUI/Restore/Sparkproductionreadinessstillunfinished.


## Checkpoint consolidat — SDK real verificat, 15.10.2026

Cod verificat: bc60448e14044f047276680f678c19acd4cb4538; tree d1e22440d4db1588adcd02a25609cab2e4559a82. Commitul care adaugă această notă
modifică numai documentația/raportul audit; HEAD/tree/CI final se citesc din PR55.

MissionVIII38747592786 SUCCESS3/3:98DartPASS (job116465221691),47JSemulatorPASS
(job116465221637),5FlutterSDKChrome+Auth/Firestore emulatorPASS (job116465221925).
Logulreal:14:02:30UTC +5Alltestspassed. Aceleași5asertăristricte,nu mocksdeSDK:
receipt/replay/edit/close,ackpierdutdupăcommit,reconcilefărăwrite,2instanțeconcurente,
AuthA→B→A2/actorBneautorizat/epochvechi,crearecuviewOwn. Primaîncercare58ac66d a
rămasînsetup;98bbe35 a localizatinitialize_primaryTimeout;fce0138 a înregistratSDKweb
realși a găsit4PASS/1FAIL larefuzlocalîmpachetat;bc60448 reparăexactaceagranițăfără
aacceptaoriceSDKerrorcanowrite.5noiprobecuSDKwrapping+1manualresume păstrează incert
oricerezultatalunuiintentdejaîn așteptare,chiardacăapelulactualerefuzatlocal.

ProbeleJavaScript47 includ6martoriACLreparați,concurență/replay/Restoredenial,creare
viewOwn,fallback/autorizareprofilecompatibile și refuzulîncăsăriiinvizibileînprecizia
double. Ultimulpinrules4b744fd1ce9826041513e680affbdbdc2713deb9d87e1cf5677ea1bfc50833e7.
187PythonlocalPASS,inclusiv116catalogși21freeze,inversiunileistoricehashurioriginale.
RaportauditJSON actualizatpecodulbc60448:21pinuri/branch,116catalog,exact2overlap,
0integrareShiva. Toate5pinurifinance/privacypluspubspec rămânpreservateînuniune.

Standard/AndroidChrome depebc60448 erauîncurslaînregistrareaacesteidovezi.Ținte
finale:702Flutterintegral,187Python,3Node,10emulatorlegacy,Identity5,Auth/VisionVM,
financeVM/Chrome,APKdebugmain+aaptfărăupload. Acestea trebuie citite dinlogurile
HEADfinal,nu declarateprinadunare.98probededicated se suprapun cu702integral;
cele5networkbrowser sunt invocate separat. CIintermediarsupersedat/cancelled nu
ține loc debuildfinal. PatruworkflowuriVIIistoriceSKIPPEDnu suntPASS.

### Lucrări încă necesare înaintea integrării

- WriteriiHome/ExpensePage și fluxurilemanager/perDiem/expense nu sunt încă toate
  mutatepenoulprotocol. IntegrareaUI trebuie testată explicitnumaiîn harnessdemo;
  nu activațiregulilecandidat pestevechiiclienți.28caracterizăriVIIaleUI vechirămân
  KNOWNUNSAFE,nu seînchidpentru cărepositorynoul a trecut separat.
- AdminRestoremultibatch,preflightglobal,export/importmarkeri/revizii rămân
  nefinalizate;Rulesprevindștergereafinanciară,darnurefacaltecolecțiidejarestaurate.
- Mobileoffline/reconnectreal,private-storagehardware șiAuthGateactualpentru
  fabrica nouluiscope rămânnecertificate.5networkcasesfolosescpersistențăcache
  dezactivată,nu probeazăcacheoffline.
- Markerabsent/cached/pendingnuconfirmănoncommit. ConflictuldupăunSDKerror poate
  rămâneînrevizuire;nu segenereazăautomatIDnou șinu serebazeazăsume.
- CompatibilitateareceipturiloristoricecuTimestampnanosecunde,întregulregistru
  foarte mare,exactitateafloatingpointlaoriceordine demărime,limitadocumentului
  1MiB și retențiemultianuală necesităprobe/strategieînainte deproducție. Guardul
  demonstratdetecteazăunincrementdispărut,nu certificătoateproblemeledouble.
- LegacyperDiemoverdeclared șiIssue32integral rămânneînchise.4logurischedule
  protejateKNOWNUNSAFE rămânlamuncaseparatăShiva.

Modelcost40op+40checks/zi,max3callback:3080reads,80writes,44,851,200bytes/an
laipoteza2KiBmarker+1KiBistoric/op. Baseline/indexuri/egress/capacitateUNKNOWN;
production_readyfalse. Fărăbilling/Blaze/Functionsnoi/CloudRun/TTL/polling/listener.
Fărămerge,deploy,date reale,serviciiplătitesaumodificăriFirebaseproducție.

Reluare:«ContinuăPR55/MisiuneaVIII dinHEADreal șiCI dindescriereaPR. Citește
ChatGptșimatriceaVIII14plusaceastănotă. Păstreazăoricecommitnou. Nurepetafixurile
validate;reparăoriceCIREDfărărelaxare,apoiintegrareUI-emulator/Restore/compatibilitate
istoric/capacitateSpark. PR50/51/52read-only,producțieși billinginterzise.»


## Continuare VIII — precizie Timestamp, 15.10.2026 seara

Baseline test-only 02884dd33e9d11d69406dff28c9acd191a70cfb3, workflow38770734627,
job116545814562:98PASS/1FAIL real. Aceeași aserțiune așteaptă nanos123456789,
primește123456000 după vechiul Timestamp→DateTime→Timestamp. Prima încercare
957f3ee a avut eroare de fixture constTimestamp, NU martor de defect; corectată
în02884dd fără relaxare. Noul tip pur FinanceTimestamp păstrează exact valorile
submicrosecundă, inclusiv în istoric nested, digest și jurnal; DateTime existent
rămâne neschimbat pentru timestampuri reprezentabile exact. Tagul rezervat nu
poate fi imitat prin mapuri furnizate de utilizator. Test SDK real suplimentar
verifică receipt/edit fără schimbarea timestampurilor istorice.
CI corecției urmează; nu declarăm GREEN înainte de rezultat.192Python localPASS
include5noi probe separate de capacitate/retentie, încă nepublicate în acest lot.
Execuția locală Flutter a fost oprită de auto-review pentru acces metadata169.254.169.254;
nu s-a ocolit refuzul. Validarea Flutter continuă exclusiv prin CI existent.
Fără schimbări main/PR50/51/52, rules, producție, billing, deploy sau distribuție.


### Precizie — a doua graniță SDK web
cc8ddf5 a trecut104Dart și47JSemulator, dar6-lea testFlutterSDK a rămasRED
(job116546880893). Aserțiunea directă din Flutter încă vede123456000:
această probă singură NU distinge pierderea din readSDK de rescrierea serverului.
Adaptorul folosește acum update doar pentru câmpurile schimbate și arrayUnion
pentru singurul receipt nou; istoricul/datele nemodificate nu sunt retrimise din
snapshotul decodat. Gate-ul nou JS citește independent serverul și cere exact
123456789/987654321 pentru start/created/receipt istoric după receipt și edit.
Testulbrowser compară în plus snapshoturile sale înainte/după; comparațiaJS raw
este obligatorie, nu opțională. Nicio aserțiune de integritate nu este înlocuită
cu simpla acceptare a statusului confirmed. CI acestui follow-up încă în așteptare.


### Corecție de interpretare a probei raw
318a0c8:6/6testeFlutterSDK PASS, dar verificatorulJS cu valorile trimise inițial
seedului a eșuat. Verificarea corectă de conservare trebuie să compare starea
SERVER înainte/după, deoarece serverul poate normaliza timestampul încă din seed.
Seedul salvează acum numai cele3perechi seconds/nanos ale fixture-ului citit raw,
fără UID/token/datefinanciare, iar verificatorul cere egalitate exactă cu ele.
Dacă serverul a normalizat deja submicrosecundele, proba NU dovedește pierdere
istorică live. MartorulDart rămâne strict123456789→123456789 și păstrează aceeași
aserțiuneRED originală. Nu pretindem că Flutter-only dovedește formatulrawserver.
