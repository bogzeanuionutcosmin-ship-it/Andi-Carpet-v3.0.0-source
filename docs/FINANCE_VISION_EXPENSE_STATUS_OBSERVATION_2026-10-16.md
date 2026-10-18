# Finance IX × Vision — diagnostic opțional în dialogul ORIGINAL ExpensePage

16 octombrie 2026. **Draft separat / DO NOT MERGE / production_ready=false.**

## Bază și nevoie

Acest lot pornește numai din PR #75 (`fd355d6b542d9ad0e2c5db4e8847e8da4a8d96ec`), care compune PR #73 al Lunei cu porturile Vision. La momentul creării acestei ramuri, Finance IX 3/3, Identity și Standard 5/5 aveau SUCCESS pe acel SHA; Chrome finance era SUCCESS în jobul Platform IX, iar Android main debug era încă în execuție. Nu se declară acel job verde înainte de finalizare.

În PR #75 `FinanceVisionOutcomeObserver` exista, dar nu era legat de fluxul de salvare al dialogului original ExpensePage: evenimentul era generat numai din teste directe ale coordinatorului. În continuare NU se intervine în Home sau în callbackurile implicite de producție. Se pune o probă de integrare reală, opțională, în adaptorul de **DEMO** deja existent pentru ExpensePage.

## Modificări

- `FinanceVisionOutcomeObserver.observeStatus` acceptă exclusiv `FinanceIntentStatus`, `VisionScopedSignalSink` și platforma enum. Metoda veche `observe(result:...)` rămâne delegant compatibil pentru testele existente. Codul rezultatului, UID, operationId, sume, documente și erori brute nu sunt citite/transmise de adaptorul Vision.
- `FinanceExpenseDemoAdapter` primește opțional `void Function(FinanceIntentStatus)? observeStatus`, fără a importa Vision și fără schimbarea constructorilor existenți. După rezultatul coordinatorului și validarea `sessionIsCurrent`, trimite exclusiv status-ul prin callback. Dacă observerul aruncă, rezultatul financiar rămâne neschimbat; dacă observarea revocă sesiunea, adaptorul nu continuă actualizarea UI după invalidare. Callbackul NU primește un `FinanceIntentResult`.
- Se adaugă **două acceptanțe widget la dialogul original** în `test/finance_intent_expense_adapter_test.dart`: (1) încasare pe server cu ACK pierdut → un avertisment Vision `finance/operation_uncertain/android`, reconciliere explicită confirmată fără a doua tranzacție/încasare sau diagnostic de succes, apoi revocare; (2) observer care aruncă nu întrerupe salvarea confirmată și nici nu produce dubluri.
- Workflowurile Finance IX emulator/Dart/SDK și IX Platforms sunt activate și pentru ramura aceasta; restul pașilor/condițiilor identici. Standard și Identity testează același HEAD.

## Ce NU dovedește / ce este blocat

Home implicit, `main.dart`, `lib/auth/`, `lib/home/`, regulile Firebase, scrierile/backupurile reale și cele 116 surse înghețate sunt nemodificate. `FinanceExpenseDemoAdapter` rămâne **numai harness**. Nu este implementată conversia manager/rate, bootstrap-ul, fluxul legacy complet sau compatibilitatea clienților vechi. Jurnalul financiar durabil IX nu este dovadă hardware ori multi-proces doar din aceste widget tests. Jurnalul Vision nu este jurnal financiar și nu confirmă tranzacția.

**Costul fluxului de diagnostic în plus:** zero citiri/scrieri Firestore, transport, billing, polling sau AI cloud. Probele financiare existente au tranzacțiile și readback-ul lor normal; observerul însuși este pur local.

Fără merge în main/PR #55/#73/#74/#75, deploy Firebase, activare reguli candidate, migrare de date, instalare/distribuire APK sau publicare web. Nu se consideră gata de lansare înaintea unui arbore efectiv conectat și auditului de hardware/Spark.

## Validare necesară pe HEAD-ul final

- Standard CI 5/5; Identity; Mission IX 3/3; Platforms Chrome/Android compile-only; pini 21/116; fără suite RED ascunse.
- Un FAIL se remediază prin commit nou distinct, verificat pe propriul SHA.
- Toate joburile `SKIPPED` sunt documentate ca atare, niciodată PASS.
