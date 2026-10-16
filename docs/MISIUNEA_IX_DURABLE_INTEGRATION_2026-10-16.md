# Misiunea IX — integrare durabilă izolată / DO NOT MERGE

Issue #72. Bază PR55 0b20afdf2b88670b684d072223b63e021327101e,
tree 3b644ca095e8b39b5bb9287a0ba232ddb8bb4af8. Cele patru workflowuri de
referință SUCCESS; nu sunt rezultate pentru IX. production_ready=false.
Ramură nouă fix/finance-durable-integration-mission-ix-20261016.
PR55, main, PR50–52 și PR71 sunt read-only. 116 surse/21 pini rămân înghețați.

## IX-01 — inventar și diferența față de VIII

| Intrare / ieșire reală | Persistență / stare | Acoperire VIII și lipsă IX |
| --- | --- | --- |
| ExpensePage create/edit/close/receipt | expense_settlement_actions → callback saveSettlement/saveFinance | SDK cu dialog original există; factory Home implicită lipsește |
| Home._saveSettlementDirect/_saveFinanceDirect | home_financial_write_actions: set merge, Learning după await, cache finance | Fără marker/revizie atomică; KNOWN UNSAFE pentru protocol |
| ExpensePage manager/rate | expense_per_diem_actions: mută managerId/perDiemRate, saveSettlement/saveFinance | Adaptorul demo refuză finance_unsupported_action; nu poate înlocui mecanic Home |
| Bootstrap finance | document finance/{teamId} și model fără revizie | Intent finance acceptă numai receipt; create necesită contract distinct |
| Cheltuială OCR/manual/confirmare | expense_document_actions → _saveExpenseDirect set merge și cache | ACL candidat există; fără jurnal operationId pentru aceste acțiuni |
| Distribuire/suplimentare perDiems | idNow, _savePerDiemDirect tranzacție create-if-absent | Nu este protocol VIII, ID nou după rezultat incert rămâne risc |
| Răspuns beneficiar perDiems | tranzacție update + receiptAudit | Nu se unifică cu v2; avansul nu este plafonat tacit |
| per_diem_settlements_v2 | PerDiemFirestoreRepository: revizie + audit, declare/ack/dispute | Schemă separată, fără rescriere/migrare |
| Home listeners | snapshots fără metadata de confirmare | Snapshot UI nu este dovada intenției proprii |
| Admin delete expense | admin_operations_actions: delete + log după await | Fără protocol VIII; contract corecție/ștergere distinct |
| Admin restore manual/automat | admin_backup_actions: gard finance/settlements înainte de mutații | V1 omite financialIntents; fără snapshot global consistent |
| Admin targeted demo restore | FinanceRestorePlan: precondiții pe documente enumerate | Nu scrie finanțe/markeri; nu dovedește inventar complet |

Fixture-uri reutilizate, fără reimplementare: FinanceAtomicFixture,
FinanceIntentJournal/Coordinator, SdkExpenseUi + ExpenseDocumentFixture,
ObservedPort și proxy offline al VIII. Acceptanțele VIII rămân controale,
nu sunt numărate din nou ca remedieri IX.

| Client / rules din repo | Rezultat |
| --- | --- |
| Legacy / main 377f1fd | Merge fără invarianta marker/revision: KNOWN UNSAFE |
| Legacy / candidat VIII | Salvări legitime fără marker refuzate: BLOCKED rollout |
| Nou / main | Protocolul client nu obligă writerii vechi: BLOCKED rollout |
| Demo nou / candidat VIII | SDK probează numai acțiunile acoperite, nu Home |
| Home legat mecanic la demo | Manager/rate/bootstrap neacoperite: BLOCKED |

Regulile live, planul, baseline, indexurile și egress rămân UNKNOWN.

## IX-02 — contract de storage și limite

Reutilizăm portul FinanceJournalStorage și jurnalul VIII. Un înveliș local nou
verifică owner, schema, checksum și citirea exactă după write înainte de send.
Nu introduce retry, delete/deleteAll, listener, timer sau migrare automată.
Hashul detectează corupere accidentală; nu înlocuiește criptarea/autorizarea.
Un write care aruncă, chiar dacă a salvat, nu autorizează send în acel apel.
Un cleanup care aruncă nu infirmă confirmarea financiară deja primită.

flutter_secure_storage 11.2.0 este deja în lockfile. Surse autor:
https://pub.dev/packages/flutter_secure_storage/versions/11.2.0
https://pub.dev/packages/flutter_secure_storage/changelog
Pachetele exacte 11.2.0 și web 2.1.1 au fost inspectate: web criptează prin
WebCrypto și folosește localStorage.setItem; readback nu dovedește fsync sau
persistență după pierderea energiei. Web necesită context sigur/localhost;
ștergerea datelor browserului, profil privat și quota rămân limite reale.
AndroidOptions implicit resetOnError=true este nepotrivit pentru dovadă
financiară: compoziția candidat dezactivează resetul și migrarea algoritmului.
Nu schimbă configurarea aplicației implicite sau alte chei de storage.
Windows 4.2.2 și Darwin 0.4.3 sunt în lockfile; fără probe hardware nu sunt PASS.

Serializarea jurnalului VIII este per UID în același isolate. Secure storage
nu oferă CAS/lock pentru întreaga secvență read-modify-write între taburi,
procese sau isolate-uri. Învelișul este candidat single-writer explicit demo,
NU certificat multi-process. Nu se activează în Home/producție pe baza readback.
Payload vechi neînvelit se refuză cu upgrade_required fără migrare/ștergere.
Coruperea se păstrează și blochează trimiterea; nu este tratată drept jurnal gol.
Limita payload rămâne 128 KiB/32 intenții, fără evacuarea celor incerte.
