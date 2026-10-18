# MISIUNEA V — Vision peste AuthGate P1 și Home modularizat

Issue #37 · 14–15 octombrie 2026 · PR #38 Draft TEST/INTEGRATION — DO NOT MERGE

## Mandat, bază și freeze

Ramura nouă `integration/vision-authgate-modular-20261014` pornește exclusiv din PR #35 `b2b13147cb62ec2904a0bbab4f014fc83130c4c5`. PR #38 țintește main numai pentru a declanșa workflow-urile standard și identity existente. Nu s-a făcut merge și nu s-a folosit/modificat bridge-ul #36.

Sursa nucleului Vision este PR #34 `5f316eaa6617fa5450d34893b77ef939df1c85ac`. În timpul lucrului, #34 a avansat extern la `325b44e6983bc8db50f6a16946b41a3527b0b0e6`: șase commituri schimbă numai pagina de diagnostic, testele ei și raportul. Am analizat diferența și am adoptat selectiv doar pagina/testele cu protecțiile noi de confidențialitate. Celelalte module folosesc freeze-ul inițial și adaptoarele documentate aici. Nicio ramură sursă nu a fost editată.

Surse protejate: #28 `fd602ed4bd727e2c2b41cf24ac988a818a2564ff`, #29 `545e0202755a8ee86a7b3406adccd469aac84f9e`, #35/#36 `b2b1314`, main `377f1fd5e73ae78a0df5cab58b09770c873cd167`. Checkoutul nou este separat; Misiunile III/IV nu au fost repetate.

## Matrice de portare

| Sursă #34 | Destinație și limită |
|---|---|
| `lib/vision/*` | 10 biblioteci independente plus adaptorul nou `vision_bootstrap.dart`; niciun monolit importat |
| Nouă suite Dart Vision | Teste portate fără slăbirea aserțiunilor; pagina/testele UI folosesc refresh-ul de securitate 325b44e |
| Bootstrap main | Trei importuri și un apel de pornire înainte de Firebase; cod constant pentru eșecul inițializării Firebase |
| FCM Home monolitic | Două hookuri în `home_push_notifications.dart` |
| GPS Home monolitic | Trei hookuri în `home_live_location.dart` |
| Sincronizare diurne Home | Un hook în `home_financial_sync.dart` |
| Salvări Expense monolitice | Șapte hookuri în `expense_settlement_actions.dart`, `expense_per_diem_actions.dart`, `expense_document_actions.dart` |
| Contract Python operațional | Verifică modulele reale, unicitatea, codurile constante și ownership; păstrează cele cinci verificări inițiale |
| Pagina Vision | Numai context intern/test; fără rută publică nouă și fără acces la jurnalul comun dispozitivului |
| Expense verifier | Pur și neconectat; zero citiri/scrieri Firestore, retry sau confirmări financiare |
| PDF/OCR/parser/versiuni/workflow-uri #34 | Nu sunt portate; păstrăm inventarul și comportamentul #35 |

Overlap-urile main/Home/Expense/OCR/teste/workflow/assets/documente sunt reconciliate prin selecție de căi, nu prin merge/cherry-pick al #34. Cele 59 Dart parts și toate porturile Home sunt păstrate.

## Loturi și rezultate

| Lot / commit | Standard CI | Identity CI | Android integrat |
|---|---|---|---|
| 1 — `b35be65f29952f66271e04addcdbf99850998343`, nucleu și nouă suite | [38637194546](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38637194546): SUCCESS 5/5; 390 Flutter, 158 Python | [38637194426](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38637194426): SUCCESS, 5 PASS | Nu era încă conectat bootstrap-ul |
| 2 — `b89a1783248da48021b6f7da6af18aac984b2d14`, bootstrap/hookuri și probe combinate | [38638290602](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38638290602): SUCCESS 5/5; 397 Flutter, 166 Python | [38638290606](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38638290606): SUCCESS, 5 PASS | [38638291119](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38638291119): SUCCESS; 123 teste și compilare reală `lib/main.dart` |
| 3 — `5ccdc54618a30af956654de1eb2826035ca44b40`, UI cu ownership și refuz device-wide | [38639357717](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38639357717): SUCCESS 5/5; 402 Flutter, 167 Python | [38639357762](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38639357762): SUCCESS, 5 PASS | [38639357491](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38639357491): SUCCESS; 128 teste și compilare reală `lib/main.dart` |

Pe lotul 3: 3 Node, 10 financial emulator + 5 identity emulator, Functions dependencies/syntax, smoke Dart și build web PASS. Cele 402 teste Flutter includ toate cele 294 din bază, 96 Vision portate inițial, 4 teste suplimentare de confidențialitate UI și 8 teste combinate. Toate A01–A12 și C01–C08 trec; cele două suite și fixture-urile de securitate sunt byte-identice cu #35.

Job IDs lot 3: Flutter `116110642054`, Python `116110641840`, Node `116110642194`, Functions `116110641497`, financial `116110642456`, identity `116110632675`, Android `116110631987`.

### Echivalența exactă a arborilor testați

