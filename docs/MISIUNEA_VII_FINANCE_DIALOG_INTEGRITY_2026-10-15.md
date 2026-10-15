# MISIUNEA VII — Issue #48, Draft / DO NOT MERGE

## VII-01: intrare și matrice de acceptanță
Bază exactă PR46: 736ef9ea66bec5ff0c431d05808e43423c1f3ba9, tree 4221469b6ea94ef26a46706d9f8b129429188f38. Ramură nouă, PR-urile existente intacte. PR40 c010e23, PR41 b0f8687, PR44 0c8f813, PR45 da922ef citite. Niciun fișier runtime modificat în preflight.

| Flux real | Controller / stare | Persistență | Martor înainte de fix |
|---|---|---|---|
| _createSettlement | nameC, start/end locale, apoi selectedSettlementId | saveSettlement(result) | create cancel RED #46; zero saves/audit |
| _editSettlement | nameC, mutație shared name/startDate/endDate | saveSettlement(s), audit după await | rejet RED #46; succes pozitiv existent |
| _toggleSettlementClosed | closed/endDate shared, catch reface doar closed | saveSettlement(s) | close endDate RED portat selectiv #44 |
| _money | amountC/fromC, receivedEntries/departure/during shared | saveSettlement sau saveFinance | controller RED #41; NaN RED portat selectiv #45 |

HomeFinancialWriteActions serializează obiectul prin set(merge:true). Callback Future<void> nu clasifică certitudinea eșecului: excepția nu dovedește inexistența scrierii. Fără retry, rollback server sau confirmări inventate. Semantica avansului diurnei (poate depăși acumulatul), perDiems/per_diem_settlements_v2, OCR, roluri și rules rămân intacte.

### Freeze înainte de primul diff
Sursa settlement SHA256 13a2dd2aaa9b50ef8172ca1ebc5468bb4cf286b9a454385936ca67f0c017ba33. 116 protected hashes plus 21 VI freeze checks; numai hashurile unui fișier explicit reparat pot fi actualizate, cu valori old/new și motiv. Testele originale #41/#44/#45/#46 și ramurile lor nu se modifică. Probe noi rulează explicit în workflowul acestei ramuri; SUCCESS al detectorului RED nu este remediere.

### Stare
VII-01: matrice statică pregătită; reproducere independentă în CI în așteptare. VII-02–12: neexecutate. Hardware/SDK/Firebase live NEEXECUTATE. Flutter absent local; CI este executorul testelor Flutter. Fără merge/deploy/publicare/rules/producție/servicii plătite. Issue47 exclus.

## VII-02: controller ownership — implementare în verificare
Baseline 5250918: workflow38685978298 SUCCESS ca detector, cele cinci defecte specifice reproduse, control pozitiv PASS; identity38685978321 SUCCESS. Prima încercare de workflow a fost anulată din cauza concurrency comun cu workflowul istoric; grupul propriu a reparat exclusiv schedulingul.

FinanceDialogFields (bibliotecă Flutter independentă, import main) creează controllere în State și le dispose numai la unmount. Create/edit/money transferate; edit capturează text înainte de pop. Datepicker callbacks cer context mounted. Închiderea cere ruta curentă pentru a ignora al doilea tap în reverse transition. Nicio schimbare de save/mutații/sume în acest lot. 22 probe lifecycle noi, inclusiv dovadă explicită controller viu în tranziție și disposed după unmount. Testele #41/#46 au aceleași aserțiuni; poarta proprie cere acum exit0 pentru cele două lifecycle witnesses, nu exit1. Edit/close/NaN rămân expected RED, fără mascare.

Hash settlement old13a2dd2aaa9b50ef8172ca1ebc5468bb4cf286b9a454385936ca67f0c017ba33 → new88b39531c23bf7d23b6b39a98e939e6f7d663f786130ef344907197998cdc43f. Actualizat strict entryul acestui fișier din freeze VI și pinul fără hook din inversion; OCR/per-diem/Home/AuthGate/116hashuri păstrate. CI Flutter în așteptare; fără revendicare de remediere verificată până la GREEN.

