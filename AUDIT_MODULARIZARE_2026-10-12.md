# Audit modularizare AndiCarpet — 2026-10-12

## Bază și limite

Bază: `54bd851b5d4876ef293c1dda95e1be354a92e154`, ramura `main`.
Citite integral înainte de modificări: `ChatGpt`,
`REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` și auditul din 11 octombrie.
CI de bază: run `38219376683`, completed/success.
Ramură de lucru: `refactor/home-codecs-sync-20261012`.

Lotul păstrează comportamentul existent. Nu modifică reguli/date Firebase,
configurație de producție, versiune, dependențe, semnare sau workflow-uri.
Nu pornește aplicația conectată la Firebase și nu execută deploy ori migrări.

## Modificări și dependențe

| Bloc | Destinație | Contract |
|---|---|---|
| 28 metode Map/FromDoc și utilitare | `lib/home/home_document_codecs.dart` | Mixin privat; singura dependență de stare este getterul `AppSettings settings`, folosit pentru fallback-ul diurnei |
| Catalog inițial, 103 locații | `lib/home/home_location_seed.dart` | Mixin fără stare; fiecare apel construiește obiecte noi; niciun acces Firestore |
| Profil propriu | `_startOwnProfileSync` | Abonare numai non-admin, aceleași preferințe și callback-uri |
| Echipe, mașini, locații, grafice, execuții | `_startOperationsSync` | Aceeași ordine, sortare, cache-uri și refresh financiar |
| Notificări | `_startNotificationSync` | Același filtru userId, priming și deduplicare |
| Chat privat și grup | `_startChatSync` | Păstrează helperii locali, sender ascuns/admin, limita 20 și unread |
| Setări globale | `_startSettingsSync` | Aceleași clamp-uri, learning și mentenanță admin |

Mixinurile sunt aplicate după `_HomePermissionMaintenance`, furnizând implementările
cerute de contractele abstracte existente. Metodele păstrează identificatorii privați,
semnăturile și corpul original; biblioteca Dart comună și callerii rămân aceiași.
Cele cinci metode de abonare rămân în HomePage în acest lot pentru a nu introduce
un contract de stare excesiv înainte de testarea separării lor.

HomePage: **136.564 -> 95.603 bytes**, reducere de 40.961 bytes (~30%).
Biblioteca principală are acum **71 parts**, de la 69. Este încă o arhitectură
intermediară; modularizarea completă și API-urile independente NU sunt finalizate.

## Dovezi de echivalență

Verificarea locală a reconstruit fișierul original prin reinserarea blocurilor
extrase și înlocuirea apelurilor noi cu abonările originale. Rezultatul este
identic byte cu byte cu sursa de bază; nu s-au editat instrucțiunile mutate.
Păstrate 15 abonări Firestore core (profilul propriu condiționat; auditul admin
condiționat), separat de cele două abonări FCM și cele patru abonări financiare.
`dispose` păstrează anularea tuturor abonărilor și GPS/timerelor.
Aceasta este dovadă de mutare textuală, nu test real pe dispozitiv.

## Audit duplicate și cod posibil nefolosit

- Inventarul urmărit de Git după extragere: 375 fișiere, 12 grupuri cu conținut
  identic. Toate sunt aceleași variante de platformă/assets explicate în auditul
  anterior. Nu sunt șterse. Raportul JSON se generează în CI ca artifact.
- 88 referințe relative Dart import/export/part în lib și test: nicio țintă lipsă.
  Sunt verificate și importurile condiționale OCR/download pentru web/mobile/stub.
- `_categoryCache`, `_functionCache`, `_expenseCache`, `_perDiemCache`, `_financeCache`,
  `_scheduleCache`, `_recordCache` sunt scrise, fără cititori găsiți în lib. Candidate
  la eliminare, nu dovadă suficientă pentru a elimina evaluarea `_encoded(...)`:
  aceasta poate produce erori la date invalide. Necesită decizie/test pentru
  compatibilitatea tratării erorilor. Cache-urile locații/echipe/mașini/userTeam
  sunt citite de `_persistCoreData` și trebuie păstrate.
