# Misiunea VIII — raport consolidat și blocaje, 16 octombrie 2026

PR #55 / Issue #54. DRAFT / DO NOT MERGE. `production_ready=false`.

## Domeniu și rezultat

Mandatul permite implementare pe ramura izolată și demonstrații în emulatorul
`demo-andi-carpet`. Nu permite deploy, merge, migrare/date reale, instalare sau
distribuție APK, billing, Functions/Cloud Run ori servicii plătite noi.

Misiunea nu este închisă integral. Protocolul candidat și harnessurile demo sunt
implementate; nu sunt active în Home implicit și nu certifică vechii clienți.
Raportul descrie distinct rezultatele demonstrate și condițiile încă neîndeplinite.

## Matricea celor 14 loturi

| Lot | Livrat în Draft | Limită / restanță |
| --- | --- | --- |
| VIII-01 | Inventar writeri și model executabil Spark, comparație C/B | Planul, baseline, indexurile și egress live UNKNOWN |
| VIII-02 | Martori ACL RED reali și scenarii de ambiguitate/concurență | 24 caracterizări VII rămân pentru UI legacy; patru Restore au devenit regresii de refuz |
| VIII-03 | Intenție imuabilă, operationId aleator stabil, digest canonic, binding actor/team/revizie | Nu se deduplichează după sumă sau nume |
| VIII-04 | Port atomic și fake concurent, replay no-op, conflict explicit | Fake-ul nu este SDK/server |
| VIII-05 | Adaptor SDK Firestore explicit demo/loopback, maximum trei încercări | Nu este configurat pentru producție |
| VIII-06 | Jurnal privat bounded, persist-before-send, refuz de ID nou pe țintă nerezolvată | Storage fizic și coordonare între procese necertificate |
| VIII-07 | Receipt/create/edit/close, coordinator și callbackuri ExpensePage reale în demo | Home implicit și toate writepath-urile nu sunt convertite |
| VIII-08 | Rules candidate, roluri/câmpuri, create legitim expense, Admin fără bypass financiar | Numai repo/emulator; nu închide Issue #32 integral |
| VIII-09 | Marker+revizie+țintă atomic, replay/concurență și ACL în SDK/emulator | Limitele de acces rules sunt testate; billing live nu este măsurat |
| VIII-10 | Opening balances păstrate, precizie Timestamp, gard Restore manual/automat, manifest țintit | Restore complet/inventar global și compatibilitate clienți vechi blocate |
| VIII-11 | Ack pierdut după commit, reconciliere server, proxy offline real Chrome, A→B→A2, recreare scope | Nu este restart OS/secure storage pe telefon și nu certifică iOS/Windows |
| VIII-12 | Diagnostic minim, audit diferențial privacy, buget multianual și capacitate document | Fără garanție cost zero; receivedEntries continuă să crească |
| VIII-13 | Standard, Identity, emulator SDK, Chrome și main Android compile-only | Nu este test pe hardware sau distribuție |
| VIII-14 | ChatGpt, rapoarte, contracte și handoff în PR | Issue #53/#54 rămân deschise cât timp criteriile integrale lipsesc |

## Continuarea curentă: revocarea registrului Admin

Auditul a identificat două limite ale readerului paginat: un owner observat fals
putea redeveni valid dacă aceeași closure revenea la true; pagina deja afișată nu
se elimina la simplul dispose extern al readerului sau la un rebuild cu owner
revocat. Cele patru probe inițiale sunt publicate separat în commitul
`93f8a647b8e29d4edfdabf30260a3b151372a403` înainte de corecție.

Corecția candidat face revocarea monotonă inclusiv pentru owner care aruncă,
notifică invalidarea fără dependențe Flutter în reader, elimină pagina/cursorul
imediat din State și programează reconstruirea sigură a panoului. Subscribe și
unsubscribe urmează înlocuirea/disposal widgetului. Un listener care aruncă nu
poate opri revocarea celorlalți. Invalidation simplă permite o deschidere explicită
nouă; dispose și expirarea observată nu reactivează readerul.

