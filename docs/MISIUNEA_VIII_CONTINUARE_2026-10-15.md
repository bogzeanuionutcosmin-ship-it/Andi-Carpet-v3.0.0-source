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
