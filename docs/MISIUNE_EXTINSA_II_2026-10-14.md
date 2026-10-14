# Misiune extinsă II — PR #28

Mandat: comentariul6164787480. Bază GitHub/local6851cd7b612e282b7b384446f61a711564658e38, standard38537913840 SUCCESS, identity38537913933 SUCCESS. Checkout nou curat; nu se repetă loturile25–27.

## A — Admin (lot29)

Două proiecții independente fără dependențe: compareAdminAccountData et adminAssignedFunctionIds. Substituțiile sunt inversabile byte-exact; main import/reexport compatibil. Comparator pending-first păstrează status explicit, name/email fallback și sort case-sensitive; assigned păstrează empty-list precedence, legacy fallback, toString, whitespace/null values și set independent. Nu stabilește autoritate sau drepturi.

Șapte teste Flutter noi:100perechi comparator/cazuri-limită, assignment legacy/list/aliasing și cinci widget tests AdminPanel real. Empty și inactive-only opresc dialogul; duplicate display names cu ID distinct, cancel fără/cu selectare;35membri scroll/select ultimul/cancel; edit funcție în dialog/cancel păstrează obiect original/rights. Sentry FirebasePlatform contează fiecare app access inclusiv exceptions înghițite. Cerem zero Firebase access, zero log/onChanged, roles/permissions intacte. Nu se certifică writes administrative/server authorization.

156 Python PASS local. Flutter/Dart indisponibile local; CI exact în curs după publicarea lotului, nu declarat verde anticipat. Inventar204Dart/59parts/145libraries/79independent lib, fără missing/orphan/duplicates/cycles. Cele116protected hashes intacte.

## B–F — rămase

B FCM: singleton Firestore în savePushToken/openChat; port opțional pushFirestore propus numai ca seam, fără modificarea algoritmului. SDK messaging fixture necesită refresh/initial/opened controllable. Guards #33 nu se portează.
C restore: Admin backup singleton/FilePicker; confirm dialog automatic precede orice DB access. Full restore non-atomic; partial snapshot, failure/retry/timeout/race necesită fixture acces la DB. Nu se inventează rollback.
D OCR: image_picker și recognizeTextFromImage hard-coded, private State/extension; saveExpense deja injectat. Harness trebuie să execute widget/form/save; regex-only nu se declară cap-coadă. Parserul rămâne protejat de mandat.
E: noi lifecycle scenarios/conversii numai dacă justificabile; FunctionDefinition importă Flutter pentru Color, nu se etichetează Dart pur.
F: reverificare read-only HEAD33/34/29, fără integrare/ref moves.

Fără merge/deploy/APK/main/PR33/34/29/Firebase production/rules/config/billing/versiune sau schimbări de comportament.

### Eșec inițial păstrat
20675e1/38541395111:223FlutterPASS/1FAIL,4alte standardSUCCESS;identity38541395031SUCCESS. Focused function editor cancel dispose controller înainte de reverse animation (runtime nemodificat). Testul cere eroarea exactă et whitelist numai cascade framework observate; zeroFirebase et drepturi intacte rămân obligatorii. Nu este remediere; KNOWN DEFECT explicit. CI corectiv urmează.

## B — FCM (lot30)

A finalc42a5b5e/38541891674 5/5SUCCESS+identity38541892239SUCCESS,224Flutter. Nu remediem controller cancel.

Seam minim propus înainte de schimbare: pushFirestore optional în Home, default FirebaseFirestore.instance, numai două puncte DB (token set et open-chat get). Source inversion byte-exact PASS. Șase SDK/State tests noi, fără rendering Home sau hardware: usable-token path payload/owner/ID/merge, refresh/cancel, await write gate, refresh-stream error fără retry, initial/opened delayed-dispose, tokenA după Home keyB (KNOWN DEFECT). Fake rejectA evită successful late attach necurățabil; nicio afirmație de acceptanță AuthGate sau server ownership.