Integrarea viitoare trebuie să apeleze dispose sincron din proprietarul sesiunii
și să furnizeze closure UID+epoch autoritativă. O schimbare a unei variabile
externe nu produce singură un frame; fără notificare, verificarea se face la
următorul acces/rebuild. Nu există polling, timer, listener Firestore, citire sau
scriere nouă la mount/rebuild/invalidation. Un frame deja văzut nu poate fi șters
retroactiv din memoria utilizatorului.

Validările noului cod se consemnează numai după CI real pe SHA publicat.
197 teste Python locale au trecut; aceasta nu reprezintă validare Flutter.

## Cost și retenție

Modelul curent include tranzacțiile, verificările explicite, refreshul server și
paginile registrului. Exemplu sintetic: 40 operații + 40 verificări pe zi = 3.960
reads document/rules modelate, 80 writes; două deschideri și trei pagini ulterioare
cu 20 markeri = încă 1.122 reads, zero writes. Total modelat 5.082 reads/zi în
această combinație, înainte de baseline/index/egress. Nu este factură măsurată.
Markeri imuabili fără TTL, purjare, polling sau replay financiar automat.

La 20 receipts/zi concentrate într-o singură țintă, presupunând 1 KiB/receipt și
4 KiB inițiali, rezerva internă de 512 KiB permite 25 zile complete. Nu este o
limită monetară nouă sau o predicție a utilizării reale; limita Firestore pe
document și indexurile rămân constrângeri. Cititorul paginat citește markerii,
nu migrează lista monetară receivedEntries într-o schemă nouă.

## Blocaje concrete pentru închiderea integrală

1. **Home implicit/toți writerii:** necesită compoziție end-to-end a scope-ului
   AuthGate, jurnalului durabil, metadatelor server și înlocuirii modelelor din
   snapshot autoritativ. Nu activați rules candidate peste clienții vechi.
2. **Restore complet:** V1 nu exportă toate subcolecțiile financialIntents și nu
   dovedește un snapshot global. Înlocuirea/ștergerea globală ar necesita inventar
   consistent și coordonarea tuturor writerilor, inclusiv clienți vechi. Scanări
   globale, migrare sau lock global nou nu sunt introduse sub acest mandat.
   Gardul refuză inputurile financiare înaintea oricărei mutații; candidatul
   țintit nu șterge și nu rescrie finanțe/markeri.
3. **Istoric în creștere:** necesită proiectarea unei scheme compatibile și
   verificarea indexurilor/retenției. Nu trunchiați, rotunjiți sau ștergeți bani.
4. **Hardware:** restart de proces/OS, secure storage, cache/offline Android/iOS,
   comportament Windows și probe fizice nu pot fi certificate de CI/emulator.
5. **Spark real:** planul activ, DB eligibilă, utilizarea existentă, indexurile și
   transferul nu pot fi deduse din cod. Nu există acces live în această misiune.
6. **Legacy perDiem:** caracterizarea încasărilor peste valoarea declarată nu se
   remediază prin plafon nou; schemele perDiems și v2 rămân distincte.

Issue #54 cere oprirea numai a sublotului care nu poate fi demonstrat sigur și
continuarea celorlalte lucrări permise. Blocajele de mai sus nu sunt prezentate
ca sarcini terminate sau ca solicitări repetate de permisiune.

## Dovezi anterioare verificate

Checkpoint inițial al acestei continuări: `80297d96b45d659ea2a02a2e4f69fe4b935c74d3`,
tree `cd0725e46a212644a3656d0dacb28da0292491b3`.
Standard #38822130215 SUCCESS 5/5 (771 Flutter, 197 Python), Mission VIII
#38822129942 SUCCESS (167 Dart, 47 JS emulator, 10 Flutter SDK + raw timestamp),
Identity #38822129884 SUCCESS, Platforms #38822129963 SUCCESS (161 Auth/Vision,
349 finance VM, 335 finance Chrome, Android debug compile). Suitele se suprapun;
nu se însumează în teste unice. Patru workflowuri istorice sunt SKIPPED.

SHA/tree/workflowurile finale ale continuării se citesc din descrierea PR #55.

## Lot următor: dialogurile originale împreună cu SDK real

