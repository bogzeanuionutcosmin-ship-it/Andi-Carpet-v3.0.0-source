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

Proba SDK disableNetwork/cache/reconnect folosește transportul real Chrome + emulator și jurnal injectat în memorie. Nu certifică persistență pe disc, restart de proces, secure storage fizic sau Android/iOS offline.

## Capacitate și Spark

Estimatorul Dart urmează formula oficială Firestore pentru valorile suportate, inclusiv nume UTF-8, document path, mapuri, liste, numere și timestampuri. Include `updatedAt` server. Refuză înainte de write o tranziție care depășește modelul de 1 MiB, fără trunchiere, ștergere, rotunjire sau plafon monetar nou.

Nu certifică indexuri, wire size, volumul live sau acceptarea tuturor documentelor sub prag. Serverul și Rules rămân autoritative. Limitele indexurilor și planul pentru paginarea istoricului necesită verificare înainte de producție.

Modelul Python și JSON-ul de scenarii separă stocarea totală de creșterea celui mai încărcat document. Exemplul sintetic de 20 receipts/zi într-o țintă, 1 KiB/receipt și 4 KiB inițiali, trece de rezerva internă de 512 KiB după 25 de zile complete. Este o ipoteză de scenariu, nu măsurare sau predicție a utilizării reale. Retenția pe cinci ani nu este resetată fictiv la fiecare an.

`production_ready=false` rămâne obligatoriu. Planul/baseline/indexurile/egress live sunt UNKNOWN. Nu există TTL, purjare de markeri, polling, listener sau serviciu plătit nou.

Surse: https://firebase.google.com/docs/firestore/storage-size și https://firebase.google.com/docs/firestore/manage-data/data-types .

## Verificare și restanțe

La pregătirea acestui document, noile harnessuri Restore/UI/offline și gardul de capacitate sunt încă în validare. Rezultatele finale și SHA/tree se citesc din descrierea PR #55 și din workflowurile acelui SHA; numerele nu se certifică anticipat.

Rămân blocante pentru integrare: toate fluxurile UI existente, Restore complet cu inventar/export/import, compatibilitatea clienților vechi, storage/restart pe dispozitiv fizic, deciziile legacy perDiem și verificarea consumului/planului live. Nici Issue #32, nici #53/#54 nu se închid pe baza acestui candidat.

Flutter local a fost blocat de auto-review pentru o încercare de acces la serviciul metadata al mediului; refuzul nu a fost ocolit. Validările Flutter sunt efectuate prin CI-ul existent din GitHub. Nu se solicită acces la credențiale sau metadata.
