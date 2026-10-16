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