| HEAD integrare | Checkout merge-ref PR #38 | Git tree identic |
|---|---|---|
| b35be65 | daf3ed12811143d0b360ca1913280efdba389040 | 95b66651623dc7c19a03e8e3a0ee9df3f6d9358b |
| b89a178 | fe3b7df21c94c0af0ff03a167055309f43a537d7 | fe2bd43b2d0afdaf6d28fa083602b6b5564c09c3 |
| 5ccdc54 | 1089e453181f7c0ff0062c05d83a66cd6b6c514e | 0091cc11be0e1f62bc185218543100ca7462da75 |

Logurile checkout pentru standard, identity și Android confirmă merge-ref-ul. Workflow-ul Android afișează explicit SHA/tree înainte de teste și build. Checkpointul documentar următor are propriul SHA/tree/CI final în descrierea PR #38, după verificare; fișierul nu încearcă să conțină propriul hash.

## Comportament integrat

Jurnalul local păstrează maximum 150 intrări / 48 KiB / 7 zile, deduplicare, sanitizare, retenție, restore înainte de write și coadă serială. Persistența indisponibilă produce fallback RAM și status explicit, fără blocarea aplicației. Flush-ul la paused/hidden/detached este best effort; nu există polling sau transport cloud.

Bootstrap-ul este unic și non-blocking înainte de Firebase. Handlerii Flutter/Dart existenți sunt înlănțuiți; lipsa unui handler async păstrează return false. Vision folosește numai codurile constante `framework_error` / `uncaught_error`, fără excepții brute, stack sau runtimeType. Observațiile dinaintea bootstrap-ului rămân în RAM; doar inițializarea explicită activează stocarea/debounce. Nu schimbăm politica Firebase sau ecranul de eșec startup.

Cele 13 hookuri operaționale sunt unice și folosesc doar area/code fixe. Home păstrează ownership la intrare și după await. Expense primește un seam opțional `diagnosticSessionIsCurrent`, furnizat din ownership Home, folosit exclusiv pentru observații. Nu acordă drepturi și nu modifică save, confirmări, sume sau retry. Eliminarea celor șapte hookuri reconstruiește byte-exact cele trei module Expense actions din #35, verificat cu hashuri Python.

Advisorul, raportul opt-in și inventarul acoperirii rămân locale/read-only. Raportul are limite de 100 intrări / 16.000 caractere și se copiază numai la gest explicit. Pagina refuză jurnalul static device-wide, inclusiv dacă acesta este injectat cu un grant pozitiv. Orice alt log injectat cere ownership live; lipsa, false sau excepția duc la refuz fără listă/raport/Clipboard. Testele combinate folosesc un jurnal sintetic nou pentru fiecare context și closure-ul real UID+epoch din AuthGate.

UI verifică ownerul înainte de copiere și după await. Proba cu Clipboard întârziat schimbă SDK UID la B înainte de dispose și cere zero feedback A; root elimină rutele, sheet-ul și SnackBar. Copierea OS deja inițiată nu poate fi retrasă retroactiv. Nu există buton/rută publică nouă Vision în aplicația autentificată.

`VisionExpenseSaveVerifier` rămâne pur și neconectat: nicio citire server nouă, deducere din cache, retry, auto-confirmare sau modificare sumă.

## Integritate, PDF și Android

Toate cele 116 hashuri protejate trec fără schimbarea manifestului. AuthGate/Sources/root, parserul OCR, PDF Magic, drepturile și formulele financiare, rules/config/assets/workflow-urile protejate, configurația Android și versiunea pubspec sunt păstrate. Nu sunt adăugate permisiuni, API-uri, servicii plătite, listener/read/write Firestore ori telemetrie cloud.

Million lipsește din baza #35. Nu l-am importat împreună cu un alt flux PDF. Originalul din sursa #34 are SHA256 `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`, verificat direct. `assets/pv_magic.pdf` rămâne SHA256 `eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b`. Integrarea documentelor rămâne separată.

Un workflow NOU, limitat prin head_ref la această ramură, testează Vision/AuthGate și compilează aplicația reală. Workflow-urile protejate nu sunt schimbate. Android folosește configurația/entrypoint-ul existente, fără secrets, modificări Google Services sau versiuni de release. Nu există upload-artifact pentru APK, instalare, distribuire ori deploy.

## Limite și pași rămași

- Accesul public la panou cere o politică explicită și o proiecție persistentă demonstrabil per UID+epocă. Un callback ownership singur nu segmentează istoricul dispozitivului. Rolul developer nu primește admin.
- Hardware/login Firebase live, GPS/FCM reale, camera/MLKit și Keystore fizic sunt NEEXECUTATE. Compilarea CI nu certifică aceste fluxuri.
- Nu există colectare backend, centralizare multi-dispozitiv, LLM cloud sau monitorizare permanentă. Un jurnal gol nu certifică sănătatea aplicației; succesul storage nu garantează integritatea fizică a discului.
- Tokenurile deja stocate, notificările OS expediate, cache-ul Firebase și writes/maintenance deja pornite nu sunt revocate/anulate de această integrare.
- Issue #32, OCR grouping/TVA, backup/migrare/idempotency, PDF Million și avatarul necesită scope distinct.

Toate loturile sigure din mandat sunt implementate și validate pe ramura de test. PR #38 rămâne Draft DO NOT MERGE. Fără merge, deploy, publicare web/APK, instalare, date/rules/config Firebase de producție, billing sau schimbări de reguli funcționale. Checkoutul și sursele protejate se reverifică la final.