| Await/eveniment | UID/efect actual | Probe efectivă |
|---|---|---|
| permission/getToken | currentUserId final din State la init; fără post-await ownership guard | tokenA întârziat după B încearcă pathA; reject fake, nu write live |
| savePushToken | users/UID/pushTokens/base64URL, merge payload, serverTimestamp | write gate blochează attach et initial; rejection nu retry |
| onTokenRefresh | closure din State, unawaited savePushToken | success/update/cancel et stream error; write error NEEXECUTAT |
| getInitialMessage | chat programează post-frame openChat | după dispose guard mounted oprește DB read |
| onMessageOpenedApp/openChat get | memberDirectory pentru member, guard înainte et după get | opened citește o dată; dispose înainte de rezultat oprește route |

FCM initial/live route success, unawaited refresh write failure, late success attach/cancel ownership, Web700 et GPS live rămân NEEXECUTATE. Cele116hashuri intacte;156PythonlocalPASS;206Dart/59parts/147libraries/79independent lib. CI exact urmează.

## D — OCR/form/Expense/save boundary (lot31)

B validat ee4255c2/38542589746 5/5SUCCESS+identity38542589759SUCCESS;230Flutter.

Două callbackuri opționale numai pentru selecție imagine et recunoaștere; defaulturile originale păstrate, source inversion byte-exact PASS. saveExpense port existent. Parser/form/save/dedup/amount/authorization runtime neschimbate. Zece teste widget noi exercită traseul real până la save fake et evidență UI locală, fără camera/MLKit/Firebase production. Nu este roundtrip Firestore.

| Text/caz sintetic | Așteptarea caracterizată |
|---|---|
|200,200.00,200,00|20000bani în Expense capturat și evidență locală|
|1.234,56 /1,234.56|123bani; KNOWN DEFECT regex captează1.23, nu123456|
|BF/date/fuel|nr12345/date05.10.2026/25L/8leiL/20000bani|
|invoice/ambiguous total|nr67890/date, ultimul total250; manual grouping invalid; override200,21→20021bani|
|save gated|zero introduced log/success/evidență înainte de await; un singur save; nonmanager confirmed=false|
|cancel form/image|zero save; image cancel zero recognizer/form|
|OCR throw/save throw|manual fallback, error et zero retry/evidence/success|

Initial local Python contract1FAIL căuta literal apel fără seam; adaptat să ceară fallback recognizer original de exact2ori, păstrând checks dedup/amount/await.156PythonPASS ulterior;116hashuri intacte.208Dart/59parts/149libraries/79independent lib. CI exact urmează; grouped amounts nu sunt declarate corecte, parserul nu este schimbat. Server rights Issue32/PR29 et hardware/cache SDK rămân în afara probelor.

## C — migration partial/future-schema (lot32); restore blocat

Două teste noi prin maintenanceFirestore existent; runtime lib/byte-identic lot31. Rejection al batch2 după350deletions confirmate, unawaited StateError observat exact în zone de test, zero marker/retry/rollback et snapshots nemutate; versiune necunoscutăbadge_v3 declanșează ștergerea definiției, golirea atribuirilor et markerbadge_v2 (KNOWN DEFECT). Nu se certifică integritatea drepturilor finale DB. Niciun delete financiar/diurnă/sală în aceste scenarii. Rejection fake înainte de commit, nu network ambiguity.

### Restore audit, fără probă dinamică

- AdminPanel.backup UI folosește singleton Firestore pentru două snapshots; actions folosesc singleton/FilePicker. Home maintenanceFirestore nu se propagă aici. Nu există port Admin read/write/file existent pentru full-restore; no new seam conform scopeC.
- Automatic cancel return precede DB access; dialogul prezintă ID et avertisment general, nu preview al documentelor. Afirmație din sursă, NEEXECUTAT widget.
- Automatic accept verifică statuscomplete/items și preflight ID/duplicates/data; metadata schema version necunoscută nu are guard dedicat. Collection absent nu e golită; valid group este înlocuit prin delete300/set8, non-atomic. Nu pretindem păstrarea documentelor existente după accept.
- Manual formatV1/preflight/allowed groups înainte de confirmation/deletion400. File decode/JSON parse sunt în afara preflight try; unknown groups ignorate, empty validated poate tot ajunge la marker-success. Save/partial failure/timeout/concurrent restore fără dinamica seam-ului rămân NEEXECUTATE.
- Nicio modificare de schema, drepturi, finanțe, jurnal Vision/offline operations sau rollback. Backup retention/codec/race lot27 și22–24 nu se repetă.

