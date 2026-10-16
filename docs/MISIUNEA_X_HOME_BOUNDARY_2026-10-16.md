# Misiunea X — opt-in Home boundary / DO NOT MERGE

Issue #77. Bază verificată PR #73: 4cd6ee522534b6e5edd45d6112ddadf23c418bac.
Working tree inițial curat. production_ready=false. Nicio modificare în Home,
AuthGate, main, pini, PR73/74/75 sau producție.

## X-01 — matrice exactă de writeri

| Flux | Intrare → persistență | Identitate / stare / risc |
| --- | --- | --- |
| create | expense_settlement_actions._createSettlement → saveSettlement → Home._saveSettlementDirect | idNow; set merge; fără CAS; succes/audit după Future, nu marker |
| edit / close / reopen | _editSettlement / _toggleSettlementClosed → același callback | obiect comun optimist; rollback sigur doar la FinanceSaveRejected; eroare generică close poate inversa starea |
| receipt settlement / legacy | _money → saveSettlement / saveFinance | ID local nou; listă și agregate mutate; set merge poate pierde alt receipt |
| manager / rate | expense_per_diem_actions → saveSettlement / saveFinance | același callback, semnificație diferită; nu sunt acoperite de protocolul receipt/edit/close |
| bootstrap finance | ExpensePage finance fallback → model TeamFinance | lipsa documentului nu autorizează creare financiară implicită |
| OCR/manual expense / confirm | expense_document_actions → saveExpense → Home._saveExpenseDirect | set merge + cache după await; reguli candidate separate; fără jurnal de intenții pentru acest flux |
| perDiems distribute | savePerDiem → Home._savePerDiemDirect | create-if-absent transaction, ID nou după intenție nouă; Learning/cache după await |
| perDiems receipt/refusal | același writer → tranzacție update + receiptAudit | beneficiar UID verificat; nu unificat cu v2; avans păstrat |
| per_diem_settlements_v2 | PerDiemFirestoreRepository | revizie/audit separat; nu convertit prin noul seam |
| Admin delete / backup / restore | admin_operations_actions / admin_backup_actions | delete expense separat; gard financiar pre-write; V1 nu inventariază financialIntents |

Home instanțiază ExpensePage în home_page.dart:358; diagnosticSessionIsCurrent
folosește sesiunea Home. Gate UI nu înlocuiește ACL server. Listener-ele Home,
cache-urile și modelul mutabil nu dovedesc confirmarea unei intenții. Learning
și auditul UI rămân în afara tranzacției; nu trebuie emise la rezultat incert.
Adaptorul nou trebuie legat de UID+generation+echipă, checked secure journal,
server observation și înlocuire de model înaintea finalizării callbackului.

## Dovezi preflight

Patru workflowuri PR73 SUCCESS: Standard 38857937421, Identity 38857937361,
Finance IX 38857937305, Platforms IX 38857937304. Acestea sunt baza, nu CI X.
Fixture-uri refolosite: ExpenseDocumentFixture, FinanceAtomicFixture, probele SDK
VIII/IX, checked journal IX. Nu numărăm din nou acceptanțele IX ca remedieri X.

## X-02/03/04/09 — candidat nou, înainte de CI

FinanceHomeCandidate reutilizează coordinatorul și adaptorul existent; storage
este învelit obligatoriu în checked journal. Constructorul nu face I/O. Callbackul
saveSettlement distinge țintele observate de CREATE atomic; o țintă existentă
neobservată produce conflict, nu overwrite. UID+generation+team closure este
monotonă inclusiv la excepții. Modelul altei echipe este refuzat înainte de I/O;
jurnalul UID care conține altă echipă blochează recuperarea fără ștergere/adoptare.
Nu există fallback la legacy, timer, retry sau activare Home implicită.

Nouă probe Flutter candidate: 3 formate de sumă cu create/receipt/edit/close/open,
anulare/rebuild/dublu click, commit întârziat și revocare, recuperare cu obiect
nou, echipă străină și conflict pe țintă existentă neobservată. Fixture-ul este
ExpensePage real; portul acestor probe este fake determinist. O probă SDK nouă
folosește Auth/Firestore emulator + secure-storage web plugin real, create și
receipt cu ack pierdut, apoi compoziție nouă și reconciliere explicită fără send.
Controalele VIII/IX rămân în același entrypoint. Nu este restart browser/OS.

CI IX este extins DOAR la predicatul ramurii X, păstrând toate comenzile și
controalele. 199 teste Python locale PASS. Rezultatele Flutter/SDK/platforme
rămân CANDIDATE până la CI pe SHA nou.
