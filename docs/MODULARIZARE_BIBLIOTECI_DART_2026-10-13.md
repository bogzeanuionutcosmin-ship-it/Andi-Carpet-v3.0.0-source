# Biblioteci Dart independente — audit și migrare 2026-10-13

Bază: PR #28 `0866bb8fee6c9e04ac75ba6cd4fe1993ed92e597`, CI 38373059059 5/5 SUCCESS. Documentele obligatorii, registrul de reguli, Vision și auditul modularizării au fost recitite înainte de modificări. Scop exclusiv structural; nu aprobă funcții noi ori release.

## Inventarul reproducibil

`scripts/audit_dart_dependencies.py` inventariază toate fișierele Dart din lib/test, directivele complete import/export/part/part-of (inclusiv toate ramurile condiționale), clase/enum/mixin/extension/typedef și funcții top-level. Snapshot: `docs/DART_DEPENDENCIES_2026-10-13.json`. Numele și directivele sunt inventar lexical, NU analiză de apeluri sau dovadă de cod nefolosit. Graful de import/export este calculat după asocierea parts cu biblioteca proprietar; nu etichetăm `part ↔ main` drept ciclu de import.

Înainte: 113 surse lib + 9 teste Dart, 89 parts / 24 biblioteci în lib. Lot 1: aceleași 113 surse lib + 10 teste Dart, **84 parts / 29 biblioteci în lib**. Fără ținte locale lipsă, parts orfane, declarații numite duplicate în aceeași bibliotecă ori cicluri de import/export. Se păstrează fluxurile OCR/download condiționale și modulele financiare v2 chiar dacă nu sunt importate direct de main. Clasele State/extensions pot avea metode private omonime fără a fi duplicate reale.

## Lot 1 — fundația modelelor

| Bibliotecă | Dependențe explicite | Interfață păstrată |
|---|---|---|
| app_enums_permissions.dart | Flutter Material | 11 enumuri și 4 extensii label/icon/color |
| location_status_and_functions.dart | Material + enumuri | LocationCategory, FunctionDefinition, LocationStatusX |
| location_category_helpers.dart | Material + enumuri + modele categorie/funcție | mapping legacy, culori și nume |
| default_categories_functions.dart | Material + enumuri + modele categorie/funcție | cataloage și functionById |
| permission_status_labels.dart | enumuri | grupuri permisiuni și etichete diurnă/metodă |

Nu importă `main.dart`, nu accesează identificatori privați ai main. În main, parts respective sunt înlocuite cu **import + export**: callerii existenți și testele care importă main primesc aceleași tipuri/extensii publice. Importurile NU se propagă tranzitiv, de aceea fiecare bibliotecă își declară dependențele. Culoarea/iconurile rămân Material: această etapă le separă de main, nu pretinde un domain model complet fără Flutter.

**Echivalență:** pentru fiecare fișier, după înlocuirea strictă a directivei part cu importuri, întregul corp (declarații, comentarii, membri) este byte/text-identic cu baza. Nicio ordine enum, constructor, fallback, culoare, badge, permisiune, mutabilitate sau regulă financiară schimbată. Compatibilitatea identității tipurilor și re-exportului este testată direct în Dart.

**Teste locale:** 145 Python PASS, 3 Node PASS, syntax Functions/diff-check PASS. Patru teste Python noi verifică integritatea grafului, limitele modelelor și ramurile condiționale. Cinci teste Flutter noi importă direct cele cinci biblioteci și verifică identitatea prin main, fallbackuri, culorile fixe, badge-uri, instanțe proaspete și setul de permisiuni. Flutter nu este instalat local; compilarea/testele și web release sunt în CI pe SHA nou. Rezultatul final va fi înscris în PR; nu se folosește verdele bazei pentru lotul nou.

## PDF — analiză separată, fără modificare

PR #20 verificat read-only la `8ae220b41b5e9c1648151606f9443ba8fa68a90a`.
`pdf_reports.dart` blob **2ce3d664c2463fdb18cefb5272557e7014ee7df4**, `pdf_format_helpers.dart` blob **f4f664d07e06e3eaac98c6b9a755fe37b054fed3**: identice cu PR #28. Compatibilitatea raportării este astfel confirmată la nivel de sursă; nu afirmăm test manual al PV-urilor pe această ramură. PR #20 schimbă Documents/download/assetul Million și comportamentul anulării/partajării, nu se copiază aceste schimbări.

Cele 5 exporturi PDF folosesc modele, enumuri/extensii, date operaționale, generator fonturi PdfGoogleFonts, download condițional și, pentru grafic, rutare. `_buildPdfTheme`, `_safeFilePart`, `_pdfDate` sunt private comune; `_safeFilePart` are și caller JPEG în Program. Graph route păstrează singletonul privat `_mapboxServices` folosit și de Map/Program. Transformarea izolată a PDF ar impune interfețe explicite pentru aceste dependențe; **PDF și PV Magic/Million sunt lăsate intacte în lotul 1**.

## Probleme și transformări oprite

- `app_data_models.dart` depinde de `graphDefaultName` din main: candidat pentru lotul 2 numai după extragerea acestui helper public; constructorii financiari/parserul monetar trebuie păstrați identic.
- Date operaționale și Learning depind de modelele centrale: pot deveni independente după acestea, în ordine fără ciclu models → dates → models.
- Celelalte parts de UI/State/auth/sync/admin depind de starea comună, identificatori privați, callbacks și mixinuri; nu sunt transformate forțat.
- Cache-uri numai scrise și receivedEntries repetat: candidați, nu ștergeri. `_encoded`, idNow și DateTime.now pot avea efecte asupra erorilor/fallbackurilor. Assets/platforme cu hash identic sunt păstrate.
- Blocajele cunoscute (concurență START, Refuzată, GPS după scriere, backup/migrări și lifecycle) rămân nerezolvate; se discută funcțional ulterior.

## Coordonare și restricții

PR #29 verificat read-only la `5b639953f6fed804b10e98561fc6a388b1d377f2`, ramură separată din main. **Nu schimbăm** ocr_parser.dart, ocr_parser_test.dart, tests/firestore/diurna.test.cjs, documentația sa ori regulile financiare; nu integrăm PR #29. Parserul său și diagnosticul autorizării rămân pe acel front.

Fără merge, deploy, Firebase producție/date/rules/config, billing, versiune, migrare sau APK publicat. PR #28 rămâne Draft. Modularizarea completă NU este finalizată. Următorul lot recomandat: helper graphDefaultName → modele centrale → date operaționale/Learning, cu CI 5/5 după fiecare lot; PDF doar după eliminarea controlată a dependențelor private și reverificarea PR #20.

## MOD-MODEL-LIBRARIES-1-CI-TEST-FIX-20261013

Lotul `bd10f05cbbd82bc57a740315b60fc00b88727c81`, run 38374611001: 4/5 joburi SUCCESS; Flutter compilează, 50 teste PASS și un test nou FAIL. Cauză în aserțiunea nouă, nu în model: getterul existent construiește Color(argb), iar testul îl compara cu MaterialColor Colors.indigo; egalitatea tipurilor de culoare nu este garantată. Test corectat să compare toARGB32 pentru aceeași valoare. Nu se schimbă getterul/modelul/culorile/UI; corpurile celor 5 modele rămân identice. CI se reverifică pe SHA corectat înainte de lotul 2.

## MOD-MODEL-LIBRARIES-2-20261013 — modele centrale, date și Learning independente

Bază `304961349d7466a8decf455462555c70df1a6ec9`, **CI lot 1 run 38374913170 5/5 completed/success** verificat înainte de acest lot. Model foundation este compilat și testat, inclusiv cele 5 teste directe. Eroarea de aserțiune Color/MaterialColor din primul run a fost corectată doar în test.

`graphDefaultName` este mutat textual din main în biblioteca leaf `lib/utils/graph_names.dart` și re-exportat în main. `lib/models/app_data_models.dart` devine bibliotecă cu importuri enums/category helpers/graph_names: toate **17 clase și parsePerDiemBani**, constructorii/setările/listele/calculele și comentariile rămân integral identice după schimbarea strictă a directivelor. Nu se rescrie modelul financiar și nu se unifică legacy/v2. `lib/utils/operational_dates.dart` importă doar modelele; `lib/learning/duration_estimates.dart` importă enums/models/dates. Ambele devin independente fără acces privat la main. Main importă și re-exportă API-urile existente. Graful este orientat aciclic; models NU importă dates, evitând ciclul models↔dates.

