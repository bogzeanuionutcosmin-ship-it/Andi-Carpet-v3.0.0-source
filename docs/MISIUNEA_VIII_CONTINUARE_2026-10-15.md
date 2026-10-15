# Misiunea VIII — continuare tehnică, 15 octombrie 2026

PR #55 rămâne Draft. Nu autorizează integrare, deploy, date reale, billing sau distribuție APK.
PR #50/#51/#52 sunt read-only și au fost reverificate la HEAD-urile f809b494, bc058bc9 și 950f736a.

## Dovezi de precizie

- `02884dd`: martor Dart real RED, 98 PASS / 1 FAIL în job 116545814562: Timestamp 123456789 devine 123456000. Încercarea precedentă `957f3ee` a avut un constructor de fixture incorect; nu este numărată drept reproducere.
- `cc8ddf5`: tipul pur FinanceTimestamp păstrează precizia la granița modelului și a jurnalului; 104 probe Dart și 47 emulator PASS. Proba browser singură nu separa precizia SDK de formatul efectiv stocat.
- `318a0c8`: adaptorul actualizează numai câmpurile schimbate și folosește arrayUnion pentru singura încasare nouă. Cele 6 probe browser au trecut; verificatorul raw a relevat că fixture-ul trebuie comparat cu starea server inițială.
- `dd592e3`: 104 Dart, 47 emulator și 6 Flutter SDK browser PASS; verificatorul JavaScript independent confirmă egalitatea exactă a celor trei timestampuri server înainte/după receipt și edit. Serverul emulator normalizează deja precizia la seed. Nu declarăm această normalizare drept defect demonstrat al datelor live.

## Restaurare țintită — candidat demo

`FinanceRestorePlan` este un manifest imuabil pentru maximum 20 de documente și 256 KiB serializat. Include snapshoturile așteptate, țintele financiare și markerii necesari pentru ultima revizie; refuză markerii orfani, lipsa dovezii și backupurile V1 reinterpretate tacit.

`FinanceDemoRestore` citește TOATE precondițiile în aceeași tranzacție înainte de prima scriere. O revizie, dovadă sau locație schimbată oprește întregul plan. Tranzacția nu rescrie și nu șterge niciun document financiar ori marker. Poate înlocui țintit numai documente deja enumerate din `locations`, `cars`, `documents`. Nu există ștergeri, batchuri succesive sau rebase automat.

Adaptorul este limitat la proiect demo și emulator local. Un refuz tipat este păstrat ca prewrite numai dacă niciun callback SDK nu a programat scrieri. Incertitudinea după o încercare sau după revocarea sesiunii nu este transformată în dovadă de nesalvare.

Acesta NU este restauratorul complet al aplicației. Manifestul nu exportă întregul inventar al colecțiilor/subcolecțiilor și nu migrează istoricul financiar. Tipurile Firestore fără reprezentare în model sunt refuzate. Vechile Restore manual/automat multibatch rămân KNOWN UNSAFE și nu sunt conectate la candidat.

## UI și identitate — harness

`FinanceDemoScope` compune repository + jurnal cu closure-ul real de proprietate primit de la AuthGate. Închiderea panoului invalidează și scope-ul; egalitatea UID nu reactivează un scope vechi.

`FinanceIntentDemoPanel` execută o intenție deja creată, cu ID stabil, și permite verificare server explicită. Rebuild, double tap, deschiderea panoului și reconstruirea jurnalului nu creează o intenție nouă și nu retrimit automat bani. Testele folosesc intrarea reală `AndiCarpetaApp.homeBuilder`, inclusiv A → B → A2 și o confirmare întârziată.

Harnessul nu înlocuiește Home/ExpensePage și nu certifică toate writepath-urile existente. Cele 28 de caracterizări VII nu sunt declarate reparate prin aceste probe separate.

Proba SDK cache/reconnect taie efectiv transportul printr-un proxy exclusiv loopback, deoarece disableNetwork singur nu a oprit tranzacțiile web. Folosește SDK real Chrome + emulator și jurnal injectat în memorie. Nu certifică persistență pe disc, restart de proces, secure storage fizic sau Android/iOS offline.

## Capacitate și Spark