Din checkpointul 7400863 complet GREEN, două acceptanțe noi candidate pornesc
ExpensePage original, cu utilizatorul Auth și echipa seeduite în emulatorul demo.
Prima execută prin butoanele reale create → receipt → edit → close, cu refresh
server și revizii 1→4. A doua pierde ack numai după commit real și apasă butonul
«Verifică salvarea»: un marker server și un refresh, fără o a treia tranzacție,
fără dublură la reintroducere și fără audit de succes înaintea confirmării.

Fixture-ul comun primește teamId injectabil, păstrând implicit valoarea veche
pentru toate testele existente. Nu se înlocuiește writerul cu fake și nu se
schimbă runtime-ul aplicației. Jurnalul rămâne injectat în RAM; această probă
nu certifică secure storage fizic, restart OS sau fabrica implicită Home.
Așteptarea bounded a evenimentelor SDK este exclusiv în test, nu polling nou în
aplicație. Rezultatele sunt candidate până la CI real pe noul SHA; 197 teste
Python locale PASS. Probele vechi și verificatorul raw Timestamp rămân obligatorii.

## Validare UI+SDK și candidat AuthGate real

Pe aac5484 toate cele patru workflowuri sunt SUCCESS: Standard #38840646418,
Identity #38840646422, Mission VIII #38840646423 și Platforms #38840646436.
Cele două probe integrate au trecut: suita SDK are 12 PASS, alături de 174 Dart,
47 JS emulator și verificarea raw Timestamp. Platformele au 161 Auth/Vision,
356 finance VM, 342 finance Chrome și Android main compile + pachet SUCCESS.

Următorul candidat conectează **AndiCarpetaApp/AuthGate real**, fluxul Auth real
și snapshoturile reale users din emulator la ExpensePage original. O încasare
este comisă, ack-ul este ținut în așteptare, apoi conturile trec A→B→A2. Ecranul
lui B nu trebuie să păstreze numele decontului lui A, nici să încarce jurnalul lui.
Scope-ul vechi este închis la disposal și nu poate refresh-ui sau audita după
eliberarea ack-ului. În A2 se încarcă explicit exact intenția durabilă și butonul
reconciliază numai prin marker+refresh, cu zero tranzacții noi și zero audit
inventat al dialogului dispărut. Stocarea RAM este comună fixture-urilor, cu chei
separate per UID; nu este storage fizic sau restart de proces. Streamul de
settings este inert; autentificarea și profilurile nu sunt înlocuite cu fake.

Fixture-ul expune același buildPage pentru montarea sub rădăcina AuthGate, cu
aceleași callbackuri și dialoguri. Nu se modifică Home implicit, AuthGate,
permisunile sau rules. A treisprezecea probă SDK este candidată până la CI real,
nu este declarată PASS prin reutilizarea rezultatului aac5484.

## Defect remediat în candidat: confirmare server și cleanup local eșuat

Checkpointul a3f3acc are toate cele patru workflowuri SUCCESS și 13 probe SDK
reale trecute, inclusiv AuthGate A→B→A2. În auditul continuării s-a găsit pierderea
flagului journalPending în FinanceExpenseDemoAdapter: coordonatorul păstra
confirmarea serverului și semnala eșecul curățării locale, dar adaptorul elibera
Future-ul și ținta. O nouă intenție pe aceeași țintă putea rămâne blocată de
intenția veche din jurnal, fără recuperarea ei în pagina curentă.

Baseline d8e89c8, Mission VIII #38842430891/job116785337750: 174 PASS / 2 FAIL.
Martorul întărit 94f7769, #38842594098/job116785936485: aceleași 174 PASS / 2 FAIL;
proba apasă efectiv «Primit la plecare» și găsește dialogul unei intenții noi,
deși cleanup-ul local era nerezolvat. Sunt verificate separat eroarea înaintea
scrierii locale și scrierea locală aplicată urmată de eroare. Confirmarea
financiară server era reală; remedierea privește finalizarea și recuperarea locală.

Candidatul reține separat confirmed și cleanupPending, blochează eliberarea
țintei și afișează explicit confirmarea cunoscută. Butonul de recuperare repetă
numai recordResult local pentru aceeași intenție; nu reexecută tranzacția sau
citirea markerului deja confirmat. După cleanup este cerut un singur refresh
server înainte de înlocuirea modelului și finalizarea callbackului UI. Un jurnal
care era deja gol după o eroare locală nu devine un blocaj permanent. Eșecul
refreshului păstrează statutul de salvare confirmată cu actualizare necesară.