- `_financeFromDoc` și `_settlementFromDoc` repetă parsarea `receivedEntries`.
  Consolidarea este amânată: fallback-urile `idNow` și `DateTime.now` sunt evaluate
  pe fiecare element și nu trebuie să se modifice identitatea sau ordinea lor.
- `lib/finance/per_diem_ledger_test.dart` este un fișier de teste în lib; nu este
  inclus de `flutter test test/`. Nu este duplicat byte-identic cu testul din test.
  Mutarea acoperirii lui și eventuala ștergere necesită verificare separată.
- Fluxurile legacy și v2, toate cele 32 de stickere și resursele de platformă sunt
  păstrate; lipsa unui import direct din main nu justifică eliminarea finanțelor v2.

## Riscuri existente și prioritate

1. Migrarea `badge_v2` resetează funcții ale membrilor non-admin și șterge definiții.
   Prioritate pentru următoarea analiză funcțională; nemodificată și neexecutată aici.
2. Restaurarea backupului nu este atomică global la erori de rețea/permisiuni sau
   între batch-uri. Snapshot-ul nu poate reprezenta explicit o colecție goală.
3. Permisiunile UI, emitterele și subscriptions rămân interdependente în aceeași
   bibliotecă. `part` nu impune separarea API-urilor și nu dovedește securitatea.
4. Testele Python sunt contracte structurale. CI Dart/web și emulator sunt necesare,
   iar testul real de distribuire Daniel -> proprietar rămâne amânat conform deciziei.

## Teste

- Înainte: **103 teste Python PASS**, **3 teste Node PASS**, syntax Functions PASS.
- După: **107 teste Python PASS**, **3 teste Node PASS**, syntax Functions PASS.
- Patru teste noi: unicitatea conversiilor și fallback financiar, catalog complet și
  unic, ordinea abonărilor/lifecycle, filtre/limite/error handling pe grupuri.
- Reconstrucție exactă sursă: PASS. `git diff --check`: PASS.
- Flutter/Dart nu este instalat local. `npm ci` Functions, testele Dart/widget,
  build web și emulatorul pe `demo-andi-carpet` sunt verificate de workflow-ul PR;
  rezultatul final se raportează explicit după rulare. Nu sunt teste pe producție.

## Pași rămași

1. Confirmarea CI pe SHA final al PR; remediere înainte de merge dacă apar erori.
2. Separarea abonărilor în module cu contracte explicite după acest checkpoint.
3. Separarea operațiilor CRUD/financiare, GPS/geofencing și navigării HomePage.
4. Fragmentarea ExpensePage (~77 KB), ProgramPage (~67 KB), MapPage (~56 KB),
   DashboardPage (~40 KB), PDF și modele; fiecare lot cu analiză și CI.
5. Înlocuirea treptată a parts cu biblioteci independente; eliminarea exclusiv a
   codului dovedit mort, cu testarea efectelor secundare și a tuturor platformelor.
6. După curățare: aprobarea regulilor pe categorii și abia apoi infrastructura
   diagnostics/cache/AI. Niciuna dintre aceste funcții noi nu este implementată aici.


## Rezolvare conflicte PR #17 — 2026-10-13