## VII-03: validare numerică minimală
VII-02 ea70d4494e9da8b92e9b6eb8c2a96429a55363f9 validat: standard38686340436 SUCCESS5/5, identity38686340354 SUCCESS, probe38686340372 SUCCESS:24PASS lifecycle (22noi+2martori originali), control pozitivPASS, edit/close/NaN încăRED la acelHEAD.

Singura schimbare runtime VII-03: `!amount.isFinite` după tryParse. Zero/negativ/gol/invalid/nume gol rămân respinse; 200/200.00/200,00/0.01 și123.456 păstrează valoarea exactă a parserului. Nu introducem rotunjire sau plafon nou; precizia peste2zecimale rămâne regula existentă, nu o decizie nouă. OCR și istoricul nemodificate. 26probe noi (22settlement+4legacy), fixture opțional legacy/saveFinance cu fallbackurile originale. ProbaNaN portată din#45 cere acum PASS real, fără schimbarea aserțiunilor.

Hash settlement 88b39531c23bf7d23b6b39a98e939e6f7d663f786130ef344907197998cdc43f → 3c8931aff9b31830670d2ad72f8fc3aba37cf2798e46dee5042e3a49a6028681; aceleași două pinuri specifice actualizate,116hashuri protejate intacte. CI pe noulHEAD în așteptare.

## VII-06/07/08: completări întârziate, observabilitate și probă local-state separată
VII-03 HEAD4bda3851a55a049e7a8e72b06a3546ed48c4d4e9: standard38686620462 SUCCESS5/5, identity38686620461 SUCCESS, probe38686620453 SUCCESS. ProbeleNaN și lifecycle sunt acumPASS real; edit/close încăRED.

ExpensePage păstrează un epoch local schimbat la UID nou. Fiecare acțiune settlement capturează epoch+UID+callbackul de sesiune original; verifică înainte de save și după await înainte de audit/UI/telemetrie. Nu anulăm scrierea server deja pornită și nu facem retry. AuthGate/Home/rules nemodificate. 20probe UI cu State reutilizat deliberat: create/edit/close/money/legacy-money ×success/failure×A→B/A→B→A2. Aserțiunea identity(State) exclude un PASS obținut doar prin unmount.

3probe observabilitate: success0/failure1/revoked0 evenimente, exact1save și fără payload PRIVATE/valoare în Vision. 1probă director read-only: zero acțiuni settlement și zero writes. Acestea nu validează ACL server.

Nou martor explicit `finance_received_state.red.dart`: save fake respins înainte de commit, zero audit și zero erori Flutter înainte de aserțiunea local-state. Dacă starea rămâne modificată, markerulRECEIPT_CONFIRMED_LOCAL_STATE_NOT_PRESERVED rămâneRED, separat de controllerul reparat.

**Limite financiare VII-04/05/06:** callbackurile curente Future<void> nu disting reject sigur de possible-write-then-throw/timeout. Păstrăm martorii edit/close și caracterizăm receipt; nu introducem rollback/retry server sau false certitudini. Implementarea care tratează commit incert rămâneBLOCKED pentru review separat conformIssue48; reparația pe eșec cert necesită un contract de rezultat explicit, fără clasificarea arbitrară a tuturor excepțiilor drept no-write. Nu declarăm aceste3defecte reparate.

**Limită VIII:** testele certifică ExpensePage și callbackurile sale simulate. `_saveSettlementDirect`/`_saveFinanceDirect` declanșează dupăwrite un Learning event în Home; `_writeLearningEvent` nu are verificare explicită de epoch în această sursă. Nu revendicăm zero backend learning-event dupălogout. Home/Learning nu este modificat aici (cooperareIssue47); necesită coordonare și probe SDK separate.

### VII-09: diferențial de securitate față dePR40/Issue32 (read-only)
`firestore.rules` este byte-identic PR40 c010e23 și această ramură: SHA256589fe5eadc06cae665eaa27e9c9df0aea54eea6dffc10994438b4d97c58367da. WorkflowPR40 38671992447/job116217019279 reverificatSUCCESS. Nu rerulăm sau importăm59probe istorice și nu le raportăm drept59teste noi pe acestHEAD.

