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

### Obligații rămase la checkpointul #136 (înregistrare istorică)

1. La acel checkpoint: păstrează PR #134/#135/#136 ca Draft/Open, fără merge; propune următorul lot ca PR Draft bazat pe capul #136. Starea curentizată #137–#145 și obligațiile încă deschise sunt notate în addendumul diferențial de la final.
2. Confirmă CI Validate, Android debug și Native emulator pe SHA-ul exact al noului lot înainte de a declara validarea completă.
3. Continuă cu separarea paginilor mari și a modelelor din `part` în biblioteci importabile, numai după inventarierea API-urilor și a importurilor.
4. Investighează separat cache-urile write-only și parsările `receivedEntries`; fără eliminare până când efectele la erori și ordinea/identitatea sunt testate.
5. Păstrează fluxurile financiare legacy/v2, cele 32 de stickere și adaptoarele specifice platformei.
6. Nu declara modularizarea integrală încheiată până când cuplarea implicită la `main.dart`, codul nefolosit și testele pentru toate familiile nu au fost închise verificabil. `production_ready=false`.

## Actualizare diferențială — candidații Map #141–#145 (19 octombrie 2026)

Baza comparației este checkpointul de modularizare #136 și ramura părinte #137 `b49512b382e1731fd0158149b5b527a163780185`. Aceste schimbări sunt pe ramuri Draft separate; ele nu modifică `main`. Matricea de la checkpoint rămâne fotografia verificată la acel SHA, iar tabelul de mai jos consemnează delta, nu rescrie retrospectiv starea main.

| Lot | Modul / contract mutat | Dependențe noi și duplicări | Regresii | SHA candidat și CI exact |
|---|---|---|---|---|
| #141 | `lib/map/map_route_selection.dart`: deduplicarea ID-urilor de graf activ, alegerea grafului solicitat cu fallback la primul activ și selectarea zilelor sortate cronologic. API-ul generic folosește accessors, fără dependență de `WorkSchedule`, widget sau `main.dart`. | Nicio dependență de pachet nou; nicio logică duplicată introdusă. Lista-ID păstrează filtrarea de echipă și ordinea primei apariții; zilele păstrează filtrul istoric doar pe graphId/started/closed, inclusiv rezultatul existent când un graphId apare la mai multe echipe. | `test/map_route_selection_test.dart`: ordinea/deduplicarea, closed/not-started, fallback, echipă null, sortare și stare goală. | `39f3506df19d9a53cd2060f646f57a0df567f7e6`; Validate `39341558517` și Android `39341558484` SUCCESS; Native `39341558511` attempt 3 în curs pe același SHA. Attempt 1 a eșuat la instalarea NDK (`ZipFile unknown archive`); attempt 2 a ajuns până după generarea PDF, apoi Auth Emulator a întrerupt stream-ul la autentificarea celui de-al doilea client (`unexpected end of stream`), fără eșec de aserțiune Map. |
| #142 | `lib/map/reverse_geocode_address.dart`: parser pur pentru răspunsul Nominatim, separat de transportul HTTP. | Fără dependențe noi; nu atinge URL/parametri, headers, User-Agent, timeout, tratarea codului HTTP ori fallback-ul de excepții. Nu unifică reverse geocoding cu căutarea înainte din Dashboard. Contractul CI permite explicit ramura copilă, fără schimbare de pași/politici. | `test/reverse_geocode_address_test.dart`: aliasuri/prioritate drum, număr, localitate/județ, deduplicare, fallback display_name și lipsa rezultatului. | `43690da9808830c3ac2f71d06ca778a09fd910eb`; Validate `39341819031`, Android `39341819032`, Native `39341819051` — toate SUCCESS pe SHA exact. |
| #143 | `lib/map/map_reverse_geocoder.dart`: transportul HTTP Nominatim injectabil, consumând parserul din #142. | Fără dependență nouă; păstrează endpointul, parametrii, precizia coordonatelor, antetele, User-Agent nativ, timeoutul, validarea răspunsului și fail-to-null. | `test/map_reverse_geocoder_test.dart`: request/antete web+nativ, rezultate invalide și excepții; toate testele folosesc transport fals, fără rețea. | `97b9f9198a8e739957fe1b4ab9d1b9ffa20e11b3`; Validate `39341822453`, Android `39341822515`, Native `39341822442` — toate SUCCESS; flux conectat și verificările PDF/checksum/artifact au trecut. |
| #144 | `lib/map/map_work_badge_state.dart`: logică generică de stare completed/next-or-running/not-completed, fără modele sau widgeturi; MapPage păstrează maparea la culori existente. | Nicio dependență/pachet nou și nicio logică duplicată. | `test/map_work_badge_state_test.dart`: fără asignări, toate vizitele terminate, restante între echipe, running/waiting, ordinea programului și sărirea intrărilor refuzate/necompletate. | `fd551da6163e014aad901c40e9b7975e1a29f0e9`; Validate `39342521773` SUCCESS; Android `39342521800` SUCCESS; Native `39342521775` încă în curs la 23:46 UTC. |
| #145 | `lib/map/map_operational_schedules.dart`: filtrarea generică a programelor pornite din ziua operațională, pentru admin/echipă. Caller-ul păstrează calculul datei. | Fără pachet nou; include intenționat grafice închise, ca să nu dispară markerul verde după închidere. | `test/map_operational_schedules_test.dart`: zi/pornire, scope admin, teamId absent și includerea programului închis. | `817489db98f1a47140ba5c07fd7bc175d1081e79`; Validate `39342732825` și Android `39342732850` SUCCESS; Native `39342732906` încă în curs la 23:46 UTC. |

