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