Estimatorul Dart urmează formula oficială Firestore pentru valorile suportate, inclusiv nume UTF-8, document path, mapuri, liste, numere și timestampuri. Include `updatedAt` server. Refuză înainte de write o tranziție care depășește modelul de 1 MiB, fără trunchiere, ștergere, rotunjire sau plafon monetar nou.

Nu certifică indexuri, wire size, volumul live sau acceptarea tuturor documentelor sub prag. Serverul și Rules rămân autoritative. Limitele indexurilor și planul pentru paginarea istoricului necesită verificare înainte de producție.

Modelul Python și JSON-ul de scenarii separă stocarea totală de creșterea celui mai încărcat document. Exemplul sintetic de 20 receipts/zi într-o țintă, 1 KiB/receipt și 4 KiB inițiali, trece de rezerva internă de 512 KiB după 25 de zile complete. Este o ipoteză de scenariu, nu măsurare sau predicție a utilizării reale. Retenția pe cinci ani nu este resetată fictiv la fiecare an.

`production_ready=false` rămâne obligatoriu. Planul/baseline/indexurile/egress live sunt UNKNOWN. Nu există TTL, purjare de markeri, polling, listener sau serviciu plătit nou.

Surse: https://firebase.google.com/docs/firestore/storage-size și https://firebase.google.com/docs/firestore/manage-data/data-types .

## Verificare și restanțe

Pe 860e2e7 sunt demonstrate 116 probe Dart, 47 JS emulator, 8 Flutter SDK browser și verificarea JS raw. Pe 4333410 sunt demonstrate 125 probe Dart, inclusiv cele 9 probe UI. Pe 9f5e37a sunt demonstrate 129 probe Dart, inclusiv cele 4 probe de capacitate, și 47 JS emulator. Cele 192 teste Python locale au trecut după sincronizarea checkoutului. CI complet al HEAD-ului care publică acest checkpoint trebuie verificat separat; rezultatele finale și SHA/tree sunt raportate în descrierea PR #55, fără autocertificarea unui commit viitor.

Rămân blocante pentru integrare: toate fluxurile UI existente, Restore complet cu inventar/export/import, compatibilitatea clienților vechi, storage/restart pe dispozitiv fizic, deciziile legacy perDiem și verificarea consumului/planului live. Nici Issue #32, nici #53/#54 nu se închid pe baza acestui candidat.

Flutter local a fost blocat de auto-review pentru o încercare de acces la serviciul metadata al mediului; refuzul nu a fost ocolit. Validările Flutter sunt efectuate prin CI-ul existent din GitHub. Nu se solicită acces la credențiale sau metadata.


## Checkpoint de reluare

Cod sursă: `9f5e37ab67efa1b80af2db9a2cda7922e92a853e`. Audit read-only pe acest cod: 21 pinuri per ramură, 116 surse protejate, exact două fișiere comune cu #52, prefixele istorice păstrate și zero integrare. Raportul JSON include SHA exact.

Comandă: «Continuă PR #55 din HEAD-ul real și verifică CI-ul acelui SHA. Citește ChatGpt, acest raport și matricea VIII-14. Nu repeta probele validate și nu declara toate fluxurile vechi reparate. Urmează integrarea dialogurilor Home/ExpensePage în harness demo, Restore complet cu inventar și strategie compatibilă cu dovezile financiare imuabile, istoricul paginat și probe fizice numai cu autorizarea aferentă. PR #50/#51/#52 read-only. Fără merge, deploy, Firebase live, billing, instalare sau distribuție.»

## Continuare — callbackurile dialogurilor reale, candidat în verificare

`FinanceExpenseDemoAdapter` conectează semnăturile existente saveSettlement/saveFinance la scope-ul demo. Nu este activat în Home de producție. Cere o observație server fără cache/pending și un model inițial identic; păstrează baseline imuabil separat de modelele mutate de dialog. Extrage o singură acțiune receipt/edit/close, refuză schimbări mixte, înlocuirea istoricului și absența refreshului autoritativ. Create fără baseline rămâne refuzat explicit în acest adaptor; repository-ul separat suportă create.

După ack pierdut, conflict sau imposibilitatea refreshului, Future-ul callbackului rămâne în așteptare. Astfel dialogul real păstrează blocarea pe țintă și nu intră în rollbackul generic nesigur de close. Reconcilierea este numai explicită, cu același intent. Markerul confirmă operația; înainte de succesul UI este cerut separat snapshot server al țintei și înlocuirea modelului prin callback. Confirmarea markerului rămâne memorată dacă refreshul eșuează, fără resubmit sau dependență de un jurnal deja curățat. Un refuz proaspăt cert poate elibera callbackul cu FinanceSaveRejected. Scope-ul trebuie să fie același cu diagnosticSessionIsCurrent al paginii.

