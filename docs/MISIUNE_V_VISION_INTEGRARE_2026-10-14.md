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


## Lot 1 validat

Commit b35be65f29952f66271e04addcdbf99850998343. Standard 38637194546 SUCCESS 5/5:390Flutter,158Python,3Node,Functions,financial10,smokeDart/web. Identity38637194426 SUCCESS5PASS. Merge-ref PR38 daf3ed12811143d0b360ca1913280efdba389040 / tree95b66651623dc7c19a03e8e3a0ee9df3f6d9358b identic HEAD. 96 teste Vision importate, cele294 originale și12+8AuthGate intacte. Million source SHA256 original verificat, assetul nu este portat.

## Lot 2 — conectare observațională

Bootstrap unic în main, înainte de Firebase: install handlers idempotent și restore non-blocking best-effort. Handlerii Flutter/Dart anteriori sunt înlănțuiți, nu suprascriși semantic; dacă async nu avea handler, false păstrează eroarea nehandled. Datele brute/stack/runtimeType nu intră în jurnal: doar framework_error/uncaught_error constante. Jurnalul colectează RAM înainte de bootstrap; numai initialize explicit activează stocarea/debounce. Astfel, un widget încorporat/test nu pornește I/O platformă implicit. Startup Firebase failure are un cod constant separat.

13 hookuri unice, constante, în cele6 module reale Home/Expense. Home păstrează toate guardurile și verifică ownerul în error callbacks; Expense primește doar diagnosticSessionIsCurrent opțional, furnizat din ownership Home. Acest seam controlează exclusiv înregistrarea observației, nu acordă drepturi și nu modifică financial save/confirm/retry. Modulele Expense actions reconstruiesc byte-exact baza #35 după eliminarea celor7 hookuri, dovedit prin hashuri Python; parserul și fluxurile de form/save rămân.

7 teste Flutter noi: bootstrap fără blocaj/failure, handler chaining/idempotence/sanitization,2 contexte UI A→B→A/logout cu sheet/route/SnackBar/copy explicite, realHome GPS/FCM/diurnă once/no-sensitive-payload, lateFCM error A respins înainte de dispose și OCR recognition/save once/no-retry. Panoul rămâne numai context intern/test cu log injectat; nu adăugăm acces device-wide sau buton public, deoarece politica de vizibilitate nu este aprobată. Verifier-ul rămâne neconectat.

Source contract #34 este adaptat la modulele efective fără eliminarea celor5 aserțiuni anterioare; două contracte suplimentare cer unicitate/ownership/coduri fixe/zero public route și zero verifier wiring. Un test Python suplimentar demonstrează inversion financiar/OCR.166PythonPASS local. CI pe SHA lot și Android se raportează după execuție.

Android: un workflow NOU compile-only, limitat prin head_ref la PR38, fără modificarea workflow-urilor protejate. Rulează teste Vision/AuthGate și compilează lib/main.dart real, fără secrets/token/Google Services modificat, fără artifact upload/instalare/deploy. Este compilare, nu hardware sau login Firebase live.