Cumulativ: toate cele **6 fișiere din lib/models/** sunt biblioteci, plus date și Learning; **89 → 81 parts**. Inventar actual: **114 surse lib / 11 teste Dart**, 33 biblioteci în lib și 44 inclusiv teste. Snapshot regenerat și fără ținte lipsă/parts orfane/duplicate în aceeași bibliotecă/cicluri import-export. Nu declarăm modularizarea completă: 81 parts încă împart main și multe module au stare/API private.

Teste locale **146 Python PASS, 3 Node PASS, syntax Functions/diff-check PASS**. Un contract nou impune direcția dependențelor; **8 teste Dart noi** importă direct modele/date/Learning și verifică identități re-exportate, constructori/alias liste/config separate, limita 23:30, an bisect/schimbare an, ferestre inclusive, prioritatea timestampurilor și toleranța de 3 ore, formatarea existentă, minimum 3 mostre valide/Learning dezactivat și trimming automat. Nu se adaugă test live sau date reale. CI Flutter/web, Functions și emulator demo trebuie verificat pe HEAD nou; SHA/run final se consemnează în PR.

PDF/PV Magic/Million și download/asseturi rămân byte-identice cu baza. Auditul PDF a comparat sursa cu PR #20; nu s-au preluat fluxurile acelui PR. Rutarea/PDF rămân parts din cauza helperilor privați și singletonului Mapbox: mutarea lor izolată fără adapter explicit ar fi nesigură. Următorul lot recomandat: separarea utilitarelor PDF comune cu interfață de fonturi/download/rutare și audit al singletonului, apoi adaptere UI, cu probe de compatibilitate și CI. Calculele repetate departureTotal/duringTotal/totalReceived în TravelSettlement/TeamFinance sunt reale, dar **nu consolidate aici**, conform interdicției schimbărilor financiare; cache-urile numai scrise și conversiile receivedEntries sunt doar candidate.

Fișierele frontului PR #29 (ocr_parser.dart, ocr_parser_test.dart, tests/firestore/diurna.test.cjs, documentația OCR), rules/config și întreg lib/finance sunt neatinse față de 0866bb8. Nu se integrează PR #29, nu se modifică autorizarea cheltuielilor. Fără merge/deploy/Firebase live/billing/versiune/APK. PR #28 rămâne Draft.

## MOD-MODEL-LIBRARIES-3-20261013 — nucleu Dart fără Flutter/Firebase

Bază `207e61405e3e66bbccb4bafeb4375ef8c17dd163`, **CI lot 2 run 38375545756 5/5 completed/success** verificat înainte de lotul 3. Testele Flutter noi pe modele/date/Learning au trecut și web release a compilat.

A fost eliminată și dependența Material indirectă a modelelor centrale: cele **11 enumuri** sunt mutate textual în `lib/models/app_enums.dart`; cele 4 extensii label/icon/color rămân textual în `app_enums_permissions.dart`, care importă/re-exportă enumurile pentru API-ul vechi. Cele **2 mapări pure** sunt mutate în `location_type_mapping.dart`, importate/re-exportate de `location_category_helpers.dart`; culorile/numele și modelele cu Color/IconData rămân în bibliotecile de prezentare. Refacerea enumuri+extensii și mapping+prezentare reproduce EXACT corpurile originale. Celelalte schimbări de modele/Learning/defaults/labels/status sunt numai directive import, cu corpurile identice.

Nucleu pur cu graful închis de **6 biblioteci**: `app_enums`, `location_type_mapping`, `graph_names`, `app_data_models`, `operational_dates`, `duration_estimates`. Niciun import package/Flutter/Firebase/main în această închidere. Modelele cu Color/IconData nu sunt forțate în acest nucleu: API-urile lor rămân compatibile cu Material.

Se adaugă în **același job Flutter din cele 5 joburi existente** o verificare reproductibilă `dart run scripts/verify_pure_models.dart`, după unit/widget și înainte de web build. Aceasta compilează și execută nucleul **fără motor Flutter**, pe exemple sintetice de constructor/mapping/limită operațională/Learning, fără rețea sau date reale. Nu este build APK/deploy ori workflow de producție. Local Dart lipsește; execuția standalone trebuie confirmată în CI, nu presupusă.

Local: **147 teste Python PASS, 3 Node PASS, syntax/diff-check PASS**. Contract nou verifică recursiv închiderea pure domain, nu doar importurile directe. Inventarul include acum și scripts/*.dart: **116 surse lib + 11 teste Dart + 1 verificare Dart standalone = 128 fișiere**, **81 parts** și 35 biblioteci lib / 47 total. Fără directive către ținte lipsă, parts orfane, declarații duplicate în aceeași bibliotecă sau cicluri import/export. Snapshot actualizat; acesta este inventar lexical și nu dovedește lipsa tuturor dependențelor de runtime ori cod mort.

Fără schimbări de comportament/randament/GPS/financiar/OCR/auth. Interfețele exportate anterior prin main și cele două facades models își păstrează tipurile/constructorii/extensiile. PR #29 neintegrat și fișierele sale protejate neatinse; PDF/helpers/download/asseturi/PV Magic/Million neatinse și compatibilitatea de sursă PR #20 verificată anterior. Regulile/config/date Firebase și billing nu sunt modificate.

**Limită și pas următor:** 81 parts rămân în main; adaptere private State/sync/UI/Mapbox și PDF necesită proiectare explicită. Nu se transformă forțat singletonul Mapbox ori helperii PDF și nu se consolidează financiar/cache fără verificarea efectelor. Următorul lot recomandat este un adapter PDF cu dependențe de font/download/rutare injectate fără re-crearea singletonului, numai după analiza callerilor JPEG și verificarea PR #20. Modularizarea completă NU este finalizată. CI final și SHA se consemnează în PR după toate cele 5 joburi; fără merge/deploy/Firebase producție/APK.

## MOD-ROUTING-BOUNDARIES-20261013 — rutare explicită, PDF/PV protejate

Bază PR #28 `54a24c496b41a6fb6b07088a94f39a426a569146`. Recitite documentele obligatorii și auditul înainte de editare. PR #20 verificat read-only la `8ae220b41b5e9c1648151606f9443ba8fa68a90a`; nu este integrat. PR #29 rămâne separat.

**Lot:** `graph_route_points.dart` separă construcția pură a punctelor (modele + latlong2, fără Flutter/network); `graph_route_calculations.dart` devine bibliotecă pentru distanța geometrică (aceeași formulă Geolocator, nu pretindem independență Flutter); `graph_road_distance.dart` primește explicit `DrivingDistanceLookup`, `RouteHttpGet` și flagul Mapbox. Nu creează servicii/clienți/cache-uri. Corpurile punctelor/distanței sunt text-identice, iar corpul rutării se reconstruiește exact prin înlocuirea inversă a numelor dependențelor; hashuri ale blocurilor în manifest.

**Compatibilitate:** main importă/re-exportă punctele și calculul, păstrează `estimateGraphRoadDistanceKm` cu aceeași semnătură și configurația Mapbox mutată literal. Unicul `_mapboxServices` rămâne privat în biblioteca main. Callback-ul `(points) => _mapboxServices.drivingKm(points)` păstrează inițializarea leneșă: nu se evaluează singletonul la pregătirea callbackului ori pe OSRM/traseu invalid. Harta, optimizarea, contorul admin, cache-ul și inițializarea MapboxServices sunt neatinse. Aceleași limite 2–75, lat/lon versus lon/lat, null/erori, timeout OSRM 12s, fără fallback OSRM după Mapbox null. Nu se schimbă algoritmul distanței, filtrarea sau mutabilitatea modelelor.

**Inventar:** 118 surse lib + 12 teste Dart + 1 script Dart = 131; **80 parts** (81 → 80), **38 biblioteci lib**. Nicio țintă lipsă, part orfan, declarație numită duplicată în aceeași bibliotecă ori ciclu import/export în inventarul regenerat. Inventarul lexical nu demonstrează lipsa codului mort; nimic nu a fost șters pe acest criteriu.

**Protecție:** `docs/ROUTING_PDF_PROTECTED_2026-10-13.json` fixează SHA-256 pentru 117 fișiere (assets, PDF/helpers, Documents, download, Mapbox/calleri, OCR/test, finance, rules/config/workflows). Testul verifică integritatea după lot. Magic: `eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b`, identic în ambele PR-uri. Million există numai în PR #20: `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`, 1.399.921 bytes. Nu afirmăm că Million este deja integrat în #28. PDF reports/helpers sunt identice cu #20; Documents și implementările download diferă intenționat între ramuri și rămân neschimbate pe fiecare. Hashurile surselor/asseturilor nu sunt un test al randării PDF ori al dialogului Android/web.

**Teste:** local 151 Python PASS, 3 Node PASS, syntax Functions și diff-check PASS. 11 teste Dart noi: API re-exportat, ordine/copie liste, GPS lipsă, metrica Geolocator, limite și coordonate, dispatch callback, propagare erori Mapbox, răspunsuri OSRM invalide, transport și timeout 12s cu ceas simulat. Fără cereri externe sau date reale. CI final run `38380434302` pe `c755ff8b8c0611e633be4f26732292df12957303`: **5/5 SUCCESS**, incluzând testele Flutter, verificarea Dart standalone și web release. Acest verdict valida lotul anterior, înaintea separării PDF.

**PDF — contracte identificate, separare amânată:** cei 5 generatori au nevoie de un provider `Future<pw.ThemeData> Function()` (aceeași ordine regular → bold → italic și propagare erori), de un callback de download cu bytes/filename/mimeType și de cele două funcții de distanță + puncte pentru grafic. `_safeFilePart` este comun cu JPEG; `_pdfDate` folosește `two`. La separare, păstrați fațadele private pentru calleri și evitați configurarea globală mutabilă. PR #20 are alt contract download (`Future<bool>`, anulare) și share distinct; în #28 contractul este `Future<void>`, iar PDF nativ se partajează. Unificarea lor ar schimba comportamentul, deci nu este forțată. Decont și rezumatul financiar din același fișier nu se rescriu pe acest front. Nu au fost create interfețe PDF nefolosite; următorul lot trebuie să fixeze teste cu fonturi locale/download simulat și un contract compatibil ambelor ramuri înaintea conversiei.

**Rămâne:** PDF/helpers, adaptoarele de State/UI/sync și 80 parts; auditul complet și modularizarea integrală NU sunt finalizate. Fără merge, deploy, Firebase producție, rules/config/billing, modificări financiare/OCR/diurne ori APK. Nu s-a executat validare Android pe dispozitiv în acest lot.

## MOD-PDF-FORMAT-PORT-20261013 — provider explicit de fonturi și format PDF

Bază: PR #28 `c755ff8b8c0611e633be4f26732292df12957303`, CI workflow run `38380434302` **5/5 SUCCESS**, verificat înaintea lotului. PR #20 reverificat la `8ae220b41b5e9c1648151606f9443ba8fa68a90a` și manifestul SHA existent; PR #29 rămâne separat.

**Bibliotecă nouă:** `lib/reports/pdf_report_format.dart` primește `PdfFontProvider` cu apeluri async `regular/bold/italic`, aplică fonturile secvențial în aceeași ordine, apoi creează tema PDF. `safePdfFilePart` și `formatPdfDate(date, two)` nu depind de starea din main. Biblioteca importă numai `pdf/widgets`; nu știe de Flutter, Firebase, Mapbox, download, Printing, JPEG sau modele financiare. Nu descarcă fonturi și nu păstrează cache singleton.

**Compatibilitate:** PDF generatorii (`pdf_reports.dart`) și callerul JPEG nu au fost editați. În main, `_buildPdfTheme`, `_safeFilePart`, `_pdfDate` păstrează semnăturile și numele private existente; `_ApplicationPdfFonts` deleagă la aceleași trei `PdfGoogleFonts.openSans*`, fără cache sau reordonare. Importul operațional al `two` rămâne în main și este injectat ca funcție în data formatter. `pdf_format_helpers.dart` nu mai este part; biblioteca independentă este importată de main. Hashul vechi al helperilor este consemnat în manifest, iar PDF reports, PV Magic, Documents și download au hashurile pinned/testate.

**PR #20 și exportul:** `pdf_reports.dart` are blob identic în PR #20 și #28, deci generatorii nu cer adaptare specifică ramurii. Flow-ul PDF al PR #20 schimbă salvarea nativă în rezultat anulabil (`Future<bool>`) și adaugă share separat; PR #28 încă are `Future<void>` și trimite PDF către `Printing.sharePdf` pe native/web download. Noul port de font e comun ambelor implementări. **Portul download/share încă nu este implementat**: ar promite incorect anularea în PR #28. Interfața corectă trebuie să păstreze rezultatul `cancelled` pentru FilePicker PR #20, să distingă share de download și să aibă un rezultat onest pentru API-ul vechi; integrarea se face după un contract comun cu adaptere separat testate pe fiecare ramură. Nu s-a copiat schimbarea PR #20 și niciun flux PV Magic/Million nu a fost alterat.

**Teste și inventar:** adăugate 4 teste Dart pentru ordinea și numărul fonturilor cerute, propagarea erorii, PDF sintetic cu fonturi built-in, normalizarea numelui ASCII și data `dd.MM.yyyy`; teste de regresie structurală păstrează wrapper-ele main și interfața. Testele Python 151 PASS, Node 3 PASS, `node --check` PASS, inventar 132 fișiere Dart / **79 parts** / 53 biblioteci totale (39 în lib, 13 teste, 1 script); fără missing/orphan/duplicate/cicluri. CI final run `38385963190` pe `06b1e8945078783d940c6ab153d5d68cc3751c52`: **5/5 SUCCESS**, inclusiv Flutter tests, Dart standalone, web release, Python, Node, Functions și emulator Firestore. Nicio rețea, date reale, randare PV ori Android device test. `pdf_report_format_test.dart` folosește fonturile built-in numai pentru un PDF sintetic.

**Rămâne:** callback de export anulabil și compatibilitate Android/web; verificarea directă în sursă PR #20 rămâne necesară la adapterul download/share. În rest 79 parts și restul auditului. Modularizarea integrală nu este finalizată. Fără merge/deploy, Firebase producție, rules/config, billing, APK, OCR, parser sau reguli/date financiare.

## MOD-HOME-LOCATION-SEED-20261013 — catalog operațional independent

Bază de lucru verificată: PR #28 `a01e8c98e48b023e325012deabb3735290563895` (arborele local conține lotul PDF format deja validat). CI anterior pentru acel cod: run `38386268514`, 5/5 SUCCESS. PR #20 consultat read-only la HEAD `8ae220b41b5e9c1648151606f9443ba8fa68a90a`.

**PDF — blocaj păstrat explicit:** `pdf_reports.dart` rămâne blobul `2ce3d664c2463fdb18cefb5272557e7014ee7df4` din ambele PR-uri; generatoarele #28 apelează `downloadFile` cu contract `Future<void>`, iar #20 are salvare `Future<bool>` (false la anulare pe FilePicker) și share separat prin `Printing.sharePdf`. O interfață comună care întoarce void ar ascunde anularea din #20; una bool nu poate deduce anularea din API-ul #28. PDF generatorii depind de helpers private din main și de rutare; helperul numelui se folosește și pentru JPEG. Nu am adăugat porturi nefolosite și nu am modificat generators, download/share, Documents, fonturi ori adaptoarele Android/web. Conversia PDF rămâne blocată până când rezultatul generării poate fi separat de transport și adapterele fiecărei ramuri sunt testate fără schimbarea contractului existent.

**Lot sigur:** vechiul part `home/home_location_seed.dart` devine biblioteca `home/seed_operational_locations.dart`, care importă explicit numai modelele și enumurile. `_HomePageState._seedLocations()` păstrează numele și punctul existent de inițializare, delegând către factory. Catalogul de 103 intrări nu a fost rescris: hashul SHA-256 al literalului înainte/după este `82611ffb8f0f605a17e196f0196765dff3f0c923117997cdf34dc9048dbc9eb1`; se construiesc în continuare listă și obiecte Location proaspete la fiecare apel. Test Dart verifică ordinea, 36 Magic, 67 Million, unicitatea ID-urilor și mutabilitatea izolată. Testul Python verifică literalul prin hash și absența Flutter/Firebase/main din noua bibliotecă.

**Protecție:** manifestul SHA-256 existent a trecut integral; `assets/pv_magic.pdf` rămâne `eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b`. PDF Million nu este inclus în #28; PR #20 păstrează originalul la `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23` / 1.399.921 bytes. Hashurile identifică fișierele sursă, nu înlocuiesc testele runtime Android/web. Nicio componentă PR #20/#29 nu a fost copiată sau schimbată.

**Inventar după lot:** 133 fișiere Dart (118 lib, 14 teste, 1 script), **78 parts**, 55 biblioteci (40 în lib). Regenerarea `DART_DEPENDENCIES_2026-10-13.json` arată zero ținte lipsă, parts orfane, declarații duplicate în aceeași bibliotecă sau cicluri import/export. Un part a devenit bibliotecă independentă; inventarul lexical nu este audit de cod nefolosit.

**Validare:** local 151 teste Python PASS, 1 test Node PASS, `node --check functions/index.js` PASS, `git diff --check` PASS; scriptul de audit Dart a regenerat inventarul fără anomalii. Flutter/Dart lipsește local. CI run `38388145518` pe SHA-ul lotului `f6fe0370dd66a6694c172a0ad854939a4b8e57d8`: toate cele 5 joburi SUCCESS (Flutter tests + web, Functions, Python, Node, Firestore emulator); include cele două teste Dart ale catalogului.

**Rămâne:** PDF download/share/runtime și 78 parts, inclusiv Mapbox/UI/sync. Pasul următor sigur: audit static al modulelor Home care nu au stare privată și callbackuri comune; pentru PDF, proiectarea artifactului de generare + adaptere per ramură, fără atingerea fluxurilor până la probe Android/web. Modularizarea completă NU este finalizată.

## MOD-ADMIN-NAV-CATALOG-20261013 — navigație admin independentă

Validarea lotului precedent: CI run `38388145518` pe `f6fe0370dd66a6694c172a0ad854939a4b8e57d8`, **5/5 SUCCESS**. Commitul exclusiv documentar `2ebb77ca8c09a9511995fa51aa6203e67cb91c69` a fost și el validat de run `38388469494`, **5/5 SUCCESS**.

`admin/admin_navigation_catalog.dart` devine bibliotecă cu import explicit Material; funcțiile pure index→icon/grup/asset rămân aceleași. În main se păstrează wrapper-ele private `_adminSectionIcon`, `_adminSectionGroup`, `_adminSectionAsset`, deci callsite-urile din Admin panel și dashboard nu se schimbă. Nu este un domain package fără Flutter: biblioteca este separată de main/Firebase, dar IconData/Icons cer Material. Testele Dart verifică toate cele 17 poziții, grupurile și asseturile, plus indexul invalid; testul Python verifică limitele import/export și wrapper-ele.

Inventar curent: 134 Dart (118 lib, 15 teste, 1 script), **77 parts**, **57 biblioteci totale** (41 lib, 15 test, 1 script). Snapshot fără ținte lipsă, orphan parts, duplicate în aceeași bibliotecă sau cicluri. Local: 151 Python PASS, 1 Node PASS, Functions syntax, snapshot și diff-check PASS; Flutter nu este instalat local. CI run `38388935786` pe `ffb35c16b2c1d41e9fce42b1e9255159609b58c4`: **5/5 SUCCESS**, inclusiv toate testele Flutter și web build.

PDF și PR #29 rămân neatinse. Riscul/limitarea PDF download/share documentată mai sus rămâne; următorul candidat este analiza Home/sync cu dependențe private, fără a forța conversia. Modularizarea integrală NU este finalizată.

## MOD-ICON-BADGE-CATALOG-20261013 — asseturi și etichete UI partajate

CI-ul lotului Admin: run `38388935786` pe `ffb35c16b2c1d41e9fce42b1e9255159609b58c4`, 5/5 SUCCESS. Actualizarea documentației: run `38389244180` pe `cb3946f5dd1d734f56bbf6bb0a37dc1acedd837b`, 5/5 SUCCESS.

`ui/icon_badge_catalog.dart` a devenit bibliotecă Material autonomă față de main/Firebase. Corpul funcțiilor, constantelor și widgeturilor este identic cu sursa de bază după normalizarea singurei redenumiri de limită (`_badgeGraphic` → `badgeGraphic`) și înlocuirea strictă a `part of` cu import Material: SHA-256 `06a837cfd5d39a547e65d8a69a0f2a7097515d41c371da10513b8b53f81fcefd`. Main importă și reexportă biblioteca pentru API-ul public. Wrapper-ul privat `_badgeGraphic` cu aceeași semnătură din main păstrează utilizatorul din `interactive_member_badges.dart`.

Teste noi importă direct biblioteca și main pentru regresia exporturilor, verifică iconuri/etichete/alias `badge_machine`, valorile necunoscute și ramurile existente de etichete asset. Testul structural protejează SHA-256-ul corpului și dependența Material explicită. Inventar: 135 Dart (118 lib, 16 teste, 1 script), **76 parts**, 59 biblioteci totale (42 lib, 16 test, 1 script), zero missing/orphan/duplicate/cicluri. Local 151 Python, 1 Node, Functions syntax, manifestul PDF cu toate cele 116 hashuri, inventar și diff-check PASS; Dart/Flutter lipsesc local. CI pe commitul acestui lot urmează înainte de următoarea etapă.

Nicio schimbare în Documents/download/share/PDF/assets sau PR #29. Următorul candidat după CI: evaluarea componentelor Home/UI cu stare privată minimă; auth, permisiuni, sync și PDF nu se forțează fără interfețe explicite și contracte compatibile.

### Corecție găsită de CI

CI inițial al acestui lot, run `38389669780` pe `acaf495b95f18c2a7490348625c89691974a2926`, a avut 4/5 SUCCESS. Testul Python, Node, Functions și emulatorul au trecut. Jobul Flutter a oprit la compilare: `interactive_member_badges.dart` folosea simbolul privat `_badgeGraphic` din altă bibliotecă `part of main`; acel simbol nu mai era vizibil după extragere. 52 teste au trecut, iar 5 test files nu s-au putut compila.

Remediu: expunem widgetul ca `badgeGraphic` în biblioteca Material și reținem wrapper-ul privat `_badgeGraphic` în main pentru callbackurile/part-urile existente. Corpul funcției rămâne identic la normalizarea numelui. Contractul static și testul direct verifică această punte. Corecția `b503f0ffbd44d0660e71aee360319d61f70f8466` a fost validată de CI run `38390010291`: **5/5 SUCCESS**, inclusiv Flutter tests și web release. Nicio altă funcționalitate schimbată.

## MOD-EMPTY-STATE-LIBRARY-20261013 — componentă goală independentă

Bază de lot: PR #28 după corecția CI `b503f0ffbd44d0660e71aee360319d61f70f8466`, run `38390010291` 5/5 SUCCESS. `ui/empty_state.dart` devine bibliotecă Material independentă; corpul UI rămâne identic după redenumirea clasei și constructorului `_Empty` în `EmptyState`, SHA-256 normalizat `2be8dc91332ee092c2c7858b6c9f36cf40f8efe2377190996b549d11fcba6c92`. Wrapper-ul privat `_Empty` din main păstrează constructorul/contractul tuturor callsite-urilor.

Test Flutter direct validează Card/icon/text; test Python validează SHA-ul corpului, importul explicit și wrapper-ul. Inventar regenerat: 136 Dart (118 lib, 17 teste, 1 script), **75 parts**, 61 biblioteci (43 lib, 17 teste, 1 script), fără missing/orphan/duplicate/cicluri. Local 151 Python, 1 Node, Functions syntax, 116 hashuri protejate, audit import/export și diff-check PASS. Flutter SDK nu este local; CI pe commitul nou trebuie să confirme testul Flutter și toate celelalte joburi.

PDF/Mapbox/download/share, PR #20 și PR #29 neatins. Următoarea analiză după CI: componente independente Home/UI; nu se mută auth/sync sau widgeturile ce folosesc stare privată fără adapter complet.

### Corecție CI — redenumirea constructorului

Run `38390449115` pe `9ba22143a734d83ac1b9d410e88b2079f577c946`: 4/5 SUCCESS. Flutter a oprit compilarea deoarece clasa redenumită `EmptyState` păstra constructorul vechi `const _Empty`, invalid în noua bibliotecă. 52 teste trecuseră; 6 fișiere nu s-au putut compila din cauza erorii. Corecție: constructorul componentei se numește `EmptyState`; wrapper-ul privat din main păstrează `const _Empty`. Hashul structural normalizează și numele constructorului. Commit corectiv `f95233dbdc50b44219306d9fcc18e1da25a0ade9`, run `38390758123`: **5/5 SUCCESS**, inclusiv Flutter tests și web build.

## MOD-MONEY-CARD-LIBRARY-20261013 — card de valoare cu callback injectat

Bază: CI corectiv Empty run `38390758123` pe `f95233dbdc50b44219306d9fcc18e1da25a0ade9`, 5/5 SUCCESS. `ui/money_card.dart` devine bibliotecă Material. Corpul widgetului original, normalizat doar pentru numele `_MoneyCard`/`MoneyCard`, are SHA-256 `e7326bf0fe3d3798ec246f094e6d53f4221abc08a7942b94b1438b80ad77c16b`. Wrapper-ul privat din main păstrează constructorul și transmite titlu, sumă și callback fără transformare. Nicio formulă sau regulă financiară nu este mutată/modificată; apelanții Expense continuă să calculeze valorile ca înainte.

Test Dart importă direct componenta și verifică textul sumei cu două zecimale și invocarea callbackului. Test Python fixează corpul widgetului și adapterul. Inventar: 138 Dart (119 lib, 18 teste, 1 script), **75 parts**, 63 biblioteci (44 lib, 18 test, 1 script), zero ținte lipsă/orfani/duplicate/cicluri. Local 151 Python, 1 Node, Functions syntax, 116 hashuri protejate, audit și diff-check PASS; Dart/Flutter lipsește local. CI pentru `48eda76f705f5b64cafc01ad955d77fab23c9859`, run `38391208890`: **5/5 SUCCESS**, inclusiv testul MoneyCard în Flutter și buildul web.

PV/PDF/Android-web download, Mapbox și PR #20/#29 neatinse. Modularizarea integrală nu este finalizată; după CI următorul pas este auditarea altor componente UI pure, fără atingerea calculelor financiare.

## MOD-INFO-CARD-LIBRARY-20261013 — componentă informativă cu accent injectat

Bază: `92a62c6080594778bee9a44ece90de03dfd08deb`, actualizare documentară pentru MoneyCard validată de CI run `38391645487`, 5/5 SUCCESS. `InfoCard` este extras în `lib/ui/info_card.dart` ca bibliotecă Material. Biblioteca primește `accent` explicit; wrapperul privat `_InfoCard` păstrează constructorul și callsite-urile existente, calculând aceeași `sectionAccent(title)` la build și pasând rezultatul.

Structura Card/ListTile, cercul, iconul, stilul fontului și titlul/subtitlul rămân identice. Test Flutter direct verifică accentul și conținutul; test structural verifică adapterul și absența vechii clase din `summary_cards.dart`. `summary_cards.dart` rămâne part pentru `_StatCard`; nu eliminăm fișierul sau directiva pe baza unei căutări de nume. Nu sunt schimbate rapoarte financiare ori logică OCR/diurne.

Inventar regenerat: 140 fișiere Dart (120 lib, 19 teste, 1 script), 75 parts, 65 biblioteci (45 lib, 19 teste, 1 script), fără ținte lipsă, orfani, duplicate în aceeași bibliotecă ori cicluri import/export. Local 152 teste Python, 1 Node, syntax Functions, 4 verificări pentru PDF/rutare, manifestul protejat de 117 fișiere și diff-check PASS. Flutter/Dart nu există local. CI run 38392826791 pe 834c58350910fa9f290c5fcb489f1d87188927ef a trecut 5/5 SUCCESS, inclusiv testul widget InfoCard și web build.

PR #20 PDF/PV Magic/Million și fluxurile Android/web rămân byte-identice; PR #29 OCR/permisiuni financiare/diurne neatins. Modularizarea integrală nu este finalizată. Următorul audit: mici componente UI cu dependențe pure; auth/sync și PDF download/share nu se forțează fără contracte de stare/anulare compatibile.

## MOD-STAT-CARD-LIBRARY-20261013 — card statistic independent

Bază: InfoCard 834c58350910fa9f290c5fcb489f1d87188927ef, CI run 38392826791 5/5 SUCCESS. _StatCard din Dashboard/Admin devine ui/stat_card.dart, cu accent și widgetul leading injectate. Adapterul privat din main păstrează constructorul, parametrii și aserțiunea originale; calculează sectionAccent(title) și construiește același appAssetIcon/CircleAvatar înainte de a delega.

Corpul independent păstrează lățimea 230, raza 18, gradientul, paddingul 18, spațierile și stilurile. Test Flutter direct verifică aspectul și leading; test structural confirmă injectarea și adapterul. După extragerea InfoCard, summary_cards.dart conținea doar această clasă și directiva part of; analiza directă a fișierului a confirmat că nu există alte declarații sau efecte. Clasa este mutată, iar fișierul gol și directiva sa sunt eliminate ca rezultat demonstrat al conversiei, nu pe baza căutării lexicale a referințelor.

Inventar: 141 Dart (120 lib, 20 teste, 1 script), 74 parts, 67 biblioteci (46 lib, 20 test, 1 script), zero lipsuri/orfani/duplicate/cicluri. Local 152 Python, 1 Node, 4 verificări PDF/rutare și 117 hashuri protejate PASS; CI run `38393426208` pe `d77ee12d84778d7e0e8c3882f1515c4fc1db1d6c`: **5/5 SUCCESS**, inclusiv testul widget StatCard și web build.

PR #20 PDF/PV Magic/Million/download/web/Android și PR #29 OCR/financial/diurne rămân neatinse. Modularizarea integrală nu este finalizată. Următoarea analiză după CI: componente UI mici cu dependențe clare, apoi auth/sync numai prin adaptere explicite.

Următorul pas exact după acest checkpoint: audit read-only al dependențelor din AppBackdrop și PageShell, în special decodarea setărilor de background și branding-ul global. Nu există încă un adapter sigur fără contracte explicite pentru settings/logo; auth, sync și PDF download/share rămân amânate până se pot păstra anularea, starea și singletonurile fără modificări funcționale.

## MOD-APP-BACKDROP-LIBRARY-20261013 — adapter pentru fundalul aplicației

Bază: `502f891cdf412b2c97f159cc0752add78ef1c7b8`. `lib/ui/app_backdrop.dart` este acum bibliotecă Material independentă. Primește culoarea simplă deja rezolvată, assetul bundled, Base64-ul opțional, opacitatea și child-ul. Wrapperul privat `_AppBackdrop` păstrează constructorul vechi cu `AppSettings`, lookup-ul assetului, cheia `custom:`, fallbackul pentru Base64 absent/invalid, helperul de culoare și toate callsite-urile. Componenta păstrează clamp-ul opacității la 0–0,70, Stack-ul, decodarea tolerantă, imaginile și overlay-ul de contrast light.

Test Dart direct verifică child-ul, Base64 invalid și overlay-ul pentru teme light/dark; testele structurale verifică adapterul și contractele vizuale. Inventar: 142 fișiere Dart (120 lib, 21 teste, 1 script), 73 parts și 69 biblioteci (47 lib, 21 teste, 1 script); fără missing/orphan/duplicate/cicluri. Verificarea locală structurală: 84 teste PASS. Testul de boundary local raportează diferență numai pentru assetul sticker_24 din checkout-ul local (fișierul nu intră în commit); CI remote va valida snapshotul branch-ului. Flutter/Dart nu sunt instalate local.

Nu s-au schimbat PDF-urile, fonturile, download/share, Mapbox, rutarea, OCR, diurnele, permisiunile financiare sau PR #29. Hashurile PV Magic/Million și asseturile protejate rămân responsabilitatea testelor/CI pe tree-ul remote. PageShell rămâne part fiindcă citește branding prin `_activeAppSettingsForBranding` global mutabil; fără contract explicit de branding, extragerea nu este sigură. Modularizarea integrală nu este finalizată.

CI pentru commitul acestui lot: în așteptare. După 5/5 SUCCESS, următorul pas este audit read-only al următoarelor componente UI cu stare izolabilă; PageShell/auth/sync și download/share rămân blocate până la adaptere fără schimbarea contractelor.


## MOD-APP-BACKDROP-CI-CORRECTION-20261013

Runul CI `38426558633` pentru `a0306d882a602afe9234108917fdfe93a2f2dc80` a eșuat în două joburi din aceeași cauză: blobul snapshotului de dependențe a fost trunchiat la transmiterea din checkout și `json.loads` a raportat eroare la primul caracter. Celelalte trei joburi: Node projection și Firebase Functions PASS; Firestore emulator încă rula la verificare. Widget test nu a fost atins deoarece CI s-a oprit în testul Python. Am regenerat fișierul JSON complet (164.045 bytes), l-am verificat local cu parserul JSON și am transmis corecția ca blob complet. Urmează CI integral pe commitul corectiv; lotul nu este considerat validat până la 5/5.


## MOD-APP-BACKDROP-WIDGET-TEST-CORRECTION-20261013

CI run `38426801822` pe `5b2b3910ee2e3e5d5cb9d7145c7ff45744393838`: Python/security, Node, Functions și Firestore emulator **4/5 PASS**. Jobul Flutter a rulat testele structurale și a executat 84 teste Python; un widget test a eșuat deoarece finder-ul global număra fundalul Material/Scaffold (3 ColoredBox) în locul celor două straturi din AppBackdrop. Am restrâns aserțiunile light/dark la descendenții widgetului `AppBackdrop`; producția nu se modifică. Revalidare CI integrală în așteptare.


## MOD-APP-BACKDROP-WIDGET-TEST-SETTLE-20261013

CI run `38427180232`: Python/security, Node, Functions și Firestore emulator **4/5 PASS**; Flutter a executat 84 teste Python și 84 teste Flutter înainte să eșueze numai testul AppBackdrop pe fundal dark, deoarece animația de temă nu se stabilizase după înlocuirea MaterialApp. Am adăugat `pumpAndSettle()` înainte de assert, fără schimbări în componentă sau comportamentul aplicației. CI integral pentru corecție este în așteptare; nu avansăm lotul până la 5/5.


## MOD-APP-BACKDROP-CI-GREEN-20261013

Lotul AppBackdrop este validat pe commitul cod `64ab4000be91e3c3e0919b1419f35eec76be1a97` prin workflow run `38427425339`: **5/5 joburi SUCCESS** (Python/security, Node projection, Firestore emulator, Firebase Functions, Flutter tests + web build). Flutter suite/widget și verificarea bibliotecilor pure au trecut; web build a trecut. Corecțiile din acest lot au fost numai la snapshotul de inventar și la determinismul/finder-ele testului; componenta și comportamentul de producție nu s-au schimbat după extragere.

Inventar final: 142 Dart (120 lib, 21 tests, 1 script), 73 parts, 69 biblioteci; zero missing/orphan/duplicate/cicluri. `AppBackdrop` este bibliotecă independentă, iar `_AppBackdrop` menține adapterul de setări și callsite-urile. `PageShell` rămâne part din cauza brandingului global mutabil. Următorul lot exact, după audit read-only: evaluarea widgetului vizual din `install_app_buttons.dart` ca bibliotecă cu callbackuri, păstrând funcțiile și contractele Android/web în wrapperul existent. Nu se modifică fluxul de instalare/launch.


## MOD-INSTALL-BUTTON-VIEW-LIBRARY-20261013

Bază: `7e15d7511dc123d95c7f3d16e5c898fbff8c53de`. Widgetul vizual `_InstallAppButtons` este mutat într-o bibliotecă Material independentă `lib/ui/install_app_buttons_view.dart`, cu callbackuri explicite pentru Android și Apple și starea compactă. Wrapperul privat cu același constructor din main păstrează ambele callsite-uri existente (login și dashboard) și leagă aceleași funcții. Dialogurile, URL-ul din setări, mesajele de eroare și apelurile `launchUrl` rămân neschimbate în `install_app_buttons.dart`; contractele Android/web nu sunt rescrise.

Test Flutter nou: callbackurile sunt invocate o dată și etichetele full/compact rămân identice. Inventar: 144 fișiere Dart (121 lib, 22 teste, 1 script), 73 parts, 71 biblioteci; fără missing/orphan/duplicate/cicluri. Local 84 teste Python structurale, inventar JSON, Node syntax și diff-check PASS; Flutter/Dart indisponibil local.

Nicio schimbare PDF, Mapbox/rutare, OCR, diurne, permisiuni financiare sau fluxuri de autentificare. Modularizarea integrală nu este finalizată. CI pentru commitul acestui lot: în așteptare; următorul pas doar după 5/5 este auditul următoarelor componente UI mici cu stare explicită.


## MOD-INSTALL-BUTTON-VIEW-CI-GREEN-20261013

Lotul `install_app_buttons_view.dart` este validat pe commitul cod `dbf801cc9d4bdbb034300a098bc337ec97392bd6`, workflow run `38460150662`: **5/5 joburi SUCCESS**. Python/security, Node projection, Firestore emulator, Functions syntax/dependencies, Flutter tests, verificarea bibliotecilor independente și buildul web au trecut. Dialogurile și rutarea de instalare au rămas în partul existent și wrapperul main păstrează callbackurile pentru login/dashboard.

Inventar după lot: 144 Dart (121 lib, 22 teste, 1 script), 73 parts, 71 biblioteci, fără lipsuri/orfani/duplicate/cicluri. Următoarea acțiune exactă: audit read-only pentru `interactive_member_badges.dart` și `app_root_theme.dart`, inventariind overlay/state și branding/global settings; se extrage numai un widget pur dacă interfețele pot păstra aceiași callbackuri, setări și singletonuri. PageShell, auth/sync și PDF download/share rămân neatinse până la adaptere sigure. Modularizarea integrală nu este finalizată.


## MOD-INTERACTIVE-BADGE-PREVIEW-LIBRARY-20261013

Bază: `99c6852c37861c8fb36db67f5d8856b23cd9f871`. Stateful overlay-ul de previzualizare a badge-ului este separat în `lib/ui/interactive_badge_preview.dart`, cu builder `BadgeGraphicBuilder` injectat pentru randarea assetului. Wrapperul privat `_InteractiveBadgeIcon` păstrează parametrii și callbackul `_badgeGraphic`; funcțiile și adaptoarele badge din part rămân acolo. Overlay root, hover, pin la tap, închiderea la tap/exit și cleanup la dispose sunt păstrate. `app_root_theme.dart` rămâne part: setează `_activeAppSettingsForBranding` global și construiește tema din setări, deci nu are încă o limită sigură fără contract de stare/branding.

Test Dart nou acoperă previzualizarea mărită la tap, toggle/cleanup și hover/exit. Inventar: 146 Dart (122 lib, 23 teste, 1 script), 73 parts, 73 biblioteci; fără missing/orphan/duplicate/cicluri. Verificările locale Python structurale (84), inventory JSON, Node syntax și diff-check PASS; Flutter/Dart indisponibil local.

Nicio schimbare la utilitarele sticker/emoji partajate, chat, PDF, Mapbox, OCR, diurne sau permisiuni. Modularizarea integrală nu este finalizată. CI pentru acest lot este în așteptare; următorul pas numai după 5/5 este un nou audit read-only pentru un widget cu stare locală fără dependențe globale.


## MOD-INTERACTIVE-BADGE-CI-FIX-20261013

Runul `38461011616` pe `2266f53b41d30b62dab304d1f6649eb1aa1a38af`: Python/security, Node, Functions și Firestore **4/5 PASS**. Flutter a eșuat la compilarea testului hover deoarece WidgetTester din Flutter CI nu expune `sendMouseMoveTo`. L-am înlocuit cu `TestGesture` creat pentru `PointerDeviceKind.mouse`, cu add/move/remove pointer explicit; codul de producție rămâne identic. Urmează rerun integral, lotul nu este validat până la 5/5.


## MOD-INTERACTIVE-BADGE-CI-IMPORT-FIX-20261013

Rerunul `38461236529` a trecut Python/security, Node, Functions și Firestore **4/5**. Flutter a găsit importul lipsă pentru `PointerDeviceKind` folosit de `TestGesture`; am adăugat importul selectiv `dart:ui`. Codul de producție nu se modifică. CI integral pentru testul corectat este în așteptare.


## MOD-INTERACTIVE-BADGE-CI-HOVER-FIX-20261013

Runul `38461449964`: tap/pin/toggle a trecut, iar celelalte patru joburi au trecut. Cazul hover/exit nu a produs onExit după mutarea la un punct de pe suprafață acoperită de overlay. Testul elimină acum pointerul mouse explicit după hover, emițând pointer removal către MouseRegion; overlay-ul trebuie să dispară. Componenta nu s-a modificat. Rerun CI integral în așteptare.


## MOD-INTERACTIVE-BADGE-CI-GREEN-20261013

Lotul `interactive_badge_preview.dart` este validat pe commitul cod `c393e891546fc997a0811a70d9cbf4d77e49f389`, workflow run `38461684523`: **5/5 joburi SUCCESS** (Python/security, Node, Firestore emulator, Functions, Flutter/widget + web build). Testele directe verifică pin/toggle, preview la hover și închiderea/cleanup la pointer exit. Inventar: 146 Dart (122 lib, 23 tests, 1 script), 73 parts, 73 biblioteci, fără missing/orphan/duplicate/cicluri.

Audit read-only: `app_root_theme.dart` citește setări mutable și scrie `_activeAppSettingsForBranding`; nu are încă un contract independent sigur. Următorul lot exact: extragerea UI-ului `auth_status_components.dart` într-o bibliotecă Material cu `logo` și `onSignOut` injectate; wrapperele existente păstrează constructors/callsites și apelul Firebase Auth. Nu schimbă fluxul de autentificare/permisiuni.


## MOD-AUTH-STATUS-VIEWS-LIBRARY-20261013

Bază: `8798481c5b7eb5fc6e5c00ad72d85c9878bf1b36`. UI-ul de stare Firebase a fost desprins în `lib/ui/auth_status_views.dart` ca bibliotecă Material independentă. `FirebaseLoadingView` primește logo-ul construit de adapterul main; `FirebaseErrorView` primește callbackul de sign-out. Wrapperele private păstrează constructorii folosiți de AuthGate, iar apelul `FirebaseAuth.instance.signOut()` rămâne în main. Doar un part UI a fost convertit; fluxul de autentificare, permisiunile și serviciile nu se schimbă.

Testele Dart verifică mesajul/logo/progresul și forwardarea callbackului de sign-out. Inventar: 147 Dart, 72 parts, 75 biblioteci; fără missing/orphan/duplicate/cicluri. Testele structurale locale (84), inventarul JSON, node --check și diff-check PASS; Flutter/Dart indisponibil local.

PR #29, OCR, regulile/datele financiare și diurnele rămân neatinse. CI pentru lotul curent în așteptare; următorul pas după 5/5 este audit read-only al componentei next cu dependențe private mici. Modularizarea completă nu este finalizată.


## MOD-AUTH-STATUS-VIEWS-CI-GREEN-20261013

Lotul `auth_status_views.dart` este validat pe commitul cod `cd161c2d9b361e81dd5b2014f3ab08dc55db829f`, workflow run `38462847310`: **5/5 joburi SUCCESS**. Python/security, Node, Firestore emulator, Functions, Flutter/unit/widget, biblioteci independente și web build au trecut.

Inventar: 147 Dart, 72 parts, 75 biblioteci; fără missing/orphan/duplicate/cicluri. Doar UI de încărcare/eroare a devenit standalone; callsite-urile AuthGate și Firebase Auth rămân în adapters main.

Următorul lot read-only: verificarea `bootstrap/firebase_bootstrap_error_app.dart` pentru extragere ca ecran Material cu mesaj injectat. Nu se modifică inițializarea Firebase sau recuperarea erorilor. Modularizarea integrală nu este finalizată.


## MOD-FIREBASE-BOOTSTRAP-ERROR-VIEW-20261013

Bază: `a9a520992454222a03761b4b4c3728d290a65d8e`. Ecranul de eroare Firebase a devenit bibliotecă Material independentă în `lib/bootstrap/firebase_bootstrap_error_app.dart`; widgetul public primește doar mesajul. Wrapperul privat din main păstrează callsite-ul `runApp(_FirebaseBootstrapErrorApp(message: e.toString()))`. Inițializarea Firebase, tratarea excepției și textul/capabilitatea de copiere selectivă rămân aceleași.

Test Flutter direct verifică instrucțiunile iOS/web/Android și mesajul SelectableText. Inventar: 148 Dart, 71 parts, 77 biblioteci, fără lipsuri/orfani/duplicate/cicluri. Testele structurale locale (84), parserul de inventar, Node syntax și diff-check PASS; Flutter/Dart indisponibil local.

PR #29 și logica de autentificare/permisiuni nu sunt modificate. CI pentru lot în așteptare; următorul pas după 5/5 este audit read-only pentru un widget UI rămas cu contract mic. Modularizarea completă nu este finalizată.


## MOD-FIREBASE-BOOTSTRAP-ERROR-CI-GREEN-20261013

Lotul `firebase_bootstrap_error_app.dart` a fost convertit la bibliotecă Material independentă și validat pe commitul cod `3b21f31e37b29c61a0d749109c98ef65f69fdc94`, workflow run `38463643897`: **5/5 SUCCESS**. Widget test, verificarea pură, build web și toate joburile de Node/Python/Functions/Firestore au trecut. Wrapperul privat păstrează apelul `runApp` și mesajul primit; initialization/excepția rămân neschimbate.

Inventar: 148 fișiere Dart, 71 parts, 77 biblioteci; zero missing/orphan/duplicate/cicluri. Următorul audit read-only: modelul `_VerifiedLocationFix`, cu atenție la păstrarea exactă a catalogului Magic/Million și a callsite-urilor de import. Nu se editează datele sau algoritmii din map. Modularizarea integrală nu este finalizată.


## MOD-VERIFIED-LOCATION-FIX-LIBRARY-20261013

Bază: `490ce02a068d642a409cd9c6de384fa08d6dc4bc`. Modelul de date `_VerifiedLocationFix` a devenit `VerifiedLocationFix` într-o bibliotecă Dart independentă cu import explicit pentru `LocationStatus`. Wrapperul privat extinde modelul și păstrează numele, constructorul/defaulturile și callsite-urile din main/map. Catalogul Magic/Million și algoritmul de import nu au fost rescrise. Testul structural fixează SHA-256 al întregului bloc `_verifiedLocationFixes`: `0d00e992bc52e500a87b307f601ec6486dbb5d6f6dd0e6db93f0cacec267a812` (8.192 bytes); testul Dart verifică defaulturi și semantica hasGps.

Inventar: 149 Dart, 70 parts, 79 biblioteci; fără missing/orphan/duplicate/cicluri. Teste Python structurale 85 PASS, parserul inventory și Node syntax PASS; Flutter/Dart indisponibil local. CI lot în așteptare. PR #20 PDF Magic/Million, PR #29 și regulile/datele financiare rămân neatinse.


## MOD-VERIFIED-LOCATION-FIX-CI-GREEN-20261013

Lotul `verified_location_fix.dart` este validat pe commitul cod `926f77b1d04342a696331cf9a7f967a1299c3f79`, workflow run `38464464699`: **5/5 SUCCESS**, inclusiv Flutter/widget, web build, emulator Firestore, Node, Functions și Python/security. Blocul de date `_verifiedLocationFixes` a rămas hash-identic (`0d00e992bc52e500a87b307f601ec6486dbb5d6f6dd0e6db93f0cacec267a812`, 8.192 bytes); wrapperul păstrează semantica/defaulturile și import actions.

Inventar: 149 Dart, 70 parts, 79 biblioteci; fără missing/orphan/duplicate/cicluri. Următorul pas exact: audit read-only al `ui/dashboard_map_components.dart` și al altor widgeturi de dashboard pentru callbackuri/stare implicite; nu extrage UI dependent de starea MapPage până nu există un adapter clar. Modularizarea completă nu este finalizată.


## MOD-DASHBOARD-MAP-COMPONENTS-LIBRARY-20261013

Bază: `d3906ef90466b3a3e32e71933301ec6f1c0524fb`. Auditul read-only a confirmat că `_StatMini` și `_MapStatusLegend` sunt widgeturi vizuale fără stare de aplicație, callbackuri sau acces la Firebase/Mapbox. `lib/ui/dashboard_map_components.dart` a devenit bibliotecă Material independentă; wrapper-ele private din `main.dart` păstrează constructorii și callsite-urile din ProgramPage/MapPage. Structura, paddingul, culorile, dimensiunile, iconul și etichetele au rămas aceleași. Nu s-au schimbat algoritmii rutării sau codul de hartă.

Au fost adăugate teste Flutter directe pentru conținutul/dimensiunea lui StatMini și culoarea/eticheta legendei, plus verificarea structurală a importului, absenței directivei part și wrapperelor. Snapshotul Dart actualizat include 150 fișiere (122 lib, 27 teste, 1 script), **69 parts** și **81 biblioteci**; zero ținte lipsă, parts orfane, duplicate în aceeași bibliotecă sau cicluri import/export. Local: 85 teste Python PASS, JSON valid, `node --check functions/index.js` și `git diff --check` PASS. SDK Flutter/Dart nu este disponibil local.

CI pentru commitul de cod `d3906ef90466b3a3e32e71933301ec6f1c0524fb`, workflow run [38465871229](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38465871229): **5/5 SUCCESS** (Python/security, Node, Functions, emulator Firestore, Flutter tests + web build). PDF-urile Magic/Million, PDF generators/helpers, PR #20, Mapbox singleton/rutare, PR #29, OCR, datele/regulile financiare, diurnele și permisiunile nu au fost modificate. PR #28 rămâne Draft/Open, fără merge/deploy.

Următorul pas exact: audit read-only al widgeturilor rămase din Home/Dashboard pentru dependențe de branding global și stare privată; extrag numai când adapterul păstrează callsite-urile și API-urile. PageShell/branding global, serviciile auth/sync și contractul PDF de anulare/download/share rămân blocate până la interfețe compatibile. Modularizarea integrală nu este finalizată.


## MOD-SECTION-VISUAL-HELPERS-LIBRARY-20261014

Bază PR #28 `e37552a5b90d4f967e5db8cdf77c61120998e2d7`, CI-ul bazei run `38466275696` 5/5 SUCCESS. `lib/ui/section_visual_helpers.dart` devine bibliotecă Material independentă cu import explicit pentru `AppSettings`. Main păstrează fațada de import/export și adaptorul privat `_plainBackgroundColor`; toate părțile și callsite-urile publice rămân compatibile. Codul helperilor este identic după redenumirea singurei funcții private necesare exportului.

Testul Flutter nou verifică mappingurile sectionAccent, toate fundalurile light/dark și conținutul/culorile SnackBar. Local: 154 teste Python PASS, 3 teste Node PASS, auditul inventarului Dart PASS (151 fișiere, 68 parts, 83 biblioteci; fără ținte lipsă, orfani, duplicate sau cicluri), protecțiile PDF/Mapbox PASS și `git diff --check` PASS. SDK Flutter/Dart indisponibil local; CI run [38474876381](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38474876381), commit `c992eb8e35561e47c585cc8d40e093d0b3dd6c19`: **5/5 SUCCESS**, inclusiv Flutter/widget și build web.

Nu s-au atins PDF-urile și fluxurile PR #20, PR #29/OCR, rutarea/Mapbox, auth/sync, date/reguli Firebase sau billing. Fără merge/deploy/APK. Modularizarea completă rămâne deschisă. Următorul pas: auditarea read-only a următorului helper vizual independent, fără extragerea PageShell/temei globale.


## MOD-BRANDING-THEME-HELPERS-LIBRARY-20261014

Bază: PR #28 `ced7d8d9cf4dbb8d75e77345c3b43518c5d0e38a`, după CI 5/5 pe lotul anterior. `lib/ui/branding_theme_helpers.dart` devine bibliotecă Material independentă, cu importuri explicite Flutter foundation/material și `AppSettings`. Main păstrează adaptoarele private pentru fonturi, catalogul const al fundalurilor/logo-urilor și alegerea assetului; `appBrandLogo` rămâne aceeași fațadă publică. Corpurile helperilor/cataloagelor sunt identice după normalizarea numelor publice necesară separării. `app_root_theme.dart`, PageShell, brandingul global mutabil și callsite-urile rămân nemodificate.

Test Dart direct adăugat pentru aliasuri font, familii dependente de platformă, catalog și fallback logo, dimensiunile widgetului. Inventar regenerat: 152 fișiere Dart, 67 parts, 85 biblioteci totale; zero ținte lipsă, parts orfane, declarații duplicate în aceeași bibliotecă ori cicluri import/export. Local: 154 teste Python PASS, 3 Node PASS, audit repository PASS, `git diff --check` PASS; Flutter/Dart indisponibile local, CI nou necesar.

PDF/PV/download/share PR #20, PR #29/OCR/diurne, Mapbox, auth/sync, date/rules Firebase și billing nu sunt modificate. Fără merge, deploy sau APK publicat. După CI: audit read-only pentru următorul helper UI independent; tema globală și PageShell rămân limitate de contractul de branding.


## MOD-TEAM-SELECTOR-LIBRARY-20261014 — selector de echipă standalone

**Bază validată pentru lotul anterior:** branding/font helpers pe commit `a9bca2494a547e07b0b4a1ae4369207737cdbbe7`, CI run [38475744399](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38475744399) **5/5 SUCCESS**.

`lib/teams/team_selector.dart` devine bibliotecă Material independentă, cu import explicit pentru modelele `Team`; accentul secțiunii este injectat. Wrapperul `_TeamSelector` din `main.dart` păstrează constructorul/callsite-urile și transmite același `sectionAccent('Echipe')`. Dropdown-ul, `selected.clamp`, etichetele, constrângerile și forwardarea callbackului rămân neschimbate.

Test Flutter direct nou verifică echipa inițial selectată, culoarea pictogramei și selectarea celei de-a doua echipe prin callback. Inventarul regenerat: 153 fișiere Dart, 66 parts, 87 biblioteci totale; zero ținte lipsă, parts orfane, duplicate în aceeași bibliotecă și cicluri. Local: 154 teste Python PASS, 3 Node PASS, `audit_repository.py` și `git diff --check` PASS; SDK Flutter/Dart indisponibil local. CI pe commitul `84cd1fced0c3037a071b8441ff71ac57febec31f`, run [38476310797](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38476310797): **5/5 SUCCESS** (Python/security, Node, Functions, emulator Firestore, Flutter/widget + web build).

Nu sunt schimbate programele, permisiunile, echipele stocate, datele/rules Firebase, finanțele, OCR, PDF/PV, Mapbox ori PR #29. Fără merge/deploy/APK. Următorul pas numai după 5/5: audit read-only al următorului widget cu adapter simplu.


## MOD-BACKUP-CODEC-LIBRARY-20261014 — codec de backup standalone

**Bază validată:** TeamSelector pe commitul `84cd1fced0c3037a071b8441ff71ac57febec31f`, CI run [38476310797](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38476310797), **5/5 SUCCESS**. Lotul precedent este complet; nu a fost reluat.

`lib/admin/backup_codec.dart` devine bibliotecă Dart independentă și importă explicit `cloud_firestore`. Logica recursivă de serializare a `Timestamp`/`GeoPoint`, a hărților și listelor este mutată textual; redenumirile la `encodeBackupValue`/`decodeBackupValue` permit exporturile. `main.dart` păstrează `_backupEncode`/`_backupDecode` ca adaptoare private, iar `admin_backup_actions.dart` și fluxurile existente nu își schimbă apelurile ori formatul.

Test Dart direct nou verifică Timestamp și GeoPoint în structură imbricată, liste/scalari și date-marker necunoscute. Inventarul regenerat: **154 fișiere Dart, 65 parts, 89 biblioteci totale**, fără ținte lipsă, părți orfane, declarații duplicate sau cicluri. CI pe commitul `4579e6ab11f9b0ec9370feb28e8cee34f5c25483`, run [38476811197](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38476811197): **5/5 SUCCESS** (Python/security, Node, Functions, emulator Firestore, Flutter tests + web build). SDK Flutter/Dart nu este disponibil local.

Nu s-au schimbat exportul/restaurarea, preflight-ul restaurării, colecțiile, datele/rules Firebase, permisiunile, finanțele, OCR, PDF/PV sau PR #29. Fără merge, deploy, APK publicat ori Firebase producție/billing. Modularizarea completă rămâne neterminată.


## MOD-SCHEDULE-CARD-LIBRARY-20261014 — cardul complet de program standalone

**Bază validată:** codec-ul de backup pe commitul `4579e6ab11f9b0ec9370feb28e8cee34f5c25483`, CI run [38476811197](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38476811197), **5/5 SUCCESS**.

`lib/schedule/schedule_card_full.dart` devine bibliotecă Flutter independentă. Folosește importuri explicite pentru modele, categorii, badge, dată, accent și card informativ. `main.dart` păstrează `_ScheduleCardFull` cu același constructor pentru apelanții existenți și îl redirecționează la API-ul public `ScheduleCardFull`. Condițiile de editare/închidere, textul pentru progres, încrederea Learning, badge-urile, cheia de reorder, callbackurile și filtrul înregistrărilor finalizate rămân aceleași.

Teste Flutter directe noi verifică randarea datei/propunerii/progresului, callbackurile add/remove/reorder și dezactivarea acțiunilor pe programe închise. Inventar regenerat: **155 fișiere Dart, 64 parts, 91 biblioteci totale**, fără ținte lipsă, parts orfane, declarații duplicate sau cicluri. Local: **85 teste Python PASS, 3 teste Node PASS**, audit repository PASS și `git diff --check` PASS; Flutter/Dart SDK indisponibil local. CI inițial run [38477458604](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38477458604) a trecut 4/5; testul Flutter pentru program închis a arătat că Flutter 3.47 cere un callback de reorder nenul. Am păstrat intenția de blocare: drag handles implicite sunt dezactivate la `closed`/fără editare, iar callbackul furnizat rămâne legat; testul verifică asta. Corecția a fost validată pe commitul `3ad28f94e74c1766ce50416bcc9e06fa5418666c`, CI run [38477747207](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38477747207): **5/5 SUCCESS**.

Nu se schimbă datele, permisiunile, algoritmii de program/Learning sau operațiile Firestore. PageShell/tema globală, auth/sync, PDF/PV, Mapbox și PR #29 rămân neatinse. Fără merge/deploy/APK/Firebase producție/billing.


## MOD-INTERACTIVE-MEMBER-BADGES-LIBRARY-20261014 — helperi de badge membri standalone

**Bază validată:** corecția cardului de program pe commitul `3ad28f94e74c1766ce50416bcc9e06fa5418666c`, CI run [38477747207](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38477747207), **5/5 SUCCESS**.

`lib/ui/interactive_member_badges.dart` va deveni bibliotecă Material independentă cu importuri explicite pentru catalogul de iconuri/badge-uri, definițiile de funcții, căutarea ID-urilor, accente și preview. Main păstrează funcțiile cu numele folosite în paginile, chatul și adminul existent; componenta privată de afișare a badge-ului va locui în modulul nou, iar wrapper-ele din main vor delega. Ordinea, limita de trei, filtrele active, eliminarea duplicate/coordonatorului și maparea `badge_machine` la `badge_worker` rămân aceleași.

Teste Flutter directe noi vor acoperi cheile în ordine, filtrele active/duplicate și badge-strip-ul cu iconuri fallback. Inventar regenerat: **156 fișiere Dart, 63 parts, 93 biblioteci totale**, fără ținte lipsă, părți orfane, duplicate sau cicluri. Local: **86 teste Python PASS, 3 Node PASS**, audit repository PASS și `git diff --check` PASS; Flutter/Dart SDK indisponibil local. CI inițial run [38478225817](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38478225817) a trecut 4/5; doar două aserțiuni ale testului Dart nou au folosit fixture-uri trunchiate de constructorul existent `FunctionDefinition` (care păstrează maximum trei badge-uri). Celelalte 104 teste Flutter și patru joburi CI au trecut. Fixture-urile au fost corectate, fără modificări ale codului aplicației; Corecția de fixture a fost validată pe commitul `703639a0f6df02449f2615cb25d00517fbda570f`, CI run [38478479946](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38478479946): **5/5 SUCCESS**.

Nu se schimbă definițiile sau drepturile funcțiilor, conturile, membrii, permisiunile, auth ori date Firebase. PR #20, #29, rutarea/Mapbox, programele/Learning și operațiile financiare rămân neatinse. Fără merge/deploy/APK/Firebase producție/billing.


## RELAUNCH-CHECKPOINT-20261014 — reluare după `e37552a5`, oprire la limita sigură

Checkpoint istoric la `703639a0f6df02449f2615cb25d00517fbda570f` (CI run [38478479946](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38478479946) **5/5 SUCCESS**; PR #28 rămâne Open/Draft, baza `main` neschimbată. Reluarea de la SHA validat `e37552a5b90d4f967e5db8cdf77c61120998e2d7` a continuat cu helperii vizuali/branding, TeamSelector, codec-ul backup, ScheduleCardFull și badge helperii. Loturile deja validate nu au fost repetate.

Inventar curent: **156 fișiere Dart, 63 parts, 93 biblioteci totale**, zero ținte lipsă, părți orfane, duplicate în aceeași bibliotecă sau cicluri detectate. Snapshot: `docs/DART_DEPENDENCIES_2026-10-13.json`. Testele noi Flutter au fost validate în CI; local au trecut 86 teste Python, 3 teste Node, auditul repository și `git diff --check`. CI #804 a scos la iveală aserțiunea Flutter pentru lista de reorder la programe închise; callbackul rămâne legat, dar drag handles sunt dezactivate, apoi CI #805 a trecut 5/5. CI #806 a identificat exclusiv fixture-uri noi trunchiate de constructorul `FunctionDefinition`; fixture-urile au fost corectate și run #807 a trecut 5/5.

În acest punct, componentele mici rămase auditate sunt legate de auth, Firestore/stare privată, branding global sau lansarea URL-urilor externe. Nu există un lot structural mai mic cu adaptere explicite și contracte deja acoperite care să poată fi făcut fără extinderea schimbării către acele funcționalități. **Modularizarea completă rămâne deschisă** pentru o etapă cu adaptere/teste dedicate; nu se declară terminată.

PR #29/OCR/diurne/finanțe, PR #20 PDF/PV Magic/Million/download/share, Mapbox singleton, reguli/config/date Firebase, billing și producția rămân protejate. Fără merge în main, deploy, publicare APK sau modificări de producție.


## MOD-ACCOUNT-ACCESS-VIEWS-LIBRARY-20261014 — paginile de acces separate de auth

Bază validată înaintea lotului: PR #28 HEAD 9020b2ef9d25ef07e9c717b13b1a7a9161cfb915, CI run 38478795300 **5/5 SUCCESS**. Paginile PendingApprovalPage și MissingProfilePage păstrează constructorii folosiți de AuthGate; conținutul Material este extras în lib/auth/account_access_views.dart, cu logo, decorul de fundal și callbackul sign-out injectate. Adaptoarele din part-ul existent continuă să folosească aceleași AppSettings, FirebaseUserProfile și FirebaseAuth.instance.signOut(). Rutarea AuthGate, citirea profilului, permisiunile, textele și configurația Firebase nu se schimbă.

Testele Flutter directe verifică ambele ecrane, backdrop/logo/email și forwardarea sign-out. Snapshotul inventarului este regenerat: **158 fișiere Dart (123 lib, 34 test, 1 script), 63 parts, 95 biblioteci**, fără ținte lipsă, parts orfane, declarații duplicate în aceeași bibliotecă sau cicluri import/export. CI run 38480354362 pentru commitul b73994b60f3ba5898e44d512f98139905ee55bda este **5/5 SUCCESS**; SDK Flutter/Dart nu este disponibil local. Nu s-au atins PR #20/#29, OCR/diurne, PDF/PV, Mapbox, date/reguli Firebase, billing sau producția; fără merge, deploy ori APK publicat.

**Următorul pas după 5/5:** audit read-only al componentelor rămase; auth streams, FirebaseUserProfile/QuickAccounts, bootstrap, PageShell și URL launchers nu se mută fără contracte specifice și teste de compatibilitate. Modularizarea completă rămâne deschisă.

## LATEST CHECKPOINT — continuare după checkpointul inițial e37552a5

Checkpointul inițial cu HEAD 703639a0f6df02449f2615cb25d00517fbda570f a fost urmat de loturile documentate mai sus și de HEAD-ul de documentație 9020b2ef9d25ef07e9c717b13b1a7a9161cfb915 (CI run 38478795300, 5/5). Lotul AccountAccessViews de mai sus este noul lot curent și CI-ul lui urmează după commit. Se păstrează protecția tuturor celorlalte PR-uri și a producției.



## MOD-ACCOUNT-ACCESS-VIEWS-CI-GREEN-20261014

Lotul AccountAccessViews a fost validat pe commitul b73994b60f3ba5898e44d512f98139905ee55bda, workflow run [38480354362](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38480354362): **5/5 SUCCESS**. Testele widget, verificarea bibliotecilor fără motor Flutter, buildul web, Python/security, Node, Functions și emulatorul Firestore au trecut.


## MOD-APP-CAPABILITIES-VIEW-LIBRARY-20261014 — tabul Capacități standalone

Bază validată: AccountAccessViews pe commitul b73994b60f3ba5898e44d512f98139905ee55bda, CI run 38480354362 **5/5 SUCCESS**. Helperul vizual și lista statică din tabul Capacități sunt mutate textual în lib/ui/app_capabilities_view.dart. AppInformationPage păstrează setările/brandingul, pagina cu taburi, istoricul static, streamul updateHistory, formularul și scrierile admin în Firestore. Taburile, textele, pictogramele, stilurile și ordinea secțiunilor nu se schimbă.

Testul Flutter direct verifică secțiunea zilnică, textul ei și secțiunea Web după scroll. Snapshotul inventarului: **160 fișiere Dart (124 lib, 35 test, 1 script), 63 parts, 97 biblioteci**; fără ținte lipsă, parts orfane, duplicate sau cicluri. CI run 38480743062 pentru commitul ecaf732538b8939dbd69835f66883aa05dffe3a5 este **5/5 SUCCESS**.

Nu se schimbă istoricul, rolurile, permisiunile, datele/rules Firebase sau textele de produs. PR #20/#29, PDF/PV, OCR/diurne, Mapbox, billing și producția rămân neatinse. Fără merge, deploy ori APK publicat.

## LATEST CHECKPOINT — 2026-10-14

HEAD de cod anterior: b73994b60f3ba5898e44d512f98139905ee55bda, run CI 38480354362 **5/5 SUCCESS**. Lotul curent este AppCapabilitiesView și este comis în continuare pe PR #28; CI pentru el urmează. Ultimul inventar complet înaintea acestui lot: 158 fișiere, 63 parts, 95 biblioteci; inventarul lotului curent este 160/63/97.


## FINAL CHECKPOINT — 2026-10-14, după loturile AccountAccessViews și AppCapabilities

PR #28 HEAD de cod: ecaf732538b8939dbd69835f66883aa05dffe3a5, CI run [38480743062](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38480743062) **5/5 SUCCESS**. Lotul anterior AccountAccessViews este validat separat pe b73994b60f3ba5898e44d512f98139905ee55bda, run 38480354362 **5/5 SUCCESS**. PR rămâne Draft/Open, fără merge; main și configurația de producție nu s-au schimbat.

Inventar: **160 fișiere Dart (124 lib, 35 test, 1 script), 63 parts, 97 biblioteci**, fără ținte lipsă, parts orfane, duplicate în aceeași bibliotecă ori cicluri import/export. Testele directe pentru cele două loturi au trecut în CI, împreună cu Python/security, Node, Functions, Firestore emulator, verificarea domeniilor fără motor Flutter și buildul web.

Auditul read-only pentru următoarele părți nu a identificat încă un modul la fel de mic și independent: QuickAccounts gestionează parole în SecureStorage; FirebaseUserProfile/AuthGate și inițializarea sunt legate de identitate/streams/startup; AppInformationPage păstrează updateHistory și scrierile admin; PageShell/tema folosesc branding global; install flow folosește URL launch extern. Aceste zone rămân pentru loturi viitoare cu interfețe și teste specifice. **Modularizarea completă nu este finalizată; 63 parts încă așteaptă separare graduală.**

PR #20, PR #29/OCR/diurne, PDF/PV, Mapbox, date/rules/config Firebase, billing și producția rămân neatinse. Fără merge, deploy, APK publicat sau modificări în producție.


## MOD-IDENTITY-LIBRARY-20261014 — profil Firebase independent, Issue #30

Bază verificată: PR #28 HEAD `3be7a09b6a28122bfae23e8ff779e7765a24cd39`, CI run `38481002554` **5/5 SUCCESS**. Issue #30 a fost citit integral; regulile funcționale deja aprobate nu se reiau și Vision/Error Log rămâne ulterior pe PR dedicat.

`lib/auth/firebase_user_profile.dart` este bibliotecă independentă cu importuri explicite Firebase Auth, Firestore și enumuri. Clasa, constructorul și factory-ul din snapshot păstrează datele/fallbackurile. Singura redenumire este metoda statică privată `_functionFrom` → `functionFrom`, folosită explicit și în adapterul directorului; corpurile clasei și adapterului sunt text-identice după normalizarea acestei redenumiri. Main importă/re-exportă API-ul existent. Nicio citire/scriere, autorizare, flux AuthGate sau regulă de cont nu s-a schimbat.

Testele Dart directe acoperă profil absent, fallback email/nume/status, precedență admin, nickname, conversia permissivă/mutabilitatea functionIds și lookup-ul comun de funcții. Local: **155 Python, 3 Node PASS**, syntax Functions și diff-check PASS. Flutter/Dart indisponibile local; CI pe SHA-ul lotului urmează. Inventar regenerat cu scriptul: **161 Dart (124 lib, 36 teste, 1 script), 62 parts, 99 biblioteci**, zero missing/orphan/duplicate/cicluri.

Următorul lot: izolarea stocării QuickAccounts cu dependență securizată explicită și teste fără acces la credentiale reale; cheia, formatul JSON, plafonul de două conturi și tratarea erorilor trebuie păstrate. Detalii în `docs/MODULARIZARE_AUTH_SERVICII_2026-10-14.md`. PR #19/#20/#21/#29 și producția sunt protejate; fără merge/deploy/APK/rules/config/date live/billing. Modularizarea integrală și auditul diferențial ulterior rămân deschise.


## MOD-QUICK-ACCOUNT-STORE-20261014 — secure storage injectat, fără migrare

Lotul de identitate `d4d90a7796bb6899f8d9fac36e44db480d2ba82c`, run CI `38482963824`: **5/5 SUCCESS**, inclusiv Flutter tests/web. Următorul lot izolează `QuickAccount` și `QuickAccountStore` într-o bibliotecă pur Dart (`dart:convert`), cu callbackuri read/write/delete. Adaptorul main păstrează instanța const FlutterSecureStorage, opțiunile implicite și cheia `andi_carpeta_quick_accounts_v1`; wrapper-ele load/save și forget din Settings păstrează aceleași operații. În Settings se schimbă numai calificarea tipului.

Echivalența modelului, corpurilor load/save și Settings a fost verificată după substituția numelor/I-O. JSON invalid/non-list revine la listă goală; erorile SecureStorage se propagă; la load nu se introduce o limită nouă, iar save păstrează deduplicarea case-insensitive și primele două chei în ordinea existentă. Nu sunt mutate parole către alt mediu sau logate; testele folosesc exclusiv date sintetice.

Local: **155 Python + 3 Node PASS**, syntax Functions, body-equivalence, diff-check și inventar PASS. Snapshot: **162 Dart (124 lib, 37 teste, 1 script), 61 parts, 101 biblioteci**, fără lipsuri/orfani/duplicate/cicluri. Testele Dart noi verifică fallbackul, filtrarea, limita, ordinea, delete la listă goală și propagarea erorilor; CI pe SHA-ul lotului urmează.

După 5/5: audit bootstrap pentru separarea selecției native/configurate de apelurile SDK, păstrând exact handlerul FCM top-level/pragma și fallbackul iOS. AuthGate și restul abonărilor nu se modifică. Fără Vision funcțional în #28, fără merge/deploy/APK/date live/rules/config/billing/migrări; PR-urile independente rămân protejate.


## MOD-FIREBASE-INITIALIZATION-POLICY-20261014 — bootstrap testabil, handler păstrat

Lotul QuickAccounts `0be4bce7d5054dc641b92f48dc7e6c94247438ac`, run `38483520307`: **5/5 SUCCESS**. Bootstrap are acum un helper pur Dart cu predicate/acțiuni injectate. Main păstrează condiția iOS cu același short-circuit și evaluează `DefaultFirebaseOptions.currentPlatform` exclusiv în callbackul configurat. Constanta VAPID și handlerul FCM cu pragma sunt text-identice; verificarea `Firebase.apps.isEmpty`, înscrierea handlerului și secvența main nu se schimbă. Nu se adaugă retry, app Firebase, fallback nou ori configurație.

Teste Dart: selecție unică, predicate o singură dată, await complet, acțiunea nealeasă lazy, erori propagate fără retry/fallback. Local **155 Python + 3 Node PASS**, syntax Functions, verificările de echivalență, diff și inventar PASS. Inventar **163 Dart (124 lib, 38 teste, 1 script), 60 parts, 103 biblioteci**, fără missing/orphan/duplicate/cicluri. CI pentru SHA-ul lotului urmează.

Audit read-only PR #19/#21: există deja `lib/vision/vision_error_log.dart`, `vision_error_telemetry.dart`, `vision_diagnostics_page.dart` și teste pe aceste ramuri. Ele sunt resurse de reutilizat ulterior, nu sunt aduse/duplicate/activate în #28. Head-uri inspectate: #19 `d4da2872a566eba258e82b8597c023e03ceb9b56`, #21 `d18b2523a31ead7eb65a04fe92a21276a4155c97`. Documentele vechi de pe #28 care descriu Vision ca neimplementat se referă la acea ramură/instantaneu; nu infirmă codul existent separat.

Următorul lot după 5/5: audit/adaptor explicit pentru sursele AuthGate (currentUser, auth changes, profile/meta streams), fără rescrierea lifecycle-ului și cu teste de reconectare/profil absent/cancel. Issue #30 și regulile aprobate rămân referința. Fără merge/deploy/APK/Vision funcțional nou/rules/config/date live/billing/migrări.


## MOD-AUTH-GATE-SOURCES-20261014 — surse read-only injectate, lifecycle păstrat

Bootstrap `75279637b52cf588a26a6ec2d0a6d1a0b044e898`, run `38484010280`: **5/5 SUCCESS**. AuthGate are acum un port explicit `AuthGateSources` pentru currentUser, authStateChanges, meta/uiSettings și profile snapshots. Adapterul main construiește callbackuri lazy către aceleași SDK-uri/query-uri, inclusiv `includeMetadataChanges: true`; sursele se fixează la initState, ca abonările existente. Constructorul păstrează apelanții existenți și permite injectare opțională pentru teste.

Echivalența întregului fișier AuthGate a fost verificată după substituția strictă a surselor și adăugarea injecției. Callbackurile/starea, fallback currentUser, UID guards, păstrarea profilului la reconectare/erori, ruta de pagină și cancel/dispose nu sunt rescrise. AuthGate rămâne part; nu se forțează separarea UI de HomePage înaintea contractelor corespunzătoare.

Teste widget cu streamuri în memorie și User/DocumentSnapshot fake: profil absent, pending, null auth tranzitoriu cu sesiune prezentă, eroare de profil după profil valid, schimbare UID și cancel vechi, setări UI/duplicat/dispose, eroare inițială și recuperare. Fără init Firebase/date live; nu se testează aici accesul operațional HomePage, login/reauth ori signout real. Local **155 Python + 3 Node PASS**, syntax, body-equivalence, diff și inventar PASS. CI pe SHA-ul lotului urmează.

Snapshot **165 Dart (125 lib, 39 teste, 1 script), 60 parts, 105 biblioteci**, zero lipsuri/orfani/duplicate/cicluri. Următoarea etapă sigură de analizat: sursele/login/abonările Home, păstrând grupurile deja extrase, ordinea, UID/cancel și fără mărirea citirilor. Auditul diferențial complet se face după modularizare și reutilizează regulile aprobate; Vision rămâne în PR-urile dedicate existente. Fără merge/deploy/APK/rules/config/date live/billing/migrări; #19/#20/#21/#29 nealterate.


## CHECKPOINT-AUTH-SERVICES-VALIDATED-20261014 — continuare PR #28 / Issue #30

Reluare din `3be7a09b6a28122bfae23e8ff779e7765a24cd39` (CI deja finalizat 5/5, nu a fost așteptat din nou). HEAD de cod nou: **`0414b6cdc7211bd5a95ff58664d97458b0111604`**. Toate loturile au fost comise și validate separat înainte de următorul:

| Lot | SHA | Run CI | Rezultat |
|---|---|---|---|
| FirebaseUserProfile independent | d4d90a7796bb6899f8d9fac36e44db480d2ba82c | 38482963824 | 5/5 SUCCESS |
| QuickAccountStore / I-O injectat | 0be4bce7d5054dc641b92f48dc7e6c94247438ac | 38483520307 | 5/5 SUCCESS |
| Politică inițializare Firebase | 75279637b52cf588a26a6ec2d0a6d1a0b044e898 | 38484010280 | 5/5 SUCCESS |
| Surse read-only AuthGate | 0414b6cdc7211bd5a95ff58664d97458b0111604 | 38484621957 | 5/5 SUCCESS |

Au trecut unit/widget Flutter, bibliotecile fără motor Flutter, build web, Python/security, Node, Functions și emulatorul Firestore în fiecare run. Local: **155 Python, 3 Node**, syntax Functions, diff-check și verificări de echivalență PASS. SDK Flutter/Dart indisponibil local; testele Dart/widget și compilarea au fost executate în CI, fără teste pe telefon ori Firebase live.

Inventar final: **165 fișiere Dart (125 lib, 39 teste, 1 script), 60 parts, 105 biblioteci totale**. Snapshotul este generat cu `scripts/audit_dart_dependencies.py` și comparat byte-identic cu o regenerare finală; fără missing targets, parts orfane, duplicate sau cicluri. Bibliotecile totale includ testele/scriptul, nu doar lib. Reducerea 63→60 nu este singurul progres: porturile pentru auth/storage/startup explicite permit testarea fără SDK live, păstrând state machine-ul.

Checkoutul local este curat și sincronizat cu HEAD-ul remote înaintea checkpointului documentației. Git read funcționează, dar push CLI nu are credentiale; commiturile au fost trimise prin connector cu lease pe HEAD-ul așteptat, apoi s-a verificat identitatea arborilor local/remote. Nicio modificare a altei ramuri. Verificare față de baza 3be7: zero diff în `lib/finance`, PDF/reports/documents/download, OCR, map/Mapbox, assets, Functions, workflow-uri, manifest/dependențe și rules/config Firebase/teste Firestore.

**Pasul exact de reluare:** verifică HEAD/CI și această secțiune, apoi citește `docs/MODULARIZARE_AUTH_SERVICII_2026-10-14.md`. Auditează dependențele LoginPage (auth/secure storage), apoi furnizorii abonărilor Home din grupurile deja separate, păstrând ordinea, URI/UID/metadata, cancel și numărul citirilor/scrierilor. Construiește mai întâi fixture-urile de stream și adapterele; nu muta întreaga stare Home/Program/Map/Decont sau brandingul global fără teste specifice. AuthGateSources nu adaugă bus/observabilitate Vision.

**Misiunea nu este finalizată:** 60 parts rămân cuplate; scopul nu este zero parts cu orice preț. Auditul diferențial complet vine după modularizare și clasifică: aprobat+implementat / aprobat+neimplementat / parțial / clarificare tehnică / decizie nouă. Regulile aprobate din registru/Issue #30 nu se votează din nou. Prima etapă nouă rămâne Vision Error Log/observabilitate, reutilizând codul existent în #19/#21 pe PR dedicat. Contractele PDF download/share/anulare din #20 rămân separate. Riscurile START concurent, token ownership, badge_v2, restore/OCR/permisiuni nu sunt reparate implicit prin aceste refactorizări.

PR #28 rămâne Draft/Open; fără merge/main/deploy/APK/date live/rules/config/billing/migrări/schimbare versiune. PR #19/#20/#21/#29 sunt protejate. Acest checkpoint de cod validat este completat de un commit exclusiv de documentație, al cărui CI se verifică înaintea raportului final.


## MOD-LOGIN-ALIAS-20261014 — continuare din checkpoint 0b6e315

LoginAliasResolver extrage body-ul rezolvării aliasului cu HTTP injectat; LoginPage păstrează wrapperul, constructorul și fluxul. Teste pentru request/bypass/erori/timeout/completion întârziat fără retry. Audit Login/identitate și inventar Home/lifecycle/cache/scope în docs/MODULARIZARE_LOGIN_HOME_2026-10-14.md. Nu se corectează implicit cursele scope financiar, callbackurile post-dispose ori token ownership. Local verificarea textuală PASS; CI pe commit urmează, obligatoriu 5/5 înainte de următorul lot. Fără merge/deploy/Firebase live/modificări ramuri protejate.


## MOD-LOGIN-ACTIONS-20261014 — lot 6

Lot 5 validat: f347625f2eb1ebd5592557b2dd9ca6374d27d80d / CI 38486333669, 5/5 SUCCESS; inventar 167/60/107. LoginActions expune resolve/create/signIn/reset/writeProfile; constructorul LoginPage primește opțional actions, adapterul implicit din main este lazy. Corpurile submit/reset/build sunt textual identice după înlocuirea apelurilor SDK. Nicio tranzacție/retry/rollback nou, nicio schimbare a schemei pending. Teste widget sintetice pentru validare/login/eroare credential/recuperare/înregistrare pending/eroare profile/dispose întârziat. Nu sunt teste de token expirat real sau Firebase live. CI pe SHA de lot urmează; pas următor helpers autentificare, apoi porturi Home când fixture-urile sunt suficiente. Restricțiile PR #28 rămân integrale.


## MOD-HOME-DEFINITION-SOURCES-20261014 — lot 7

Lot 6 LoginActions: a04a0ba4c044da9a7781589144ae971fa6cbef5c / CI 38486724314 **5/5 SUCCESS**, inventar 169/60/109. HomeDefinitionSources este port read-only pentru cele trei query-uri globale locationCategories/backgrounds/functions. Factory-ul SDK este lazy, fără transformare/share/replay/retry/listen propriu. HomePage păstrează API-ul existent și acceptă opțional source; aceeași orchestrare creează cele trei subscriptions în ordinea originală. Callbackurile, caches, seed/sync permissions, financial refresh, mounted și dispose sunt textual păstrate după substituția celor trei expresii sursă. Nu există citiri/scrieri/listen suplimentare în adapter.

Teste directe cu Firestore fake și streamuri sintetice pentru laziness/query/default metadata, ordinea event/error/reconnect, o singură abonare și cancel/late events, independența a două surse. Aceste teste verifică portul și subscription ownership al consumatorului de test, NU întregul HomePage cu GPS/FCM/finanțe ori schimbarea UID în producție. AuthGate are deja teste UID/cancel; pentru Home complet rămân fixture-uri de efecte laterale înainte de mutarea stării. CI pe lot urmează.

Completare audit I/O Home: persistCoreData compară location/team/car/userTeam caches înainte de batch set și le actualizează numai după commit. Auditul scrie audit + Learning async; notificările locale scriu notifications. Seed citește limit1 apoi batch; migration badge_v2 citește users/functions/settings și scrie/șterge batch-uri, nemodificată/neexecutată. Maintenance citește backupAutomation, notificări/backups vechi și items, apoi delete/batches; backup citește cele 15 colecții și UI settings, scrie backups/items. Push citește profil pentru navigare și scrie pushTokens; GPS scrie/șterge liveLocations. Operational/financial actions folosesc set/delete și tranzacția existentă de diurnă/audit. Aceste efecte nu sunt aduse în portul read-only.

Risc suplimentar existent: init GPS/FCM async poate continua după dispose; nu se introduce implicit o politică de anulare nouă. Definițiile sunt globale, nu de UID; înlocuirea stării Home este responsabilitatea ValueKey(uid). Scope financiar/generation guards, DND și token ownership rămân blocaje funcționale documentate. Pasul următor sigur: helpers login independente; ulterior fixture-uri Home complete și porturi pentru restul grupurilor. Fără Vision nou, merge/deploy/production/rules/billing ori atingerea PR #19/#20/#21/#29.