Cele șapte probe noi folosesc ExpensePage și dialogurile originale pentru receipt/close, plus refuzul observației cache. Nu repară automat Home implicit, create în acest adaptor, toate cele 28 de caracterizări vechi, restartul fizic ori clienții vechi. Sunt candidate până la verificarea CI pe SHA publicat.

### Gard în Restore-ul existent și extinderea adaptorului

Primul lot callbackuri, b2bb076: 136 probe Dart PASS, inclusiv cele șapte noi; 47 JS emulator PASS. Verificarea integrală a acelui HEAD continuă separat.

În lotul următor, Restore manual V1 și automat refuză întregul input care enumeră finance/settlements sau subcolecțiile lor, înainte de orice ștergere, batch ori marker de succes. Chiar și colecția financiară goală provoacă refuz: lipsa markerilor nu dovedește absența operațiilor. Backupurile istorice și exportul rămân nemodificate. Șase probe pe handlerii Admin reali verifică input mixt și zero mutații. Gardul nu certifică restaurarea operațională care omite finanțele și nu este un import complet.

Adaptorul adaugă intrarea explicită createSettlement pentru callbackul de creare: absența țintei este validată în tranzacția protocolului; niciun document existent nu poate fi înlocuit. Testul folosește dialogul Nouă real, commit urmat de ack pierdut și reconciliere fără o a doua scriere. Sunt adăugate și probele dialogului edit și ale conflictului de revizie. Modificările sunt candidate până la CI pe SHA publicat. Nu activează implicit Home și nu modifică cele 28 de caracterizări vechi.

### Recuperare vizibilă demo și bugetul refreshului

Wrapperul `FinanceExpenseDemoRecovery` afișează starea neconfirmată și butonul explicit «Verifică salvarea» lângă ExpensePage original. Ascultă notificările adaptorului; montarea și rebuildul nu citesc Firestore. Proba apasă butonul real și cere un marker server plus snapshotul țintei, cu un singur submit inițial. Scope-ul adaptorului trebuie închis de proprietar la disposal. O probă separată verifică dialogul legacy cu opening balance explicit și două încasări egale distincte.

Modelul Spark include acum și citirile de refresh autoritativ: în lipsa unui număr explicit estimează conservator una după fiecare operație și fiecare reconciliere, cu maximum zece accesări rules suplimentare per citire. Pentru 40 operații + 40 verificări pe zi: 3.960 reads/zi în model, din care 880 pentru refresh, și 80 writes/zi. Nu este limită măsurată; verificările manuale repetate trebuie incluse în input. Nu există polling/retry automat. Scenariile JSON sunt regenerate cu hashul nou al modelului. 194 teste Python locale PASS.

### De ce Restore complet rămâne blocat

Backupurile V1/automate nu enumeră registrul subcolecțiilor financialIntents și nu demonstrează un snapshot global. Tranzacția țintită protejează numai documentele enumerate, nu apariția altor documente în colecții. Un import complet cu înlocuire/ștergere ar necesita inventar complet consistent, coordonare cu toți writerii/clienții vechi și strategie de migrare aprobată; adăugarea unei scanări de colecții ori a unei blocări noi globale ar încălca sau extinde mandatul actual. Nu se introduc acestea tacit. Gardul fail-closed oprește sublotul nesigur, conform Issue #54 VIII-10; exportul istoric nu este reinterpretat ca dovadă completă. Gardul nu pretinde siguranță pentru restaurările operaționale fără finance/settlements.

Activarea implicită în Home rămâne condiționată de acest blocaj, compatibilitatea clienților și storage/restart fizic. Planul Spark și egress live nu pot fi deduse din cod sau emulator. Nicio instalare ori probă live nu este executată sub mandatul curent.

### Patru caracterizări Restore convertite în regresii după remedierea efectivă