| Caz caracterizatPR40 | Stare server din repo | Delta misiuneaVII |
|---|---|---|
| OCR legitimate create fără distributedBy | respingere caracterizată | nicio remediere ACL |
| unauthorized amount/confirmed spoof | KNOWN UNSAFE, update permis în emulator | UI finite nu reparăACL |
| finance.managerId | KNOWN UNSAFE pentru membruviewOwnDecont | nicio schimbare |
| reopening settlement | KNOWN UNSAFE în aceleași limite | nicio schimbare |
| outsider/cross-team | controaleDENYPR40, nu garanție exhaustivă | rules neschimbate |
| legacy director permissions | KNOWN UNSAFE fallback | noultestUIread-only nu schimbă backend |

Avansul și schemeleperDiems/per_diem_settlements_v2 neschimbate. TesteleabuzassertSucceeds rămân dovezi de vulnerabilitate, nu acceptanțăsecuritate.

Pin autorizat VII-08 `lib/expenses/expense_page.dart`: 6c948fe71f19246a3c71bd2d2a20ac963bdf0b783f694a14ef81ed73f1ff71d3 → efd42ce1c1944bcf0288aea6ec54d2d9448ecf36dbba833454c8c43603cce01c.

Pin autorizat VII-08 `lib/expenses/expense_settlement_actions.dart`: 3c8931aff9b31830670d2ad72f8fc3aba37cf2798e46dee5042e3a49a6028681 → 3976d0bb5e0eef4c1c54d44443deade6938e6d6498293999e9dab0ad00b459f3.

### Corecție fixture VII-08
HEAD9c02ebe: probe38689600569FAIL înainte deexecuție la două cascade Dart cu arrow closure (setter interpretat peFuture/bool). Controller/numeric51PASS, receiptRED specific confirmat și director1PASS; nu revendicăm20session/3telemetryPASS. Atribuirile fixture devin statementuri separate, fără schimbarea aserțiunilor/runtime. Dublaconfirmare dinlifecycle invocă acum handlerul real de douăori; aldoileatap hit-tested în animație putea rata widgetul (warningCI), deci acea probă anterioară nu certifica reentrancy.

## VII-10/11 — porți separate și platforme
HEAD6d53127035fa05672944824a20f5ee2b024a81f1/tree591f3a55435fb8d2d3db26e794f05e48fdea4c64: standard38689824155 SUCCESS5/5, identity38689824183 SUCCESS, probe38689824104 SUCCESS. 51PASS lifecycle/numeric originale+noi;24PASS session/telemetry/director;1control edit-successPASS. Cele3probeRED au eșuat din motivele specifice, nu compilare. Dublaconfirmare este acum invocată efectiv de2ori șiPASS.

Workflowul nou mission-vii-platforms.yml este izolat prin branch+concurrency proprii; păstrează workflowurile istorice și hashul probei originale controller. Rulează AuthGate/Vision, martorii financiari devenițiGREEN, testelefinance înVM șiChrome, plus2probeWeb700, apoi compileazălib/main.dart înAPKdebug și inspecteazăaapt. Nu uploadăm/instalăm/publicămAPK, nu modificăm versiuni/manifest/semnare/dependențe. Rezultatul peHEADul final se verifică înGitHubActions și se înscrie înPR50; nu este revendicat anticipat.

## VII-12 — checkpoint parțial și reluare
**MisiuneaVII NU este încheiată integral.** VII-01,02,03 și07 au probe funcționale; VIII certificăExpensePage (limitaHome/Learning rămâne); IX este diferențialread-only; X păstreazăfreeze și porțile distincte; XI urmează validarea platformelor peultimulHEAD. IV/V/VI rămânKNOWN RED și implementarea rezultatului incert necesităreview separat. NiciunGREENdedetector nu este numărat caBUGFIXED.

| Defect | Înainte | După pecheckpointul6d53127 |
|---|---|---|
| create cancel controller | RED #46 | PASS real, aserțiuni originale |
| receipt controller | RED #41 | PASS real, corp probă original păstrat |
| NaN ajunge la save | RED #45 | PASS real, zero save invalid;26teste noi |
| completare UI/audit dupăUIDswitch | lipsăgardă locală înExpensePage |20probePASS cuState reutilizat; nu certificăefecteHome/SDK |
| edit save rejection | RED #46 | încăRED |
| close endDate failure | RED #44 | încăRED |
| receipt entries/totals failure | riscstatic #42 | RED dinamic distinct, nereparat |