Aceleași două regresii stricte rămân. O probă suplimentară rulează dialogul real
cu SDK Firestore real și o eroare injectată în jurnalul RAM, apoi verifică prin
buton exact două tranzacții totale (create+receipt), un refresh și zero resubmit.
176 Dart și 14 SDK sunt ținte de validare până la CI real al noului SHA. Nu sunt
certificate storage fizic, Home implicit, Restore complet sau Spark live. Nu
există retry automat financiar/local, polling, read/write Firestore suplimentar
la rebuild, modificare rules, bani/rotunjiri ori servicii plătite noi.

## Continuare nouă: operații succesive fără refresh extern ascuns

Bază complet GREEN: 3ce0084. Nu se repetă loturile UI+SDK, AuthGate sau cleanup.
Baseline d376cca, Mission VIII #38844858895/job116792961278: 176 PASS / 1 FAIL real;
după prima încasare confirmată, al doilea dialog din aceeași pagină nu se salva
fără observe extern. Acesta este un gol în compoziția demo, nu o reparație deja
distribuită în Home.

Candidatul adaugă readAcceptedModel, callback sincron opțional după handoff-ul
snapshotului server către UI. Adaptorul verifică tipul TravelSettlement/TeamFinance,
path, echipa, câmpurile reprezentate, revision și lastOperationId ale modelului
instalat. Refolosește validarea existentă observe, fără o a doua implementare de
codec și fără a deduce confirmare din model. Snapshotul complet este înghețat
înaintea await-ului UI; baseline păstrează datele originale, inclusiv precizia
Timestamp, separat de reprezentarea de afișare. Abia după validarea modelului
se eliberează callbackul și se reține baza pentru următoarea intenție explicită.

Fără callbackul opțional se păstrează API-ul anterior cu observe explicit.
Model absent, tip greșit, revizie veche sau valoare greșită păstrează operația
confirmată în recuperare, fără audit de succes sau reexecutare financiară. Un
writer concurent ulterior produce conflict; nu se face rebase automat.

Memoria rămâne bounded la 32 baseline-uri. forgetBaselineExplicitly elimină doar
o observație regenerabilă și refuză orice țintă cu Save încă în așteptare; nu
șterge jurnalul sau intențiile. Create la capacitate este refuzat înainte de
tranzacție. Sunt adăugate șapte regresii Dart, incluzând proba RED păstrată.

Proba SDK existentă create→receipt→edit→close este întărită prin eliminarea celor
trei citiri manuale de baseline dintre acțiuni. Cere exact patru tranzacții și
patru refreshuri server, deja necesare confirmării UI. Nu se adaugă citiri la
rebuild, polling, listener sau scrieri de baseline în Firestore. Modelul de cost
rămâne conservator; nu este o măsurare live.

183 Dart și 14 SDK sunt ținte de validare până la CI real pe SHA publicat; 197
Python locale PASS. Home implicit, Restore complet, clienții vechi, hardware și
Spark live rămân distincte/necertificate. Nicio modificare rules/hashuri protejate,
producție, billing, date reale, merge ori instalare/distribuție APK.

### Control legacy al aceleiași integrări

28cfad0 a trecut Mission VIII #38845201516: 183 Dart, 47 JS emulator și 14 SDK
reale + raw Timestamp. Standard/platforme încă în verificare la acel checkpoint.
Proba legacy existentă este întărită separat pentru ramura TeamFinance a noului
callback: elimină observe manual dintre două încasări egale, cere exact două
refreshuri, păstrează opening balance 1, totalul 401 și ID-uri distincte. Nu este
un test duplicat și nu crește artificial numărul suitei. Sursa runtime nu se
schimbă în acest follow-up; CI final trebuie confirmat pe SHA-ul lui propriu.


## Restore țintit — certitudine după programarea scrierilor