Pe f1c6cf5: 147 Dart, 47 JS emulator, 8 Flutter SDK + verificator raw și 194 Python PASS. Standard și platforms au eșuat strict în patru caracterizări VII Admin-restore-versus-receipt: ele cereau vechiul delete+set și suprascrierea încasării, iar gardul nou a produs zero batchuri. Testele nu au fost șterse/skipuite: aceiași handleri, ambele colecții și ambele ordini de commit verifică acum refuz explicit, zero tentative de batch, zero scrieri directe, zero audit de succes și păstrarea încasării. Aceste patru cazuri sunt remediate prin REFUZUL restaurării financiare; nu certifică un Restore complet. Celelalte 24 de caracterizări rămân neschimbate. Rezultatele integrale trebuie verificate pe următorul HEAD.

### Izolarea fixture-ului Admin în Chrome

Pe b56a017 Standard a trecut 5/5 (751 Flutter, 194 Python, build web), identity și Mission VIII au trecut; platformele au trecut 161 Auth/Vision și 329 finance VM. Chrome a trecut 309/315, cele șase eșecuri fiind noile fixture-uri Admin. Dashboardul Admin construiește un client Mapbox implicit, incompatibil cu no_default_http_client; fixture-urile financiare existente îl izolau deja prin http.runWithClient. Noile șase probe primesc aceeași izolare, cu aserțiuni suplimentare zero HTTP și zero acces Firebase implicit. Niciun client implicit nu este reactivat, niciun test nu este skipuit și nicio aserțiune de refuz/zero mutații nu este relaxată. Compilarea Android nu a rulat pe acest SHA deoarece Chrome a oprit jobul; urmează validare completă pe noul HEAD.

## Continuare 16 octombrie — recuperare după recrearea scope-ului

Checkpoint inițial verificat: 723ab5548fbe550bc482a2dcffc1d54836176224, tree 6d787c1e4f4fd135fa6e06090e0bd5298abb8f0e; toate cele patru workflowuri active SUCCESS. Următorul lot completează recuperarea adaptorului după închiderea/recrearea ecranului: operatorul poate încărca explicit jurnalul local, apoi verifica fiecare intenție existentă. Încărcarea nu generează ID, nu execută tranzacție și nu citește serverul. Întregul manifest local este verificat înainte de atașare, cu maximum 32 ținte, fără ștergerea jurnalului corupt sau preluarea jurnalului altui UID. Reconcilierea rămâne numai server-read și nu retrimite tranzacția.

Patru probe noi candidate: aceeași intenție lost-ack după recrearea paginii, intenție încă necomisă fără execuție, jurnal corupt fail-closed, izolarea altui proprietar. Noua pagină înlocuiește modelul din server fără a fabrica auditul de succes al dialogului dispărut. O probă SDK suplimentară folosește Auth și Firestore reale în emulator: create comis, ack pierdut efectiv după commit, scope nou, același ID/digest, reconciliere și exact o tranzacție. Este recreare în același proces cu storage injectat; nu certifică restart OS sau secure storage fizic. Rezultatele se verifică pe SHA publicat, fără a declara probele PASS înainte de CI.

Nu există activare în Home implicit, import financiar complet, migrare, deploy, instalare APK sau modificare live. Blocajele de release rămân cele descrise mai sus; Issue #54 cere oprirea numai a subloturilor care nu pot fi probate sigur.

### Validarea legăturilor manifestului Restore

Pe db4e2f5, 151 Dart și 9 probe SDK reale + verificator raw PASS; 47 JS emulator PASS. Manifestul țintit este întărit separat: teamId valid, finance/documentId legat de echipă, revizie între 0 și limita exactă JavaScript, fără lastOperationId la revizie zero. Fiecare marker enumerat trebuie să aibă operationId/path/team coerente, actor valid, kind cunoscut, digest SHA-256 în format corect, baseRevision întreg și revision=base+1, fără a depăși revizia țintei. Câmpurile necunoscute sunt refuzate; finance legacy acceptă numai markeri receipt. Formatul digestului nu este prezentat drept recalculare criptografică fără intenția originală.

Trei probe noi candidate acoperă legături falsificate/malformed, limitele reviziilor și păstrarea simultană a markerilor istorici + cel mai recent în tranzacția țintită. Fixture-ul folosește acum schema completă reală a markerului. Schimbarea nu inventariază markerii neenumerați, nu declară complet un backup și nu permite scriere/ștergere financiară. CI pe noul SHA rămâne obligatoriu.

### Limită UI și portabilitate