### Comparație cu constatarea istorică despre MapPage

Auditul din 12 octombrie descria MapPage ca `part` cu GPS, pluginuri, HTTP/Mapbox și stare globală, fără teste focalizate identificate. Constatarea structurală rămâne corectă pentru pagina întreagă; nu implică faptul că fiecare helper era netestat după #136. Loturile #139–#145 au scos politici/helpers importabile pentru cheia/expirarea geometriei, validarea punctelor, selecția rutelor, parsing/transport reverse geocoding, starea badge-ului și filtrul de programe operaționale. GPS, UI, modele și orchestration MapPage rămân cuplate; aceste loturi sunt îmbunătățiri incrementale, nu închiderea modularizării Map. Constatările istorice despre duplicate nu justifică ștergerea celor 12 grupuri de asset/config sau a codului cu efecte/ordini necaracterizate.

Nu s-au șters cod/asseturi pe baza inventarului de identități, nu s-au schimbat date Firebase și nu s-au atins fluxurile existente. `production_ready=false`.


## Corecție finală CI și lotul Map #146 (20 octombrie 2026 UTC)

Acest addendum închide statusurile intermediare din tabelul de mai sus pe baza run-urilor terminale pentru SHA-urile exacte:

| PR / SHA de cod | Validate | Android debug | Native emulator |
|---|---|---|---|
| #141 39f3506df19d9a53cd2060f646f57a0df567f7e6 | 39341558517 SUCCESS | 39341558484 SUCCESS | 39341558511 attempt 3 SUCCESS |
| #142 43690da9808830c3ac2f71d06ca778a09fd910eb | 39341819031 SUCCESS | 39341819032 SUCCESS | 39341819051 SUCCESS |
| #143 97b9f9198a8e739957fe1b4ab9d1b9ffa20e11b3 | 39341822453 SUCCESS | 39341822515 SUCCESS | 39341822442 SUCCESS |
| #144 fd551da6163e014aad901c40e9b7975e1a29f0e9 | 39342521773 SUCCESS | 39342521800 SUCCESS | 39342521775 SUCCESS |
| #145 817489db98f1a47140ba5c07fd7bc175d1081e79 | 39342732825 SUCCESS | 39342732850 SUCCESS | 39342732906 rerun SUCCESS |
| #146 913d9a2ed34aeff46514acead45c054f105a67e8 | 39344765440 SUCCESS | 39344765436 SUCCESS | 39344765414 SUCCESS |