Bază validată: 20f0ab4, toate cele patru workflowuri SUCCESS. Continuarea nu
schimbă mandatul sau limitele restaurării complete. Martorul RED 58aee8a,
Mission VIII #38847219264/job116800367806: 183 PASS / 2 FAIL reale. Un port care
comite apoi aruncă FinanceRefusal era raportat rejectedBeforeWrite; o reluare de
callback care observă un document schimbat după programarea anterioară a unei
scrieri era raportată conflict. Tipul excepției singur nu dovedește absența
scrierilor. Portul SDK avea deja protecția; interfața generică Restore nu o avea.

FinanceDemoRestore reține acum, peste toate callbackurile aceleiași apelări,
dacă s-a programat vreo scriere. Flagul se setează înainte de tx.write, inclusiv
pentru o metodă care aruncă. FinanceRefusal/FinanceRevisionConflict devin uncertain
cu finance_restore_uncertain după acel prag. Refuzul/conflictul strict înainte
de prima scriere rămâne distinct. Nu există retry financiar la nivelul aplicației,
rollback, rebase, confirmare inventată sau scriere suplimentară.

Cele două regresii noi acoperă excepții tipizate după commit (refuz și conflict)
și refuzul la reluarea callbackului după o scriere programată. Proba existentă de
receipt concurent este întărită cu exact o apelare și două callbackuri; rezultatul
public devine conservator uncertain. Aserțiunile zero scrieri și încasarea
concurentă păstrată rămân stricte. Schimbarea nu afirmă că fixture-ul a comis:
separă ceea ce poate dovedi fixture-ul de certitudinea permisă interfeței publice.

Ținte până la CI al SHA-ului corectat: 185 Dart, 14 SDK existente, 47 JS existente.
197 Python locale PASS. Home implicit, Restore complet, hardware și Spark live
rămân necertificate; production_ready=false. Nicio schimbare în rules, Home,
AuthGate, workflowuri, hashuri protejate, bani sau date reale.


## Recuperare locală înainte de o tentativă nouă pe aceeași țintă

Bază complet GREEN: 86e6a31. Defect nou, distinct de recuperarea deja testată:
într-o pagină care nu încărcase încă jurnalul, un dialog nou genera alt ID.
Prepare refuza corect ținta ocupată, fără apelare server, dar adaptorul păstra
Save-ul nou deoarece journalPending era true pentru intenția veche. Încărcarea
explicită ulterioară vedea digesturi diferite și nu putea atașa intenția originală.
Martor RED 1ad1226, Mission VIII #38848457561/job116804157228:
185 PASS / 2 FAIL reale, pentru intenție veche necomisă și comisă cu ack pierdut.

FinanceCoordinatedResult expune acum blockedByPendingIntent exclusiv pentru
refuzul prepare finance_unresolved_target. Acesta certifică numai că ID-ul nou
nu a fost stocat sau trimis; nu infirmă commitul intenției vechi și nu îi șterge
jurnalul. journalPending rămâne true. Adaptorul poate finaliza cu refuz cert
callbackul nou, eliberând numai Save-ul său pentru încărcarea explicită a celui
original. Erorile de storage/prepare, aceeași intenție incertă și cleanup-ul
confirmat nu primesc acest indicator și își păstrează protecțiile anterioare.

Cele două probe folosesc dialogul original, verifică zero tranzacții/citiri noi
la tentativa refuzată, rollbackul exclusiv al modelului tentativei noi, lipsa
auditului de succes și identitatea exactă a intenției vechi. Recuperarea explicită
nu execută intenția necomisă; cea comisă se confirmă prin marker+refresh și nu se
retrimite. Controlul coordinator existent este întărit pentru flag și jurnal;
controlul reluării aceleiași intenții cere flag false. O acceptanță nouă SDK reală
folosește butoanele originale pentru refuz, încărcare și reconciliere: exact două
tranzacții totale create+receipt vechi, un singur receipt/revizie 2 în server.

Ținte până la CI real: 187 Dart, 15 Flutter SDK, 47 JS emulator. 197 Python locale
PASS. Storage-ul harnessului este RAM; nu certifică restart OS sau hardware.
Zero auto-replay, polling, citiri la rebuild sau servicii noi. Home implicit,
Restore complet/inventar consistent, schema receivedEntries, compatibilitatea
clienților, hardware și Spark live rămân restanțe distincte; production_ready=false.