72testeFlutter noi descoperite automat (22lifecycle+26numeric+20session+3telemetry+1director) și1martorRED nou pentrustareareceipt. Nu sunt72testehardware. Standardulfinal include și testelemoștenite; numărul exact se citește dinlog. Toate cele116hashuriprotejate PASS; numai settlement/ExpensePage și pinurile specifice lor au fostmodificateexplicit.

**Reluare exactă:** citeșteHEADulreal alPR50 șiCIultim, făfetch curat, păstreazăramuraDraft; nu repetaIII–VI sau testelevalidate. Prioritatea următoare: contractulcerte/incertereconciliere demai jos pentruVII04/05/06; sourceprobesRED rămânobligatorii. Nu editaIssue47/HomeGPS/FCM/Learninglogging, nu face merge/deploy/publicare/producție/rules/billing.

Hardware, GPS/FCM/Firebase live, MLKit/cameră și commiturile unui serverreal:NEEXECUTATE. UIownerPASS nu înseamnă că ACLservereste securizat.

## Contract concret pentru continuarea VII-04/05/06 — propunere, neimplementată

- Reprezentare explicită a rezultatului: confirmat; respins înainte de scriere; incert. O excepție generică nu decide singură categoria. Gărzile client din Home resping înainte de `.set`; excepțiile SDK/timeout și eventualele side effects după write nu sunt clasificate arbitrar.
- Un candidat de editare trebuie separat de snapshotul local confirmat; compatibilitatea callbackurilor și actualizărilor prin listener se testează. La respingere certă se restaurează numai starea propriei operații, fără a suprascrie o versiune mai nouă primită între timp.
- Închidere: snapshot comun pentru closed/endDate; succesul păstrează semantica existentă; eșecul cert reface ambele. Redeschiderea și drepturile rămân neschimbate.
- Încasare: `ReceivedMoneyEntry.id` există deja (`idNow()`), dar un ID în payload nu este singur o garanție de idempotency server. O eventuală reluare trebuie să păstreze același ID și să verifice autorizat documentul/revizia; nu să creeze alt transfer. Se separă settlement de finance legacy și se păstrează agregatele istorice fără inventarea transferurilor.
- La rezultat incert: fără retry/scriere de compensare automată, fără sumă declarată confirmată sau definitiv respinsă; reconcilierea cere verificare server și protecție UID+epoch, în limitele contractului aprobat. Nu logăm sume, ID-uri, nume sau payloaduri în Vision.
- Acceptanță: exact un write inițial; controale before/after pentru fiecare câmp; failure înainte de commit; write-success-then-throw; timeout; event listener mai nou; duplicate confirm; UID switch; zero audit de succes pe respingere; verificare explicită a ID-ului operației. Regresii pentru avansuri și schemele distincte de diurnă.

Această propunere este concretă pentru review separat al cazurilor incerte, conform Issue48. Nu a fost implementată ca politică financiară și nu autorizează schimbări de rules/server/retry.

## Continuare VII-04 — respingere certă înainte de persistență

Bază reverificată: PR50 `cadbf00acf40d71771b38c16fd5a99bd71bc1e01`, checkout curat, tree `e77cdd5b409889c46942251b715eb0ad27e0ed69`. CI final al bazei: standard38690312118 SUCCESS5/5 (508Flutter/171Python/3Node/10emulator), identity38690312163 SUCCESS5; Android38690312317 SUCCESS (161+75VM,2+72Chrome,APKreal+aapt). Nu reluăm misiunile încheiate.

**Contract minim implementat numai pentru certitudine dovedită:** `FinanceSaveRejected extends StateError` este emis în cele două gărzi locale settlement/finance înainte de apelul Firestore. Nu există catch care convertește excepții SDK/timeout în acest tip. Testul Python nou inversează exclusiv cele două nume de tip și reconstruiește hashul byte-exact al adaptorului anterior: toate condițiile de drepturi, scrierile și efectele ulterioare rămân neschimbate. Compatibilitatea StateError și mesajele sunt păstrate. Nu sunt schimbări de ACL/rules sau semantică financiară.