- Intrări verificate: PR #17 `29f394478ea5fd86822efd3a138766067c3f9694`, main `992875ecb41003bc55e4509daf2a949b9e384f0d`, PR #18 `d42426852fc92226cfaf003a0ed7a1ca713e14bb`.
- Merge local main → ramura PR #17: exact două conflicte content/append în `ChatGpt` și `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`. Fără conflict în cod. Secțiunea 100 a notei PR #17 se suprapunea cu deciziile de fațade din main; secțiunea 9 a registrului PR #17 cu regulile Conturi.
- Rezolvare: conținutul complet din PR #18 păstrat byte cu byte ca prefix, inclusiv toate deciziile main; evidența originală PR #17 păstrată separat ca secțiunea 155 / 74, cu referința corectată. Arhitectura Vision este identică integral cu PR #18. Documentele de audit/proiectare existente în main sunt păstrate. Nu s-a folosit alegere globală ours/theirs.
- Verificare de integritate: toate fișierele non-documentație sunt identice byte cu byte cu HEAD-ul anterior PR #17, inclusiv codul modularizat, testele, assets, workflows, Functions, rules și configurația. Nu se introduce o schimbare de comportament. Numerotările de secțiuni sunt unice.
- Teste locale: 107/107 Python PASS; 3/3 Node projection PASS; `node --check functions/index.js` PASS; audit repository PASS cu 12 grupuri identice deja cunoscute (asseturi/configurări distincte de platformă, nu șterse). Flutter nu este instalat local; Flutter unit/widget, build web, npm ci Functions și emulatorul Firestore demo se execută în CI.
- `git diff --check` semnalează spații finale moștenite din documentele aprobate; acestea sunt păstrate pentru integritatea textului, inclusiv hard breaks Markdown. Verificarea modificărilor proprii nu introduce spații finale. Nu confundăm aceste avertismente cu defecte de cod.
- La înregistrarea acestei note, CI pentru noul commit nu este încă executat. Verdictul final, SHA exact și linkul rulării sunt consemnate în descrierea PR #17 după încheierea celor cinci joburi; verdele istoric 38220879828 nu validează singur noul commit.
- Fără merge în main, deploy, APK, modificări Firebase live, chei/API ori billing. Vision/Error Log rămâne specificație, nu implementare. Modularizarea integrală și riscurile din acest audit și arhitectura Vision rămân pentru etapele următoare.

## Actualizare diferențială — checkpoint PR #136 (20 octombrie 2026)

### Bază și metodă

- Auditul istoric pornea de la `main` `54bd851b5d4876ef293c1dda95e1be354a92e154`; documentul de reguli curent din `main` are blob SHA `ddbdc55128c285337b006958f86ef323ff6be7c5`.
- Inventarul de mai jos a fost refăcut din arborele exact al PR #136, `0c9cbc6e1090c295db2c867826ca58447e738df9`, nu copiat din valorile din 12 octombrie. `main` rămâne separat la `8452159475ff187867002425fa9c3b8c7e8006aa`; PR #134, #135 și #136 sunt Draft/Open și nemergate.
- Inspecția a numărat fișierele Dart, părțile `part of '../main.dart'`, importurile locale explicite și testele după nume/cale. `scripts/audit_repository.py` a găsit 12 grupuri de conținut identic în assets/configurări de platformă; nu sunt eliminate, fiindcă semnificația lor depinde de platformă. Nu a raportat grupuri de cod Dart identic.
- „Fără test dedicat identificat” înseamnă lipsa unui test focalizat pe acel modul; nu afirmă că funcționalitatea nu este exercitată deloc în build-urile sau testele end-to-end.

### Matricea modulelor aplicației la SHA #136