La #145, prima execuție Native a fost marcată cancelled după avansarea ramurii cu un commit exclusiv documentar; jobul a fost relansat pe același SHA de cod și a terminat SUCCESS. Pentru #141, attempt-urile de mediu 1–2 și retry-ul cu succes sunt descrise în PR și raport. Codul verificat pentru #145 rămâne părinte al commitului documentar 7da7476dd8fc28f08e6105abfcdcce5d704329f3.

### Lot #146 — filtrele locațiilor mapate

PR Draft #146 913d9a2ed34aeff46514acead45c054f105a67e8, copil al #145, extrage intersecția generică categorie/status/GPS folosită de marker list, count/list fără coordonate și gruparea pe categorie în lib/map/map_location_filters.dart. Testele test/map_location_filters_test.dart acoperă categoria și statusul selectat, GPS complet/parțial, restricția unui panel la o categorie și selecții goale. Se păstrează ordinea de intrare înaintea sortărilor existente. Nu depinde de modele, UI, Firebase sau pachete noi. Branch-filter-ele Validate/Android/Native admit baza #145, iar contractul lor structural este actualizat; nu s-au schimbat pașii workflow sau politica de deploy.

Testele locale per lot: 173 Python, 3 Node și git diff --check PASS; Flutter/Dart nu sunt instalate local. Pentru toate schimbările Map #141–#146, codul/politicile au regression tests focalizate și CI exact-head este verde. PR-urile #134–#146 rămân Draft/Open și nemergate la această verificare. MapPage păstrează cuplare între GPS, UI, modele și orchestration; acesta este progres incremental, nu închiderea modularizării aplicației. Nicio ștergere bazată pe duplicate de asset/config fără dovadă, nicio schimbare Firebase. production_ready=false.

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



## Addendum XIX — verificarea incrementală a politicilor MapPage (19 octombrie 2026, UTC)

### Diferențial față de auditul din 12 octombrie

Recontrolul codului din #136 a confirmat că validarea punctelor GPS și politica cache-ului geometriei rutiere erau încă implementate în `MapPage` (`part` din `main.dart`). Ambele sunt funcții pure fără IO; au fost mutate în module autonome și acoperite cu teste de graniță. Regulile geospațiale și expirarea nu s-au schimbat. Aceste constatări au fost reconfirmate în HEAD-ul curent și nu reutilizează automat observațiile istorice.

| PR / exact HEAD | Modulare și dependențe | Duplicare/dead code | Teste și CI |
|---|---|---|---|
| #139 `d4c5325f3ef7ae9831ff2b99c7a8a10ad257b551` | `map_geometry_cache_policy.dart` separă formarea cheii coordonatelor și TTL-ul de 5 minute din `MapPage`; depinde de `latlong2`, fără UI sau IO. | Niciun dead code șters și niciun duplicat Dart byte-identic identificat. Ordinea coordonatelor, precizia 6 zecimale și pragul strict rămân identice. | `map_geometry_cache_policy_test.dart`; Validate `39330028546`, Android `39330028582`, Native `39330028636`: SUCCESS pe HEAD. |
| #140 `adc1484ae579ad17372e7f70609a231ff4f40451` | `map_point_validation.dart` separă regula GPS apelată înaintea scrierilor markerelor; depinde de `latlong2), fără storage, permisiuni sau UI. | Nu s-a eliminat logică presupus moartă. Limitele inclusive, coordonatele finite și respingerea `(0,0)` sunt păstrate pentru aceleași trei apeluri. | `map_point_validation_test.dart`; Validate `39330296822`, Android `39330296806`, Native `39330296765`: SUCCESS pe HEAD. |

### CI final și compoziție stacked