Editarea restaurează name/startDate/endDate numai la acest semnal explicit, cât sesiunea originală este activă și câmpurile încă aparțin încercării proprii. O observație mai nouă nu este suprascrisă. Closed/manager/sume/selectarea rămân neatinse. Generic StateError, timeout și posibilul write-success-then-throw rămân neclasificate, fără rollback sau retry nou. Aceste cazuri nu sunt declarate reconciliate.

Proba istorică edit-failure din această ramură păstrează toate aserțiunile, inclusiv identitatea obiectului, toate câmpurile, exact1save și zero audit. Numai fake-ul declară acum informația pe care chiar o garantează: `FinanceSaveRejected` înainte de persistență. Poarta proprie cere PASS real; PR46 original este intact. Controale negative distincte folosesc în continuare StateError generic și un fake de scriere reușită urmată de eroare, deci noul contract nu poate produce un GREEN prin clasificarea arbitrară a tuturor erorilor.

**7 teste Dart noi:** compatibilitate marker; reject cert; generic; write-then-throw; observație mai nouă; epoch revocat; modificarea efectivă a startDate prin datepicker cu păstrarea closed inițial. **1 test Python nou**,172PASS local. Flutter/Chrome/Android pe noulHEAD sunt în așteptare; nu revendicăm încă GREEN. VII-05/06 rămân RED, iar reconcilierea rezultatelor incerte rămâne pentru review separat.

VII-04 `lib/expenses/expense_settlement_actions.dart`: SHA256 3976d0bb5e0eef4c1c54d44443deade6938e6d6498293999e9dab0ad00b459f3 → 105bb0fa1d4141e610ecd765bb5afe61013e038d655bb118d1a264353c863d02.

VII-04 `lib/home/home_financial_write_actions.dart`: SHA256 7de96936fd2493ed210d392cc6554f768a3a3dc25fafca2169e9ab126e807f76 → ad5c8989bc6740a63592ae354684a7518b1b350e539db77df2022a735f493365.

## Continuare VII-05 — closed/endDate la respingere certă

Lotul VII-04 `c86ba258ae35b8691c4dd83922ed2f58d255d7e2` are standard38691749622 SUCCESS5/5, identity38691749546 SUCCESS și probe38691749620 SUCCESS: martorul editării și cele7teste noi trec efectiv. EndDate-close și receipt rămânRED pe acelHEAD. Buildurile Android intermediare pot fi supersedate; nu sunt folosite ca dovadă pentru noulHEAD.

Închiderea/redeschiderea capturează împreună closed și endDate. La `FinanceSaveRejected`, le restaurează numai dacă sesiunea este încă validă și starea încă este încercarea proprie; observațiile noi nu se suprascriu. Erorile neclasificate păstrează calea existentă, fără clasificare SDK, server rollback sau retry nou. Drepturile și regulile de redeschidere nu sunt schimbate.

Un set cu cheie epoch+settlementId împiedică două dialoguri sau două scrieri concurente de close/reopen pentru același decont. Cheia se eliberează înfinally inclusiv la cancel/eșec, iar epoch-ul unui cont nou nu este blocat de operația veche. Confirmarea folosește închiderea protejată a rutei pentru dublu handler.

**17 teste noi:**8combinații succes/reject×close/reopen×endDate prezent/absent; cancel/Back/barrier;2duplicate handler; failure→acțiune nouă reușită; observație nouă; revocare; write-success-then-throw. Martorul #44 păstrează toate aserțiunile, dar fake-ul marchează explicit respingerea înainte de persistență; poarta devinePASS real. PR44 original este intact. Fixture-ul are opțiuni inițiale closed/end, cu aceleași valori implicite. CI nou în așteptare.

VII-05 `lib/expenses/expense_page.dart`: SHA256 efd42ce1c1944bcf0288aea6ec54d2d9448ecf36dbba833454c8c43603cce01c → 176fa1a7e904747d55dfd17b6a035c7a0db20b498c46ceab1daef719a0d1ea29.

VII-05 `lib/expenses/expense_settlement_actions.dart`: SHA256 105bb0fa1d4141e610ecd765bb5afe61013e038d655bb118d1a264353c863d02 → 0fc0c21e6b23d481fee3dbc2072b70a163515093a5418c9af212738dff29d914.