| Modul | Structură și cuplare observată | Dependențe locale / duplicări / cod nefolosit | Teste existente la checkpoint |
|---|---|---|---|
| Intrare și adaptori (`lib/` root) | 11 fișiere autonome; `main.dart` include majoritatea ecranelor prin `part`; OCR și download au adaptoare condiționale web/mobile/stub | Dependențe externe Flutter/Firebase/pluginuri; niciun duplicat exact Dart identificat | `ocr_parser_test.dart`, `widget_test.dart`, teste build/web și native CI |
| Admin | 15/15 fișiere `part` ale bibliotecii principale; 132,693 B | Accesul la modele, Firebase și UI vine implicit din `main.dart`; este cuplat transversal | `admin_apk_url_source_contract_test.py`, `admin_privacy_contract_test.py`, `admin_security_integration_contract_test.py`, teste Python de repository/CI |
| Auth | 5/5 `part`; ecrane și gateway folosesc aceeași bibliotecă | Cuplare implicită cu starea globală/auth Firebase | `admin_security_integration_contract_test.py`, `widget_test.dart`; fără test dedicat separat pentru fiecare ecran |
| Bootstrap | 2/2 `part` | Inițializarea Firebase și aplicația de eroare folosesc importurile globale | Verificare de pornire în CI; fără test de unitate dedicat identificat |
| Centralizer | 1 pagină `part`; 3 utilitare independente | Writer depinde de snapshot checker și Cloud Firestore; snapshot-ul compară câmpuri existente | `centralizer_*_test.dart`, `manual_execution_defaults_test.dart`, teste native și PDF |
| Chat | 2/2 `part` | UI, identitate și Firestore împart biblioteca principală; duplicate exacte neidentificate | Fără test focalizat Dart pentru ecranele chat identificate |
| Contacts | 1/1 `part` | Cuplare implicită la modele și helperi globali | Fără test focalizat identificat |
| Dashboard | 1/1 `part`, 41,144 B | Mută START/STOP și stări de program prin callback-uri globale; împărțea un formatter de eroare de salvare cu ProgramPage (consolidat în lotul următor) | `program_graph_creation_test.dart`, contracte Craiova/learning, flux nativ CI |
| Documents | 1/1 `part` | UI legat de permisiuni și starea Home | Fără test focalizat identificat |
| Expenses | 1/1 `part`, 77,425 B | Cel mai mare ecran după Home; combină cheltuieli, OCR, diurne legacy/v2, settlement și PDF; fluxurile legacy/v2 rămân distincte; nu se unifică | 6 teste Flutter `per_diem_*` în `test/`; `lib/finance/per_diem_ledger_test.dart` este adiacent și nu intră în `flutter test test/` |
| Feedback | 1/1 `part` | Cuplare implicită prin `main.dart` | Fără test focalizat identificat |
| Finance | 14 fișiere independente | Dependențe interne explicite între ledger, adaptoare legacy, settlements, reconciliation/payment plan; repository-urile depind de Firebase; nu se amestecă `perDiems` cu settlements v2 | 6 teste Flutter `per_diem_*` sub `test/`; un test adiacent în `lib/` nu este inclus automat |
| Home și sincronizări | 5/5 `part`; HomePage 101,935 B | Transversal: auth, subscriptions, cache, serializare, operații și permisiuni; 7 cache-uri (`_categoryCache`, `_functionCache`, `_expenseCache`, `_perDiemCache`, `_financeCache`, `_scheduleCache`, `_recordCache`) sunt numai scrise, fără cititori găsiți în `lib/` | Contracte Python/security/repository; coverage de integrare și testele CI native; fără unități Flutter pe fiecare subscription |
| Learning | 1/1 `part` | Consumă modele și `AppSettings` globale | `grafic_learning_notifications_contract_test.py`; testele de program verifică indirect proiecțiile |
| Map | 4/4 `part`; `map_page.dart` 55,655 B | GPS, pluginuri hartă, servicii HTTP/Mapbox și stare globală; geocodarea și UI sunt încă împreună | Teste de integrare/web și contracte conexe; fără test focalizat pentru `MapPage` identificat |
| Members | 2/2 `part` | Directorul folosește identitatea globală, permisiuni și Firestore | `member_directory_minimization_test.py`, `member_directory_projection.test.js`, `manual_member_directory_deploy_gate_test.py` |
| Models | 5 `part` + 2 independente | Două fișiere independente importă Flutter Material; restul tipurilor de bază sunt părți ale `main.dart`, deci modelele încă nu sunt un API autonom | `app_enums_permissions_test.dart`, `location_function_models_test.dart` |
| Notifications | 2/2 `part` | Push diagnostics și SMS împart accesul global la auth/settings | `grafic_learning_notifications_contract_test.py`; fluxuri/native CI, fără test Dart focalizat pentru fiecare ecran |
| Operations | 2/2 independente | `atomic_restore` și `record_writer` depind separat de Cloud Firestore; nu depind de UI | `atomic_restore_preflight_test.dart`, `record_writer_test.dart`, `record_writer_recovery_authority_test.dart` și contract |
| Profile | 1/1 `part` | Date, setări și permisiuni partajate implicit | Fără test focalizat identificat |
| Reports/PDF | 2 `part` + 1 independent | Normalizarea numelui fișierului e independentă; randarea PDF rămâne legată de modele globale | `pdf_filename_normalization_test.dart`, `centralizer_pdf_*_test.dart`, `xix_pdf_text_test.py` |
| Schedule | 2/2 `part`; `program_page.dart` 71,716 B | ProgramPage depinde implicit de modele/UI globale; `preferredProgramTeamIndex` este deja acoperit; mesajele de eroare sunt duplicate ca utilizare între Dashboard și ProgramPage și sunt extrase în acest lot | `program_graph_creation_test.dart`, `program_team_selection_test.dart`, contracte program/firestore și `schedule_save_failure_test.dart` nou |
| Settings | 1/1 `part` | Configurare, admin și persistare în bibliotecă comună | Fără test focalizat identificat |
| Teams | 1/1 `part` | Selector UI folosește modele globale | `program_team_selection_test.dart` acoperă doar selecția echipei din ProgramPage |
| Testing harness | 1 fișier autonom | Importă intenționat `main.dart` pentru test UI sintetic offline | Rulat în workflow-ul de validare; fără backend de producție |
| UI shared | 13 `part` + 5 independente; 18 fișiere | Catalogurile independente sunt pure sau depind de Flutter; helpers de temă/UI rămân `part`-uri | `badge_metadata_test.dart`, `branding_asset_catalog_test.dart`, `font_choice_normalization_test.dart`, `section_accent_palette_test.dart`, `section_asset_catalog_test.dart`, `android_install_link_test.dart` |
| Utils | 1 `part` + 1 independent | Formatările pure sunt independente; datele operaționale rămân `part` | `date_formatters_test.dart`; acoperirea datelor operaționale apare și în testele Centralizer |