- #136 code HEAD `0c9cbc6e1090c295db2c867826ca58447e738df9` rămâne checkpointul anterior validat. Pe descendentul routing-only `611373f5f40fab34754a9629d5249d55c457c825`, Validate `39328855282`, Android `39328855242`, Native `39328855346` au toate SUCCESS. Native a avut două încercări eșuate de runner: finder-ul UI nu a găsit temporar „Craiova 02”, apoi descărcarea NDK a returnat arhivă invalidă. A treia încercare a trecut testul UI, verificarea PDF și upload-ul.
- #137 HEAD `b49512b382e1731fd0158149b5b527a163780185`: Validate `39329182964`, Android `39329183035`, Native `39329183078` — SUCCESS.
- #138 code HEAD anterior `9d80d35a0e9b8a1b134a20afe52d8dc71b6669a0`: Validate `39329350464`, Android `39329350579`, Native `39329350418` — SUCCESS. Această notă documentară este adăugată în continuarea branch-ului #138 și va fi retestată pe noul exact HEAD.
- Pentru #139/#140 au trecut local 173 teste Python/security, 3 Node projection tests și `git diff --check`; Flutter/Dart sunt verificate prin CI exact de mai sus. Toate cele patru loturi rămân Draft/Open și nemergate, direct bazate pe #136 routing-only; niciun patch de produs #134–#138 nu a fost reaplicat.
- `main` și regulile oficiale sunt neschimbate. Nu s-au modificat Firebase, comportament, dependențe, releases, semnare ori APK.

### Obligații care rămân după loturile MapPage

Extragerea a două politici pure nu modularizează întregul MapPage. MapPage, HomePage, ExpensePage, ProgramPage și DashboardPage rămân pagini mari `part`-uri. Nu elimina cache-urile Home, nu simplifica parsarea financiară și nu fragmentează mutații Firestore până când contractele/fallback-urile nu sunt modelate prin teste. Continuă inventarierea dependențelor, verifică orice candidat de cod nefolosit înainte de ștergere, apoi separă UI și IO incremental cu teste pe fiecare limită. `production_ready=false`.


## Addendum XIX — checkpoint C35–C38 (21 octombrie 2026, UTC)

### Candidate status and exact-head evidence

| Candidate | Exact HEAD | Validate | Android | Native | Verdict |
|---|---|---|---|---|---|
| C35 / PR #213 — optional automatic Expense OCR prefill | `87a7c13281e8443abc19d72a62cfdf7445f8266d` | run `39534696560` SUCCESS; web `12316738143` SHA-256 `97999396afeab514de81b8a3635f25831bb80bcb05d41f5e73c955e26e43a09b`, PDF `12316563464` `14577627af8096c0703aaa4a7f98482947a3d3c2a3626235a95b1673464b34d3`, audit `12316353648` `0b02f80aa501d7355202297727eb672b2dd380fb44352adb5ef426b0d365451b` | run `39534696587` SUCCESS; APK `12316144752` SHA-256 `5e9eec807eba4046d457b1b8731796d686e941921cc8b0c78b5c958f8ff81906` | run `39534696637` SUCCESS; evidence `12318270032` SHA-256 `a4a9415dc34765f5eb51a1356cef9f417829c7b2776ad4a0b90ce24ff42c19bd` | Fully validated |
| C36 / PR #214 — Home live location resource lifecycle | `214812c54c75ae147b249076af5304c815d100a9` | run `39534999364` SUCCESS; web `12316758621` SHA-256 `3b37e7ef2abac1ffc9050b28747ac4de19c34093141bc013cb3aff0b5e82a55e`, PDF `12316683716` `7e0239ad42908a17bed1942241360925bfc20a8ab67b6c02a88b22c9cb2390c1`, audit `12316897937` `ddc855e1433e15b962fd65b5c64f3ef888e758dd7737df8b2a0276eff0133185` | run `39534999348` SUCCESS; APK `12317213780` SHA-256 `35dc60a5d30e1061dc29c67555edb812fc1dce4c33d3467d39e9f18f2c08996d` | run `39534999537` first attempt failed before emulator/UI: Android 36 Google APIs image download returned `Error on ZipFile unknown archive`; same-SHA retry is active. Diagnostic artifact `12317194651` SHA-256 `b697de680fc04987795c73ad4c85be097505598fb2277ba2bdfa375c4dea5821` | Partially validated pending Native retry |
| C37 / PR #215 — Map route line presentation | `9117fc3c8cd9e5b3698beabd216171e299baeccd` | run `39535914321` SUCCESS; web `12316854957` SHA-256 `3e4c45fc712dbd95b9cf01733954c5e9a55013b6003ff1e79016076f4fc275fb`, PDF `12317530462` `e208e2c6938312cda6fdd7c0cfc627bb0f2d90299811111c38140f01c2542a03`, audit `12317069111` `5b8ad7fb1c7f01b63651fe461e953a3a3cc0757981a9bcc6fdec9fb095b9e0e2` | run `39535914331` active after focused contracts/analyze | run `39535914376` active after focused contracts/analyze | Partially validated pending packaging/native evidence |
| C38 / branch preparation — Dashboard active record selection | Test-first contract commit `b9ec953958179aa0bfa282253c16f1bdbeeaaf84`; implementation is isolated on `codex/xix-dashboard-active-record-selection-20261021` | Not started | Not started | Not started | No PR created; requires C37 terminal validation first |