## Continuare VII-06 — integritatea încasărilor la respingere certă

VII-05 `f96b109cebbfeba7f7197fb6f808e5e47d73c19e`: standard38692128716 SUCCESS5/5; identity38692128867 SUCCESS; probe38692128850 SUCCESS, inclusiv17teste noi și martorulclose/endDate devenitPASS. Receipt era ultimul martorRED pe acelHEAD.

Încasarea capturează ținta settlement/finance și numele echipei la deschiderea dialogului. După confirmarea utilizatorului păstrează un snapshot al intrărilor și celor două agregate. La `FinanceSaveRejected` restaurează snapshotul numai dacă lista, prefixul istoric, intrarea proprie și totalurile încă sunt încercarea proprie. O observație mai nouă nu este ștearsă. Agregatele legacy sunt restaurate exact, nu recalculate sau transformate în transferuri inventate. Calea de succes și sumele rămân cele existente.

Cheia epoch+team+settlement blochează intrările paralele plecare/în timpul deplasării și se eliberează înfinally la cancel, Back, barrier, eșec sau succes. O operație nouă în contulB/A2 are alt epoch și nu este blocată de save-ul vechi. Nu este un mecanism de idempotency server sau cross-device. CodulVision received_amount_save_failed rămâne unul singur, constant, numai pentru sesiunea activă.

**29 teste noi:**16combinații settlement/legacy×departure/during×succes/reject cert/generic/write-then-throw; agregate legacy fără intrări;4cazuri observație nouă/revocare;2intrări duplicate; recovery explicit;2cazuri cont succesor legitim;3cancel/back/barrier urmate de acțiune nouă. Martorulreceipt păstrează toate aserțiunile și acum declară explicit fake-no-write prin marker; poarta devinePASS real. Controalele neclasificate nu sunt convertite în respingere certă.

Rezultatele SDK generice, timeouturile, commiturile incerte, reconcilierile și lipsa unui contract atomic/idempotent server rămân NEIMPLEMENTATE/BLOCKED pentru review separat. Nu există server rollback, retry automat, noi reguli financiare sau modificări de Firestore rules. Nicio afirmație de securizare backend ori testare live. CI pe noulHEAD este în așteptare.

VII-06 `lib/expenses/expense_page.dart`: SHA256 176fa1a7e904747d55dfd17b6a035c7a0db20b498c46ceab1daef719a0d1ea29 → 9016fe9e1d79e5fc8ce3686bf72e29a5c2dcfd28351698361c5f93f155cc249e.

VII-06 `lib/expenses/expense_settlement_actions.dart`: SHA256 0fc0c21e6b23d481fee3dbc2072b70a163515093a5418c9af212738dff29d914 → 4a5fa16106be54cc7667fcd462aab534b498577c333bf26cd9b6aebc925ae5ba.

## VII-06/08 — serializare între acțiunile aceluiași decont

`625343fbd903fc604f9a903e93143f42e3557b6e`: standard38692687415 SUCCESS5/5, identity38692687328 SUCCESS, probe38692687421 SUCCESS. Cele3probe de respingere certă sunt acumPASS real; controalele generic/write-then-throw rămân caracterizări ale comportamentului incert, nu BUGFIXED.

În verificarea concurenței am separat un risc suplimentar: două gărzi independente money/close nu împiedicau o editare sau închidere să trimită întregul model în timp ce încasarea era încă în așteptare. Noua gardă comună serializează create (cheie separată) și edit/close/money (aceeași cheie de decont). Cheia este recordDart `(epoch, teamId, settlementId)`, fără concatenare ambiguă de ID-uri; nu se păstrează sau trimite la server. finally eliberează numai cheia operației proprii. Blocarea nu introduce retry ori noi reguli financiare.

**7teste noi** invocă handlerii reali capturați, nu doar hit-testing:6combinații edit/close/receipt×succes/reject încearcă ceilalți writeri în timpul save-ului; zero dialog sau save suplimentar și snapshot corect dupărejection. Apoi o acțiune nouă funcționează. Al7-lea testează intrareaNew și confirmarea dublă. Este serializare înExpensePage pentru aceste4fluxuri, nu un lock global pentru Admin/altefluxuri/alte dispozitive. Atomicitatea și reconcilierea server rămân în afara acestei reparații.