### Comparație cu auditul din 12 octombrie

- Confirmat încă valabil: paginile `ExpensePage`, `ProgramPage`, `MapPage` și `DashboardPage` sunt fișiere mari `part` în `main.dart`; modulele lor nu au granițe independente de tip/import. HomePage are aceeași problemă la scară mai mare.
- Confirmat, dar cu valori actualizate: HomePage este 101,935 B (nu 95,603 B la snapshot-ul auditului); ExpensePage 77,425 B; ProgramPage 71,716 B (nu estimarea veche 67 KB); MapPage 55,655 B; DashboardPage 41,144 B. Valorile se referă numai la blob-urile exactului PR #136.
- Confirmat: cele 7 cache-uri de mai sus au definiții și scrieri, dar niciun cititor găsit prin căutare globală în `lib/`. Nu sunt eliminate în această etapă: expresiile `_encoded(...)` sunt evaluate în aceleași operații și pot ridica erori pentru date invalide; eliminarea ar schimba posibile efecte de eroare și necesită investigație separată.
- Confirmat: există două parsări apropiate de `receivedEntries` în `_financeFromDoc` și `_settlementFromDoc`; fallback-urile `idNow`/`DateTime.now` pot afecta identitatea/ordinea, deci consolidarea nu este demonstrată sigură.
- Confirmat: `lib/finance/per_diem_ledger_test.dart` nu este sub `test/`; păstrat, fără duplicare sau ștergere.
- Actualizat: auditul de repository găsește 12 grupuri identice, toate în manifests/assets/configurări de platformă cunoscute. Acest fapt nu dovedește duplicare de logică în Dart și nu justifică ștergerea lor.
- Nu au fost eliminate fluxuri legacy/v2, colecții, assets ori cache-uri. Nu s-au modificat reguli oficiale, Firebase, comportament, versiuni, dependențe sau workflow-uri prin lotul de cod.

### Lot următor realizat din checkpointul #136

- Extragerea helperului de mesaje pentru erorile salvării programului din `program_page.dart` în `lib/schedule/schedule_save_failure.dart`, bibliotecă separată ce depinde numai de `firebase_core`.
- DashboardPage și ProgramPage folosesc acum același helper; au fost păstrate literal textele și ramurile de eroare existente. Se adaugă `test/schedule_save_failure_test.dart` pentru `permission-denied`, `unauthenticated`, `unavailable`, `deadline-exceeded`, `failed-precondition`, cod necunoscut, `StateError` și fallback generic.
- Mutarea reduce utilizările dublate și scoate această logică din `part`-ul UI. Nu pretinde că decuplează întregul ProgramPage/DashboardPage.
- Testele Python locale la baza #136: 173/173 PASS. Repository audit: 457 fișiere urmărite, 12 grupuri de asset/config identice. Flutter/Dart nu sunt instalate în mediul local; testul nou, analyze și build-ul sunt obligatoriu de verificat în workflows CI pe SHA-ul lotului.

