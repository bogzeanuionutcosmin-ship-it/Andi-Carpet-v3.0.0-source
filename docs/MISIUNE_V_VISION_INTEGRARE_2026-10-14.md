# MISIUNEA V — Vision V0.8 în Home modularizat cu AuthGate P1

## Mandat și freeze

Issue #37 autorizează integrarea/testarea numai pe o ramură nouă din PR #35. Bază b2b13147cb62ec2904a0bbab4f014fc83130c4c5 (#35), sursă read-only Vision 5f316eaa6617fa5450d34893b77ef939df1c85ac (#34). #28 fd602ed4bd727e2c2b41cf24ac988a818a2564ff, #29 545e0202755a8ee86a7b3406adccd469aac84f9e, #36 b2b1314; main nu se modifică. Checkout nou separat, curat la început. Nu repetăm RED/fixurile Misiunii IV.

Ramură integration/vision-authgate-modular-20261014. Un singur PR Draft TEST/INTEGRATION DO NOT MERGE, cu BASE main exclusiv pentru triggerurile standard/identity existente. Fiecare checkout merge-ref trebuie să aibă tree identic cu HEAD integrat. #36 nu este reutilizat/editat.

## Matrice de portare selectivă

| Sursă #34 | Destinație / decizie |
|---|---|
| lib/vision/* | 11 biblioteci independente: log, telemetry, persistence queue/status/lifecycle, advisor/report/coverage/UI, verifier pur |
| test/vision_*_test.dart | 9 suite existente, fără slăbirea aserțiunilor |
| main bootstrap | adaptor minim peste bootstrap #35; păstrează politicile Firebase și handlerii existenți |
| Home FCM/GPS monolitic | hookuri constante în home_push_notifications/home_live_location, păstrând ownership după await |
| Home diurne monolitic | hook sync_failed în home_financial_sync, fără schimbare queries/scopes |
| Expense monolitic | hookuri numai în expense_settlement_actions/expense_per_diem_actions/expense_document_actions |
| Vision operational source contract | adaptare strictă la module reale; unicitate/coduri constante/guards |
| Panou Vision | bibliotecă locală testabilă; nicio rută publică nouă, deoarece drepturile device-wide între conturi nu sunt aprobate |
| VisionExpenseSaveVerifier | pur și neconectat; zero Firestore reads/retry/confirmări |
| PDF/OCR/parser/versions/workflows #34 | nu se importă; păstrăm fluxurile și hashurile #35 |

Overlap-urile main/Home/Expense/OCR/teste/workflow/assets/documente sunt reconciliate prin selecție de căi, nu prin merge/cherry-pick #34. Niciun monolit runtime importat și cele 59 parts sunt păstrate.

## Lot 1 — nucleu și teste importate

Cele 11 module și cele 9 suite Dart Vision sunt byte-identice sursei freeze #34. În acest lot bootstrap/hookurile nu sunt încă active, iar panoul este numai în teste. Log runtime:150 intrări/48KiB/7zile; restore-before-write, coadă serială, fallback RAM/status explicit, lifecycle flush; fără Firebase/rețea/LLM/permisiuni noi. Raportul este Clipboard numai la gest; verifier-ul nu este conectat la aplicație.

CI pe SHA lot este obligatoriu înainte de bootstrap/hookuri; rezultatele și arborii se consemnează după execuție. Baseline 294Flutter/158Python/3Node/10financial+5identity, AuthGate12+8 și protected116 rămân.

## PDF: discrepanță de inventar preexistentă

În #35 nu există assets/pv_million.pdf; există assets/pv_magic.pdf SHA256 eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b. Million există numai în sursa #34 și hashul original din mandat este 3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23. Misiunea interzice importul accidental al fluxurilor PDF: nu adăugăm assetul sau logica PDF pe această ramură. Conservăm byte-exact inventarul #35, verificăm separat hashul original al sursei, iar integrarea documentelor rămâne distinctă. Nu pretindem că Million este prezent aici.

## Limite

Fără merge/deploy/APK publicat/instalat/web publicat/producție/role rights/finanțe/OCR/START-STOP/backup/migrare/Learning/billing. Panoul device-wide nu autorizează accesul unui alt cont; expunerea producție rămâne decizie explicită de permisiune. Hardware/autentificare/Firebase live NEEXECUTATE. Android se compilează în CI numai dacă runnerul permite, fără upload/distribuire de APK.