Total continuare față de cadbf00:60testeFlutter noi (7edit+17close+29receipt+7concurență) și1Python nou. Cumulativ înPR50:132testeFlutter noi față dePR46. Numerele PASS finale/HEAD/tree se verifică pe noulcommit; nu se împrumută rezultatele unuiHEADanterior.

Serializare `lib/expenses/expense_page.dart`: SHA256 9016fe9e1d79e5fc8ce3686bf72e29a5c2dcfd28351698361c5f93f155cc249e → f6a3976dbe52fa81c1599d78207803c35362c2cba5ece9c68182cb68a8af511d.

Serializare `lib/expenses/expense_settlement_actions.dart`: SHA256 4a5fa16106be54cc7667fcd462aab534b498577c333bf26cd9b6aebc925ae5ba → db37036095f0f8f54b3e820cb0eb9230a8f8243f12aaae55f4d87b2559cbf87d.


## VII-04/05/06 — audit rezultate incerte, continuare 2026-10-15

Bază verificată: c49c1f2765f3cb06e08adc46fe3b78c2982ff1b0, tree947c9c3fb5cea0fe9276c3acffb46d6b7688f039, checkout curat. Standard38693180067/identity38693180026/finance38693180131/platforms38693179790 SUCCESS; 568Flutter/172Python,132financeChrome+2Web700 și APK debug real+aapt. Niciun lot validat nu a fost reluat.

19 probe Flutter noi execută handlerii reali ExpensePage cu o limită de persistență sintetică ce capturează la invocare și separă commit/ack: pending30s, succes, timeout fără commit, commit apoi timeout, reintroducere manuală după rezultat incert, două instanțe independente/ordine inversată a commiturilor, A→B→A2 cu commit întârziat, divergență closed/endDate după commit+timeout. Settlement și finance legacy rămân distincte. Fake-ul proiectează numai câmpurile observate, fără a reimplementa SDK/codec sau a pretinde Firebase live. Timeoutul este injectat la limita aplicației: nu afirmăm că Firestore.set expiră automat offline. CI pe noul commit este în așteptare.

KNOWN UNSAFE (detectoare PASS, nu reparații): reintroducerea manuală poate persista două intenții echivalente cu ID-uri diferite, chiar dacă primul apel nu a comis deoarece memoria conține deja mutația; snapshotul concurent poate înlocui lista/totalurile altui writer; close poate rămâne deschis local după un commit închis. Zero retry/rollback/reconciliere nouă. Succesul sintetic este control pozitiv; verificăm 0 audit succes la timeout și 0 telemetrie pentru epoch vechi. Sursele runtime și firestore.rules sunt neschimbate în acest lot. Contractul detaliat și compatibilitatea #51 urmează separat, fără integrare.


## VII-08 — martor nou pentru completarea close după revocare

Inspecția catch-ului close generic arată `s.closed = !next` înainte de garda sesiunii. Martorul `finance_stale_close.red.dart` cere ca un obiect partajat/reobservat de succesor să nu fie modificat de completarea veche. Opt scenarii: revocare/unmount/A→B/A→B→A2 × StateError/TimeoutException. Fixture-ul primește numai un override opțional de settlement, valorile implicite rămân aceleași. Proba are aserțiune de integritate strictă, zero save suplimentar/audit/UI privat; workflowul cere RED specific, nu compile failure. Confirmarea dinamică urmează înainte de corecție. Niciun runtime modificat aici; nu este remediere de rezultat server incert.


VII-08 martor f10b892: workflow38695842560/job116292104540 a reprodus strict 4 cazuri stale (revoked/unmounted ×2 erori). Cele4 cazuri A→B/A2 au întâlnit mai întâi un overflow de layout al fixture-ului la800px; nu sunt revendicate drept repro reușită. Corecție numai viewport1400×1000, cu reset în teardown. Poarta baseline cere acum exact8 markeri și respinge explicit overflow/compilefailure. Nicio aserțiune financiară sau runtime schimbată. Auditor read-only #50/#51 rulat local:21pinuri per ramură validate,2+3 delte disjuncte, exact2fișiere comune; nu s-a executat integrare. Restul drafturilor de audit rămân nepublicate până la lot separat.