### Obligații rămase

1. Păstrează PR #134/#135/#136 ca Draft/Open, fără merge; examinează lotul nou ca PR Draft bazat pe capul #136.
2. Confirmă CI Validate, Android debug și Native emulator pe SHA-ul exact al noului lot înainte de a declara validarea completă.
3. Continuă cu separarea paginilor mari și a modelelor din `part` în biblioteci importabile, numai după inventarierea API-urilor și a importurilor.
4. Investighează separat cache-urile write-only și parsările `receivedEntries`; fără eliminare până când efectele la erori și ordinea/identitatea sunt testate.
5. Păstrează fluxurile financiare legacy/v2, cele 32 de stickere și adaptoarele specifice platformei.
6. Nu declara modularizarea integrală încheiată până când cuplarea implicită la `main.dart`, codul nefolosit și testele pentru toate familiile nu au fost închise verificabil. `production_ready=false`.

## Lot independent — parser de sumă Expense (20 octombrie 2026)

- Următorul lot separat pornește din PR #137, HEAD-ul său curent fiind baza tehnică. Nu atinge SchedulePage/DashboardPage și nu repetă delta din #134–#137.
- `ExpensePage._expenseAmountBani` este mutat în `lib/expenses/expense_amount_parser.dart`, bibliotecă Dart autonomă. Modulul reutilizează `parseLeiToBani` din `lib/finance/per_diem_money.dart`, păstrând limita formularului `1–9` cifre întregi, separator virgulă/punct, cel mult două zecimale și sumă strict pozitivă.
- Formularul continuă să valideze aceeași expresie de eroare și să trimită aceeași valoare integer-bani către `Expense`. Nu se schimbă modelul, settlement-ul, OCR-ul sau stocarea. `test/expense_amount_parser_test.dart` acoperă bani întregi/fracționari, limita maximă, zero, semne, formate invalide, exponent și precizie prea mare.
- Contractul de igienă a repository-ului a fost mutat de la verificarea sursei UI la modulul responsabil de parsing și confirmă folosirea conversiei integer-bani comune.
- Verificări locale pe codul lotului: Python/security 173/173 PASS; Node member projection 3/3 PASS; `git diff --check` PASS. Flutter/Dart nu sunt instalate local; testele Dart, analyze și build-ul rămân de confirmat în CI pe SHA-ul exact al PR-ului.
- Aceasta este o a doua extracție țintită, nu închiderea modulului Expenses. `expense_page.dart` rămâne un `part` mare; OCR, dialogurile, filtrele de settlement și scrierile au cuplare la modele/starea principală și sunt obligații separate.

### CI pentru PR-uri copil stacked

- Endpointul de workflow a confirmat că #137 nu primea run-uri când baza branch-ului copil nu era în allowlist. PR #136 a primit un commit numai de rutare/contract CI (`611373f5f40fab34754a9629d5249d55c457c825`); acesta nu schimbă codul aplicației sau testele de produs. Validate, Android și Native au pornit pe acest HEAD; Validate a trecut, celelalte două sunt încă în curs la momentul acestei note.
- PR #137 include o extindere suplimentară numai pentru CI (`b49512b382e1731fd0158149b5b527a163780185`) astfel încât următorul PR stacked să primească aceleași trei workflow-uri. `test/stacked_pull_request_ci_contract_test.py` verifică toate filtrele și condiția native.
- #137 rămâne diferența modulară: tabelul și lotul schedule; branch routing-ul necesar pentru copil este parte a istoricului #136/#137 ca să existe validări CI reale. Niciun merge nu este permis sau făcut.