Lista de recuperare este scrollabilă și ocupă o porțiune bounded a ecranului, fără a scoate ExpensePage din zona sa scrollabilă. O probă suplimentară încarcă toate cele 32 de intenții pe 320×480, ajunge la ultima fără overflow și cere zero execuții/citiri server. Martorul de baseRevision fracționar folosește 0.5 pe VM și Chrome; nu depinde de distincția runtime dintre un double integral și int în JavaScript. CI final și SHA/tree exacte sunt consemnate în PR după încheiere, fără a certifica un commit viitor aici.

Proba bounded UI de pe 11aaca0 a trecut încărcarea celor 32 și verificarea fără overflow, dar nu a ajuns la ultimul element în bugetul implicit de 50 gesturi ×100px; helperul a încheiat cu No element. Fixture-ul folosește acum maximum 100 gesturi ×250px și cere explicit ultimul element hitTestable, nu doar existent în arbore. Limita jurnalului, numărul celor 32 operații și aserțiunile zero SDK/overflow rămân neschimbate. Celelalte 154 probe Dart au trecut pe acel SHA; proba UI se revalidează pe noul commit.

Pe 491c404, navigarea ajunge la ultimul banner, dar aserțiunea hitTestable pe container nu dovedește accesibilitatea acțiunii sale. Proba vizează acum butonul ultimei operații, îl aduce în viewport și îl apasă efectiv: înainte de apăsare zero server reads, după apăsarea explicită exact un marker-read, zero tranzacții și toate cele 32 cereri necomise păstrate. Nu este eliminat testul de interacțiune; verifică acum controlul operabil, cu aceleași limite de ecran și de jurnal. Celelalte 154 probe Dart au trecut; următorul CI validează controlul.

## Continuare spre misiunea integrală — registru Admin paginat

Checkpoint de pornire: 02efbebb87099ccfb672a339a8ad1db4f5fa078d, toate cele patru workflowuri active SUCCESS. Adăugat candidat exclusiv demo, read-only, pentru maximum 20 de markeri ai unei singure ținte per pagină. Prima cerere citește ținta din server și fixează revizia superioară; paginile următoare folosesc revision ≤ următoarea revizie așteptată, orderBy descendent și limit. Nu există offset, listener, polling, încărcare automată a paginii următoare sau scanare globală de colecții. Panoul reține numai pagina curentă și afișează tipul operației/revizia, fără actorUid, operationId ori valori monetare.

Cursorul este legat de instanța readerului și de sesiunea AuthGate. Markeri lipsă, duplicați, nepotriviți cu ținta/echipa/ID/revizia, cache sau pending sunt refuzați. O operație adăugată după prima pagină nu schimbă revizia fixată. «Complet» înseamnă numai secvența markerilor 1..revizia fixată, nu backup complet, snapshot global sau dovadă pentru bani legacy fără markeri. Array-ul receivedEntries și creșterea lui spre limita de document nu sunt migrate de acest cititor.

Permisiunea existentă list pentru financialIntents rămâne exclusiv Admin. Nu se slăbește firestore.rules. Proba SDK candidată cere refuz permission-denied pentru manager, apoi Admin citește [3,2], se comite revizia 4 între pagini și Admin citește [1] pe cursorul vechi; o deschidere explicită nouă vede [4,3]. Sunt adăugate 8 probe pure și 3 widget (cereri exclusiv explicite, double tap, revocare/disposal), plus o probă SDK reală. Rezultatele necesită CI pe noul HEAD.

Costul static include separat primele pagini și paginile următoare. La 20 elemente/pagină, 2 deschideri + 3 pagini ulterioare pe zi estimează 1.122 document/rules reads suplimentare și zero writes: 5×20×11 + 2×11. Index reads, egress și baseline live rămân neverificate. Modelul poate refuza scenarii care depășesc rezerva internă; nu există activare automată pe baza lui. 197 Python locale PASS; JSON de scenarii regenerat cu hashul modelului. Nicio modificare de index/deploy/plan/billing.

Referință oficială consultată: https://firebase.google.com/docs/firestore/query-data/query-cursors — paginare/range/order/limit. Validarea reală a query-ului, ACL și concurenței este separată, în emulatoare. Blocajele pentru Home implicit, Restore complet, schema istoricului monetar, clienți vechi, hardware și Spark live rămân explicite.