209Dart/59parts/150libraries/79independent lib;156PythonPASSlocal et116hashuri intacte. CI exact urmează.

## Checkpoint E/F et starea finală

| Lot | SHA validat | Standard CI | Identity CI | Flutter |
|---|---|---|---|---|
|A/29|c42a5b5e014177a5cdb745c8f3aaa98595ca0ed7|38541891674 SUCCESS5/5|38541892239 SUCCESS|224|
|B/30|ee4255c2b3e4fa74b1a865d9e14e5e54261fc12a|38542589746 SUCCESS5/5|38542589759 SUCCESS|230|
|D/31|6cbffab117eb42e0a0ef6945b5597bcc72211bbf|38543337920 SUCCESS5/5|38543338015 SUCCESS|240|
|C/32|9ddbb6989f39a2fd0492b5e5c740e9fbf434f97d|38543871448 SUCCESS5/5|38543871463 SUCCESS|242|

E checkpoint final adaugă1Pythonboundary pentru noul leaf pur et2checks în smokeDart existent (fărăFlutterengine). F read-only refresh#34becf552;#33a5f43ef/#29545e020/main377f1fd intacte. Conflictele et portarea sunt în INTEGRARE_PR28_PR33_PR34_2026-10-14.md. CI pe SHA checkpoint se publică în descriereaPR după finalizare, pentru a evita autoreferința.

**25Flutter noi față de217baseline;157Python(1nou),3Node,10financial+5identityemulator;smokeDart etbuildweb.** CountsFlutter242dovedite în logs lot32; Python157localPASS; restul CI final se confirmă înPR. Inventar209Dart=138lib+70test/support+1script,59parts/150libraries/79independentlib. Nota inițială210/151 era greșită cu1, corectată. Regenerare inventory et116protectedhashesPASS. Audit lexical fărămissing/orphan/duplicate/cycle, nu dovadă code-dead.

| Etapă | Rezultat efectiv | Limite |
|---|---|---|
|A Admin|2pureprojections,UI/cancel/scroll et focused-controller KNOWN DEFECT|mutantedit/delete/assign/serverauthorization necertificate|
|B FCM|tokenownership/payload/writegate/refresh/cancel/delayedinitial/opened;lateAattempt KNOWN DEFECT|refreshwritefailure/livechatroute/late-successattach/Web700 ethardware lipsă|
|C backup/restore|migrationbatchfailure etunknownfutureversion;restore sourceaudit|fullAdminrestoreUI/partial/timeout/race BLOCAT fărăDB/FilePicker portexistent|
|D OCR|fakeimage/recognizer→realparser/form/Expense→savefake/evidenceUI,amount/date/fuel/invoice/cancel/throw/gate|cameraMLKit etFirestore roundtrip/rights necertificate;groupedtruncation nereparată|
|E dependency/lifecycle|newleafclosure etengine-free smoke,27Admin/HomepartsState păstrate,existingmodels/learningpure|nicio conversie forțată;noul delayedFCM scenariu nu înlocuieșteAuthGateacceptance|
|F integration|SHAs/conflicts/Visionrefresh etseammatrix read-only|zero integration etzero CIcombinedtree|

### Reluare exactă

VerificăHEADreal/CI și workingtree; nu repeta25–32. Următorul lot poate adăuga un portAdminbackupDB/file strict limitat etsource-inversion proof înainte de fixture full-restore/cancel/partial/future-schema; acesta nu există încă. Păstrează finanțele/diurnele/sălile în cancel/preview et raportează acceptrestore ca operație destructivă non-atomică. FCM refresh-write failure et livechat route necesită observator/cleanup fără listeners tardive rămase. RemediileP1/parser/migration/controller sunt funcționale separate, nu scope-ul acestei modularizări. Integrarea#33→#28→#34 rămâne un mandat viitor.

Checkoutfinalcurat/sync,PRDraftOpen. Fără main/merge/deploy/APK/Firebaseproduction/data/rules/config/billing/version/PR33/34/29. Nu există lucru promis în fundal.