C35 changes only the eligibility/dispatch boundary for optional automatic OCR; manual document selection, retry/fallback, persistence, and financial calculations remain with ExpensePage. C36 moves ownership of the existing web poll timer and native position subscription into a resource lifecycle helper; permission checks, sampling policy, background behavior, and callbacks remain in HomePage. C37 moves only the already-existing complete-route polyline palette/segment construction; route selection, geometry, and GPS stay in their established modules. Each extraction has focused contract tests and runs in the cumulative Draft chain.

### CI routing investigation

C31 `86d58d3f85d3c8643d7ec2f8f5c751c3c87cb4e4` and C32 `389e30dd937ebcd57c7bcbfdd18e11b7795f565f` have passing Validate runs but no Android/Native PR runs. On each exact SHA, both Android and Native workflow files contain two same-indentation `run:` keys in one Home proximity test step; GitHub recorded only push-triggered workflow-file failures with zero jobs, not test failures. The Android duplicate is absent at hotfix `5f1967150acef5d9b7fc493b145881aa7161732d`; the Native duplicate is absent by C33 `a5fb8ec8772d8f0a25ab42b17b62121a6d04155a`. C31/C32 are not retrospectively certified on Android/Native because rerunning their invalid workflow definitions on new code would not certify those original SHAs.

C37 additionally exposed and corrected a stacked-base predicate typo before final certification: a branch-list edit initially joined two Native `github.base_ref` values into one string and produced a skipped job on an intermediate SHA. The final candidate fixes the predicate, checks each exact base value, and adds a Python contract that rejects multiple `run:` keys in any Android/Native workflow step. Validate passed those regression contracts on C37's exact current HEAD.

### Remaining responsibilities and next work

- C38 isolates only Dashboard's existing running and waiting record selection plus newest-first ordering in `dashboard_record_selection.dart`. Contracts pin same-team filters, status/start/end requirements, operational work-date inclusion, and ordering. It does not alter START/STOP, transaction writes, team state, or C34 status priority.
- Home still couples permission maintenance, Firebase synchronization, cache projection, background location writes, and screen orchestration. Keep those as separately tested boundaries; do not change GPS permission/background semantics without contract evidence.
- ExpensePage still owns persistence, settlement workflows, financial mapping, and PDF invocation after OCR and validation helpers. Preserve integer-bani, rounding, record identity, and legacy/v2 settlement behavior.
- Program/Dashboard still include UI orchestration around transactions and concurrency; keep pure selection/projection extractions separate from Firestore effects.
- MapPage still coordinates Mapbox loading, route selection, GPS permission/lifecycle, and presentation; the C37 helper does not move these responsibilities.
- All PRs remain Draft/Open and unmerged. No production Firebase change, deploy, release signing, or production APK distribution was performed. `production_ready=false`.
