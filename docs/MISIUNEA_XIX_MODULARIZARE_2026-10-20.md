# Misiunea XIX — inventar și continuarea modularizării

**Data verificării:** 20 octombrie 2026 UTC  
**Reguli `main`:** blob `ddbdc55128c285337b006958f86ef323ff6be7c5`; SHA `main` `8452159475ff187867002425fa9c3b8c7e8006aa`.  
**Audit oficial folosit:** `AUDIT_MODULARIZARE_2026-10-12.md`, blob curent `1f7d9fb93b7be46a28348db8110cefaed9f99a8f`, versiunea revizuită în PR #146; inventarul complet la SHA #136 `0c9cbc6e1090c295db2c867826ca58447e738df9`.  
**Stare la actualizarea raportului:** PR-urile #134–#153 sunt Draft/Open și nemergate; `production_ready=false`.

La verificarea GitHub curentă, PR #136 este încă Draft/Open, dar `head_sha` raportat este `611373f5f40fab34754a9629d5249d55c457c825`; SHA checkpointului inițial furnizat era `0c9cbc6e1090c295db2c867826ca58447e738df9`. PR #137 are baza `611373f5...` și capul `b49512b...`; loturile #147–#153 sunt bazate independent pe #137, astfel încât nu includ modificările validate ale celorlalte PR-uri. Lotul #153 atinge alte linii din `main.dart` și alte fișiere decât #149–#152.

Acest raport păstrează matricea oficială a tuturor familiilor de module la checkpointul #136 și adaugă diferențele inspectate în codul actual, pentru a nu prezenta stările istorice ca rezultate curente. Rândurile fără delta nouă rămân cuplate conform acelui inventar; lipsa unui test focalizat nu înseamnă lipsa oricărei acoperiri indirecte.

## Matricea verificabilă a modulelor aplicației

| Modul | Structură și cuplare observată la #136 | Dependențe, duplicări sau cod nefolosit | Teste identificate |
|---|---|---|---|
| Intrare/adaptoare (`lib/` root) | 11 fișiere autonome; majoritatea ecranelor sunt `part` în `main.dart`; OCR/download au adaptoare condiționale | Flutter/Firebase/pluginuri externe; auditul nu a găsit duplicate Dart exacte | `ocr_parser_test.dart`, `widget_test.dart`, build/web și native CI |
| Admin | 15/15 `part`, 132,693 B | Modele, Firebase și UI implicite din `main.dart`; cuplare transversală | Contracte APK URL/privacy/security și teste repository/CI |
| Auth | 5/5 `part` | Stare globală și Firebase Auth implicite | `admin_security_integration_contract_test.py`, `widget_test.dart`; fără test focalizat pentru fiecare ecran |
| Bootstrap | 2/2 `part` | Inițializare Firebase și eroare de pornire în biblioteca principală | Verificare pornire CI; fără unitate dedicată identificată |
| Centralizer | Pagină `part`, 3 utilitare independente | Writer cu Firestore și snapshot checker; comparație pe câmpurile existente | `centralizer_*_test.dart`, `manual_execution_defaults_test.dart`, native/PDF |
| Chat | 2/2 `part` | UI, identitate și Firestore împart starea globală; duplicate exacte neidentificate | Fără test Dart focalizat pentru ecranele identificate |
| Contacts | 1/1 `part` | Modele/helperi globali impliciți | Fără test focalizat identificat |
| Dashboard | 1/1 `part`, 41,144 B la #136; etichetarea orașului extrasă în #153 | START/STOP și program prin callback-uri globale; formatterul comun de erori separat de Schedule; noul helper depinde doar de nume/adresă | `program_graph_creation_test.dart`, contracte Craiova/learning, `location_city_label_test.dart` (#153), native CI |
| Documents | 1/1 `part` | UI legat de permisiuni și starea Home | Fără test focalizat identificat |
| Expenses | 1/1 `part`, 77,425 B | Cheltuieli, OCR, diurne legacy/v2, settlements și PDF; legacy/v2 rămân distincte | 6 teste Flutter `per_diem_*`; test adiacent în `lib/finance/` nu intră în `flutter test test/` |
| Feedback | 1/1 `part` | Cuplare implicită prin `main.dart` | Fără test focalizat identificat |
| Finance | 14 fișiere independente | Ledger/adaptoare/settlements/reconciliation/payment plan; repository-urile folosesc Firebase; legacy/v2 nu se unifică | 6 teste Flutter `per_diem_*`; un test adiacent în `lib/` |
| Home/sincronizări | 5/5 `part`; HomePage 101,935 B | Auth/subscriptions/cache/serializare/operații/permisiuni transversale; 7 cache-uri au doar scrieri în `lib/`, dar nu se șterg: expresiile `_encoded(...)` pot avea efecte la date invalide | Contracte Python/security/repository și coverage CI; fără unități pentru fiecare subscription |
| Learning | 1/1 `part` | Modele și `AppSettings` globale | `grafic_learning_notifications_contract_test.py`; verificări indirecte în testele de program |
| Map | 4/4 pagini UI `part` la #136; helpers standalone adăugați în #139–#147 | GPS/pluginuri/HTTP/Mapbox/stare globală; UI și orchestration încă împreună; duplicate exacte Dart neidentificate | Teste directe pentru geometry cache, point validation, route selection, reverse-geocode, badge state, programe operaționale, filtre și categorii; fără test MapPage complet |
| Members | 2/2 `part` | Identitate, permisiuni și Firestore globale | `member_directory_minimization_test.py`, `member_directory_projection.test.js`, deploy gate manual |
| Models | 5 `part` + 2 independente la #136; catalogul implicit și etichetele permisiunilor/statusului desprinse în #149/#151/#152 | Modelele de bază încă depind de `main.dart`; modulele noi importă explicit enumuri/definiții și Material | `app_enums_permissions_test.dart`, `location_function_models_test.dart`, plus teste directe pentru etichete/catalog în #149/#151/#152 |
| Notifications | 2/2 `part` | Push diagnostics/SMS folosesc auth/settings globale | Contract notificări/learning și native CI; fără test Dart focalizat pentru fiecare ecran |
| Operations | 2 independente la #136; filtrul generic pentru echipă/locație/zi adăugat în #148 | `atomic_restore` și `record_writer` folosesc Firestore, fără UI; politica generică nu depinde de modele | `atomic_restore_preflight_test.dart`, `record_writer_test.dart`, `work_date_record_selection_test.dart`, recovery authority |
| Profile | 1/1 `part` | Date/setări/permisiuni împărțite implicit | Fără test focalizat identificat |
| Reports/PDF | 2 `part` + 1 independent | Normalizarea numelui e independentă; randarea PDF încă folosește modele globale | `pdf_filename_normalization_test.dart`, `centralizer_pdf_*_test.dart`, `xix_pdf_text_test.py` |
| Schedule | 2/2 `part`; ProgramPage 71,716 B | UI și modele globale implicite; formatterul de eșec comun cu Dashboard a fost extras în #137 | `program_graph_creation_test.dart`, `program_team_selection_test.dart`, `schedule_save_failure_test.dart`, contracte/native |
| Settings | 1/1 `part` | Configurare/admin/persistare în biblioteca comună | Fără test focalizat identificat |
| Teams | 1/1 `part` | Selector UI pe modele globale | `program_team_selection_test.dart` acoperă selecția ProgramPage |
| Testing harness | 1 fișier autonom | Importă intenționat `main.dart` pentru flux sintetic offline | Rulat în workflow-ul de validare; fără backend de producție |
| UI shared | 13 `part` + 5 independente | Catalogurile sunt pure sau Flutter; helpers de temă/UI rămân `part` | Teste badge/branding/font/palette/section assets/install link |
| Utils | 1 `part` + 1 independent la #136; politica pură a datei operaționale extrasă în #150 | Formatarea și politica de zi/fereastră sunt standalone; predicatele pe `CentralizerRecord` rămân `part` | `date_formatters_test.dart`, `work_date_policy_test.dart`, teste Centralizer pentru predicate/date |

**Metodă și limite:** numărătorile structurale provin din matricea auditului oficial la SHA #136, nu au fost recalculate ca proprietăți ale `main` din 20 octombrie. Comparația din audit confirmă la #136: Home 101,935 B; Expense 77,425 B; Program 71,716 B; Map 55,655 B; Dashboard 41,144 B. `scripts/audit_repository.py` a găsit 12 grupuri identice de assets/configurări de platformă; ele nu sunt duplicări logice demonstrabile și nu au fost șterse. Pentru lotul #148 auditul a găsit 459 fișiere urmărite și aceleași 12 grupe.

## Comparație cu constatările istorice

- **Încă valabil structural:** ecranele Home/Expense/Program/Map/Dashboard sunt mari și cuplate ca `part`-uri; modelele și multe ecrane încă depind implicit de `main.dart`.
- **Actualizat și izolat treptat în loturi existente:** Map are helpers independenți pentru route selection, reverse-geocode parsing/transport, badge state, programe operaționale și filtre locații (#141–#146). Fiecare PR are regresii și exact-head CI verde, consemnate în auditul oficial din PR #146.
- **Nedemonstrat drept cod mort:** cele 7 cache-uri write-only și parse-urile repetate `receivedEntries`; evaluări, ordine și efectele de eroare nu sunt suficient caracterizate. Nu se elimină în acest lot.
- **Nu s-au copiat ca actuale probleme istorice:** tabelul principal rămâne snapshotul #136, iar toate schimbările ulterioare se notează distinct mai jos. Cele 12 identități de conținut nu justifică ștergerea resurselor platformei.

## Loturi curente

| PR | Delta independentă | SHA cod | Verificare/regresii |
|---|---|---|---|
| #137 | `lib/schedule/schedule_save_failure.dart`: mesaje comune pentru erori de salvare Schedule/Dashboard extrase fără schimbarea textelor/ramurilor | `b49512b382e1731fd0158149b5b527a163780185` | Test focalizat `schedule_save_failure_test.dart`; Validate `39329182964`, Android `39329183035`, Native `39329183078` SUCCESS pe acest SHA |
| #138 | Parserul sumelor întregi bani reutilizat în Expense input; legacy/v2 și settlement neatinse | cod `9d80d35a0e9b8a1b134a20afe52d8dc71b6669a0`; cap documentar `a995ea7ad3adf1377a3fb60807b1158f18bf42f6` | Validate `39329350464`, Android `39329350579`, Native `39329350418` SUCCESS pe cod; Validate `39332702567`, Android `39332702487`, Native `39332702591` SUCCESS și pe capul documentar |
| #139 | `lib/map/map_geometry_cache.dart`: cheie geometrie cu ordine coordonate/precizie 6 zecimale/expirare >5min scoase din MapPage | `d4c5325f3ef7ae9831ff2b99c7a8a10ad257b551` | Test direct pentru cheie, expirare strictă și ceas înapoi; Validate `39330028546`, Android `39330028582`, Native `39330028636` SUCCESS |
| #140 | `lib/map/map_point_validation.dart`: regulă pură finită și limite inclusive, cu (0,0) respins | `adc1484ae579ad17372e7f70609a231ff4f40451` | Test direct pentru limite și valori invalide; Validate `39330296822`, Android `39330296806`, Native `39330296765` SUCCESS |
| #141 | `lib/map/map_route_selection.dart`: dedupe ID-uri graf, alegere grafic și zile | `39f3506df19d9a53cd2060f646f57a0df567f7e6` | `map_route_selection_test.dart`; Validate `39341558517`, Android `39341558484`, Native `39341558511` attempt 3 SUCCESS |
| #142 | `lib/map/reverse_geocode_address.dart`: parser pur Nominatim | `43690da9808830c3ac2f71d06ca778a09fd910eb` | `reverse_geocode_address_test.dart`; Validate `39341819031`, Android `39341819032`, Native `39341819051` SUCCESS |
| #143 | `lib/map/map_reverse_geocoder.dart`: transport HTTP injectabil, cu parserul din #142 | `97b9f9198a8e739957fe1b4ab9d1b9ffa20e11b3` | `map_reverse_geocoder_test.dart` cu transport fals; Validate `39341822453`, Android `39341822515`, Native `39341822442` SUCCESS |
| #144 | `lib/map/map_work_badge_state.dart`: stare generică completed/next/running | `fd551da6163e014aad901c40e9b7975e1a29f0e9` | `map_work_badge_state_test.dart`; Validate `39342521773`, Android `39342521800`, Native `39342521775` SUCCESS |
| #145 | `lib/map/map_operational_schedules.dart`: filtru programe active pe zi operațională | `817489db98f1a47140ba5c07fd7bc175d1081e79` | `map_operational_schedules_test.dart`; Validate `39342732825`, Android `39342732850`, Native `39342732906` rerun SUCCESS |
| #146 | `lib/map/map_location_filters.dart`: filtrare comună categorie/status/GPS | `913d9a2ed34aeff46514acead45c054f105a67e8` | `map_location_filters_test.dart`; Validate `39344765440`, Android `39344765436`, Native `39344765414` SUCCESS |
| #147 | `lib/map/active_map_categories.dart`: o singură politică generică pentru filtrare/sortare categorii active, folosită la inițializare și în `visibleCategories`; MapPage rămâne `part` | `1a1067a9c19b382e0cb238f283b86e80d2c0471f` | `active_map_categories_test.dart`; local 173 Python, 3 Node, audit 461 tracked/12 identități. Validate `39351271898` SUCCESS, Android `39351271925` SUCCESS, Native `39351271885` attempt 2 SUCCESS. Attempt 1 a eșuat tranzitoriu în emulator la găsirea checkbox-ului „Craiova 02”; rerun-ul exact-head a trecut connected flow/restart, PDF/checksum și artifact upload. |
| #148 | `lib/operations/work_date_record_selection.dart`: filtrele echipă/locație/zi, identice în Map și Schedule, mutate într-o bibliotecă generică fără model; caller-ele păstrează calculul datei, predicatele și sortarea existente | `bd9d073aa2557a6bfbaf92b630507d8d41ff1ed9` | `work_date_record_selection_test.dart`; local 173 Python, 3 Node, audit 459 tracked/12 identități, `git diff --check` PASS. Validate `39352901504`, Android `39352901666`, Native `39352901576` toate SUCCESS pe SHA exact, inclusiv PDF/checksum și artifact. |
| #149 | `lib/models/permission_status_labels.dart` standalone, cu enumuri importate explicit; `main.dart` import/export compatibil | `90a4f55c0cb274866cba6d321a9fa3ee3d381300` | `permission_status_labels_test.dart` exhaustiv pentru toate permisiunile, diurnele și metodele de plată; local 173 Python, 3 Node, audit și `git diff --check` PASS. Validate `39356119509`, Android `39356119375`, Native `39356119346`: toate SUCCESS pe SHA exact. |
| #150 | `lib/utils/work_date_policy.dart` standalone pentru rollover 23:30 și fereastra operațională; predicatele pe model rămân `part` | `078c6413e637f5deb81f13f5726dd79f6e583f35` | `work_date_policy_test.dart` verifică limitele și incluziunea ferestrei; păstrate testele existente Centralizer; local 173 Python, 3 Node, audit și `git diff --check` PASS. Validate `39356344002`, Android `39356343975`, Native `39356344113`: toate SUCCESS pe SHA exact. |
| #151 | `lib/models/default_categories_functions.dart` standalone, cu import explicit pentru enumuri, model și Flutter Material | `45c67956c4fef5b1be23ef7b760e6d97bbbcd568` | `default_categories_functions_test.dart` verifică ID-uri, etichete, culori, permisiuni Admin și lookup; local 173 Python, 3 Node și `git diff --check` PASS. Validate `39357203731`, Android `39357203798`, Native `39357203939`: toate SUCCESS pe SHA exact. Run-urile anterioare `39356465654/680/637` aparțin capului vechi. |
| #152 | `LocationStatusX` extras ca bibliotecă standalone cu importuri explicite | `3af01003bb60b118214771025c8197f864a06d07` | `location_status_labels_test.dart` verifică textul, iconurile și culorile tuturor statusurilor; local 173 Python, 3 Node și `git diff --check` PASS. Validate `39357202983`, Android `39357202962`, Native `39357202965`: toate SUCCESS pe SHA exact, inclusiv emulator și artifact upload. Run-urile inițiale `39356643270/259/293` aparțin capului anterior, după repoziționarea importului. |
| #153 | `lib/dashboard/location_city_label.dart` extrage politica pură de etichetare din nume/adresă folosită de Dashboard; geocodarea și caller-ul GPS rămân neschimbate | `d1e7325a5bcfc0fb95082f581d5fcaa874160f84` | `location_city_label_test.dart` acoperă segmente finale, prefixe românești, țară/cod poștal și fallback; local 173 Python, 3 Node, `git diff --check` PASS. Validate `39358474548`, Android `39358474533`, Native `39358474429`: toate SUCCESS pe SHA exact, inclusiv flux conectat/restart, PDF/checksum și artifact upload. |

## Obligații rămase

1. Raportul consolidat este publicat pe PR #148; această revizie adaugă lotul #153 și verdictul său final. #147–#153 au Validate, Android debug și Native SUCCESS pe SHA-urile lor exacte.
2. Descrierea PR-urilor păstrează separat SHA-urile de cod verificate și SHA-ul raportului. Documentul oficial `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` nu este modificat.
3. Continuă separarea paginilor mari, modelelor și API-urilor din `main.dart` în loturi mici, independente și caracterizate cu teste; matricea nu marchează modularizarea completă până când nu există dovezi pentru toate familiile.
4. Lotul #153 desprinde numai formatarea etichetei de oraș, fără a schimba geocodarea ori politica GPS; decuplarea ecranelor mari continuă în loturi controlate.
5. Investighează separat cache-urile fără cititori și parser-ele `receivedEntries`; fără eliminare/consolidare până când efectele, ordinea și identitatea sunt testate.
6. Păstrează fluxurile legacy/v2, stickerele, adaptoarele de platformă și datele. Fără merge, deploy, schimbări Firebase de producție, semnare sau distribuire APK.
7. Modularizarea integrală nu este închisă; `production_ready=false`.


## Actualizare live — verificare 20 octombrie 2026, 04:10 UTC

Toate rezultatele de mai jos au fost recitite din GitHub după checkpointul anterior. SHA-urile de cod nu s-au schimbat. #154, #155 și #156 sunt Draft/Open și nemergate. Stările SUCCESS de mai jos se referă strict la SHA-ul menționat.

### CI și probe exact-head

| PR / SHA cod | Validate | Android debug | Native emulator | Artefact Native / hash | Concluzie |
|---|---|---|---|---|---|
| #154 `dd209555054e247fd907f9b71608ab9cdaed335b` | `39363877750` SUCCESS | `39363877801` SUCCESS | `39363877751` SUCCESS | Artifact `12238413393`, ZIP SHA-256 `31815a16004d56997c16ee913f264109626095e554b577162c4a38c8b54ccbc3`; PDF SHA-256 `25281c932adc9b80cd0b721a012b621d59f3c74bd5b808b67283f93578fde589` | Scenariul UI conectat, reload, 11 intervenții și PDF: SUCCESS |
| #155 `7b3dd70f6028a827c9bf89faf260d6635059068e` | `39362736082` SUCCESS | `39362736225` SUCCESS | `39362736043` SUCCESS | Artifact `12238402379`, ZIP SHA-256 `7d096652f41cbff395544a9427c5fee4684f1c0f342e6749464512f7af36328b`; PDF SHA-256 `c51270c89c4eecbca1386f2f48f8a8b2e639962786679022cc6103c20fc160e7` | 11 intervenții recitite, două cold restarts autentificate și navigare: SUCCESS |
| #156 `93e56b2699dd73b252e691cb220eba6fb40b90d8` | `39364036427` SUCCESS | `39364036351` SUCCESS | `39364036348` SUCCESS | Artifact `12238104506`, ZIP SHA-256 `e7581060f210962eea7c71697e20c8ae7f463439f01fdfb30f8ec188ea0747bb`; PDF SHA-256 `632a54d70c3aa42842685e39220dd5799a819b3832a14876943af6e929b7ec28e` | Web build, unit/widget, Firestore emulator, connected Native și PDF: SUCCESS |

Artefactele native conțin `observations.json`, capturi și ierarhii XML pentru ecranele Grafic/Centralizator/Acasă, textul extras din PDF și `SHA256SUMS`. SHA-ul ZIP este digestul raportat de uploadul GitHub Actions; SHA-ul PDF este din `SHA256SUMS`.

### Analiza blocajului „Craiova 03”

Eșecul inițial a fost în automatizarea UI. Testul folosea `find.byType(TextField)`, deși dialogul conține mai multe câmpuri, și selecta primul `Scrollable` al dialogului, care nu identifica sigur lista virtualizată a selectorului. Regresia restrânge câmpul după eticheta vizibilă și scroll-ul la `CustomScrollView` al selectorului. Logul de rerun raportează `resultTiles=1` pentru fiecare query Craiova 01–11; observațiile confirmă `graphCreatedThroughUi=true`, 11 documente UI/Firestore distincte și `pdfMatchedScheduleItems=11`. PDF-ul nativ a fost generat, extras cu Poppler și verificat după text; include cele 11 intervenții și rândul planificat neexecutat. Nu a fost identificat un defect separat PDF sau o lipsă de locație în fixture. Nu s-au schimbat fixture-ul ori regulile de business.

### Expenses: limita compatibilității financiare

#156 mută verbatim parserul `parsePerDiemBani` și adaugă teste pentru conversie, separator zecimal, zero, limita veche de 100.000.000 lei, precizie și date invalide. Aceasta validează contractul parserului, nu echivalența cu soldurile.

`ExpensePage._perDiemDifferenceBani` păstrează un contract legacy: filtrează perechea beneficiar/distribuitor și doar înregistrările confirmate cu sumă primită; plățile suplimentare reduc datoria și nu creează o nouă diurnă. `lib/finance/per_diem_ledger.dart` folosește entitlements/payments/reversals, perechi distribuitor-beneficiar, idempotency și o limită distinctă de bani. Modelele, unitățile și regulile nu sunt interschimbabile; nu există o migrare sau un adapter sigur demonstrat. Nu se raportează „compatibilitate cu ledgerul”. Următoarea extragere Expenses trebuie să fie separată, să caracterizeze politica legacy (plată exactă/scurtă/excesivă, suplimentară, neconfirmată, perechi izolate) și să țină testele ledgerului independente.

### Progres actualizat pentru cele șase module

| Modul / fișier dominant | Extrageri existente până la #156 | Responsabilități încă amestecate | Următoarea extragere sigură și verificare | Dependențe, risc și conflicte |
|---|---|---|---|---|
| Home — `lib/home/home_page.dart`, ~101.611 caractere | Backup/permisii, codec documente, seed de locații și utilitare de sincronizare extrase în loturi anterioare | Lifecycle/subscriptions/cache, push tokens, GPS, START/STOP și scrieri Firestore/navigare | Mai întâi un policy pur pentru starea live-location; caracterizare pentru stări, expirare și uid/team înainte de extragerea orchestration-ului | Cuplare puternică la Auth, permisiuni, timer/stream și Firestore; risc ridicat la scrieri/lifecycle |
| Expenses — `lib/expenses/expense_page.dart`, ~76.911 caractere | Parser sumă din #138; parser diurnă în Finance din #156 | UI cheltuieli/OCR/atașamente, settlement legacy/v2, sold carryover și PDF | Extrage politica legacy `_perDiemDifferenceBani` ca helper pur numai după teste dedicate; păstrează ledgerul separat | Nu echivalează cu ledgerul: supplementary semantics și amount bounds diferite; nu reutiliza calculul fără decizie |
| Program/Grafic — `lib/schedule/program_page.dart`, ~70.154 caractere | Save-error #137, route selection #141, work-date selection #148, geocoder comun #154 | UI creare/editare, stare și lifecycle grafic, START/STOP/pause/restart | Următoarea seam: proiecție pură de eligibilitate/create Graph; fixture 11 item-uri și teste ordine/status/active/open | Se bazează pe modele și callback-uri globale; păstrează verificarea Native Craiova și state orchestration neschimbată |
| Map — `lib/map/map_page.dart`, ~55.407 caractere | #139–#147: cache, puncte, rutare, geocoder invers, badge, programe active, filtre locație și catalog categorii | Controller Mapbox/GPS, markere, sheet-uri, tap/edit/navigation și lifecycle | Extrage un view-model pur de marker după characterization pentru icon/status/tap permissions | Plugin, permisiuni, mounted/dispose și identitatea echipei; risc mediu spre mare, fără schimbare de marker policy implicită |
| Dashboard — `lib/dashboard/dashboard_page.dart`, ~40.916 caractere | Mesaje salvare #137, city label #153, geocoder #154 | START/STOP și prezentarea stării plus coordonarea create/finish/wait/write | View-state pur pentru etichetă/culoare/icon de status, cu test exhaustiv pe statusuri | Scrierile au lock/CAS/idempotency și izolare de echipă; extragerea writerului are risc ridicat |
| Rapoarte/PDF — `lib/reports/pdf_reports.dart`, ~28.181 caractere | Filename normalization și utilitare de format/salvare în loturi anterioare | Generarea mai multor PDF-uri în aceeași bibliotecă part; Centralizer projection încă amestecată cu modele globale | Candidați pentru extragere: `centralizerPdfExecutionRows` și DTO autonom, după explicitarea dependențelor; verifica testele projection și PDF text/hash | Depinde de record/status/date/model; schimbarea formatării poate altera PDF-ul. #154–#156 nu ating projection-ul |

Riscul producției rămâne: toate verificările sunt pe emulator, synthetic team și Firebase emulators; nu probează configurația sau datele Firebase de producție. Nu s-a făcut merge, deploy, signing sau distribuire APK. `production_ready=false`.

### Următoarele operațiuni autonome

1. Revizuiește și rulează exact-head CI pentru următorul PR modular de raportare/PDF, pe o ramură independentă bazată pe #137, dacă dependențele projection-ului pot fi făcute explicite fără mutarea modelelor.
2. Continuă Expenses numai cu teste separate pentru politica legacy; nu adaptează ledgerul pentru a mima soldul legacy.
3. Păstrează completările de #154–#156 Draft/Open și înregistrează eventualele review-uri fără merge.
4. Reauditează capetele #134–#156 înainte de un candidat consolidat și menține `production_ready=false`.

## Checkpoint live Misiunea XIX — 20 octombrie 2026, 05:05 UTC

Am verificat starea GitHub înaintea acestei actualizări. PR-urile #145, #146, #148 și #154–#163 sunt Open/Draft, nemergate. Nu s-a făcut merge sau deploy. Rezultatele din tabel sunt legate de SHA/run-urile enumerate.

### Validare exact-head

| PR | HEAD | Validate | Android | Native | Artefacte și concluzie |
|---|---|---|---|---|---|
| #154 | dd209555054e247fd907f9b71608ab9cdaed335b | 39363877750 SUCCESS | 39363877801 SUCCESS | 39363877751 SUCCESS | Artifact 12238413393, ZIP SHA-256 31815a16004d56997c16ee913f264109626095e554b577162c4a38c8b54ccbc3; PDF SHA-256 25281c932adc9b80cd0b721a012b621d59f3c74bd5b808b67283f93578fde589. UI, Firestore 11 rânduri și PDF verificate. |
| #155 | 7b3dd70f6028a827c9bf89faf260d6635059068e | 39362736082 SUCCESS | 39362736225 SUCCESS | 39362736043 SUCCESS | Artifact 12238402379, ZIP SHA-256 7d096652f41cbff395544a9427c5fee4684f1c0f342e6749464512f7af36328b; PDF SHA-256 c51270c89c4eecbca1386f2f48f8a8b2e639962786679022cc6103c20fc160e7. Conectare, două reporniri, 11 rânduri/PDF: SUCCESS. |
| #156 | 93861efab61b762a5e0b9ee9485232feb578326c | 39369094268 SUCCESS | 39369094283 SUCCESS | 39369094381 SUCCESS | Artifact 12241092689, ZIP SHA-256 e9327e78a37cffd63cafef79f00d0feaaf352008099ec50b03c81831a14c6405; PDF SHA-256 94e875a6c4cfb1604f174c101fce7ee5ff6a701766d3a822bf9052a9947ac417. Web, Android, Native, parser/ledger contract și PDF: SUCCESS. |
| #157 | 310368920f86be7e5a3a97298c4dd31714c6ee63 | 39368459523 SUCCESS | 39368459549 SUCCESS | 39368459469 SUCCESS | Artifact 12240423292, ZIP SHA-256 62aa1376521800245c2b8d20bc6fe882485a764ebc9b6f008dd87f2330d8b2f2; PDF SHA-256 cf3ccb06c9a8da57c3c442cbb2cd3c11e151fab14cfa7c2d05bb63f8dfb7872b. Projection, connected flow și PDF: SUCCESS. |
| #158 | 8f77859eb6ab590e3aeafd69a8683be136a5404d | 39369120334 SUCCESS | 39369120287 SUCCESS | 39369120306 SUCCESS | Artifact 12240639885, ZIP SHA-256 7342dae9d06da4da78c0120034c8cc41b36cae6045d8c07fd66ffe0fd2004f73; PDF SHA-256 9f60a1bf740a98d2313e5c8a7bba9448d45e0930ce9941d9518670ccf4ff569b. Stacked peste #156; 11 rânduri, idempotency, stale baseline, izolare echipă și offline denial: SUCCESS. |
| #159 | 240fc94912ede6b970711ffddb55d724e710767b | 39369245152 SUCCESS | 39369245161 SUCCESS | 39369245054 SUCCESS | Artifact 12240509336, ZIP SHA-256 f4257981471f29988358ba7517396e062d9fb990ab6ad51eda359c9fc4c7f2ca; PDF SHA-256 18e67824a9c3ac25e460ec9c8d5344564710698cdb9df9617a389ba1d80c158d. Dashboard, reload, 11 rânduri/PDF: SUCCESS. |
| #160 | 32ddacd755ead3bd727c8b2f0e0e1f5fdc717f50 | 39370471019 SUCCESS | 39370471221 SUCCESS | 39370471025 IN PROGRESS | Android artifact 12241257099, ZIP SHA-256 4b4378ea6b0faec7472f39138c3967c11c66eb52469a48389b7fa60ca954b67d. Native la connected flow/restart; PDF/checksum/upload încă pending. |
| #161 | c30c60794a812991328cb9094d8d1a8ea3b4ff0e | 39371522926 SUCCESS | 39371522913 IN PROGRESS | 39371523027 IN PROGRESS | Validate și teste focalizate trecute. Android debug/Native operational APK în packaging; connected flow/PDF încă pending. |
| #162 | f408eedd1325b0c45b528f960ce6cec93320d66a | 39371034740 SUCCESS | 39371034683 SUCCESS | 39371034711 IN PROGRESS | Validate artifacts: PDF 12241381697 SHA-256 7f4949800e6ffeb385d901838b35988bcf0f6457babdbf3b85252b011bd4260d; web 12241356925 SHA-256 c1d975daa521b87cc11859a1af4b698b117d6a633006adb43ed201a9079b098e; audit 12240869830 SHA-256 8a6bb7f0897991b4c595d82394c3a747c8dc6ce4d0a8974fd804be448dcc098c. Native compiling release candidate; connected flow/PDF pending. |
| #163 | f67a3bd9e5bd854b3b76c1622ee026d8a564516c | 39371563027 SUCCESS | 39371563083 IN PROGRESS | 39371563029 IN PROGRESS | Validate, analysis și teste trecute; Android/Native packaging. Connected flow/PDF pending. |

Pentru run-urile active artifactele nu erau publicate, deci nu există încă digest-uri finale de consemnat. Nu au fost observate eșecuri curente la checkpoint.

### Blocajul „Craiova 03” și PDF

Cauza demonstrată la #154 este automatizarea UI: locator global TextField într-un dialog cu mai multe câmpuri și scroll pe primul Scrollable, în locul listei virtualizate din picker. Regresia limitează locatorul după eticheta vizibilă și scroll-ul la CustomScrollView-ul pickerului. Diagnosticul Native raportează un rezultat pentru Craiova 01–11; fluxul a creat graficul, a scris și recitit 11 documente și a trecut validarea PDF. PDF-ul include cele 11 intervenții plus rândul planificat. Nu s-a găsit defect PDF independent, lipsă în fixture, defect de încărcare/ordonare date sau defect de produs.

### Expenses și dependențe

#156 mută parserul pur de bani; #158 extrage politica legacy de sold și este stacked justificat peste #156. Ledgerul din lib/finance/per_diem_ledger.dart rămâne separat; nu a fost introdus al doilea calculator. #162 duplicate matcher este sibling independent și nu schimbă OCR, atașamente, salvare, ledger sau sume. Rămâne necesar contractul automat de compatibilitate între caller-ele Expenses și ledger, păstrând formulele distincte.

### Progresul celor șase module mari

| Modul / fișier dominant | Deja extras | Amestecat încă | Următoarea extragere sigură și teste | Dependențe și risc |
|---|---|---|---|---|
| Home — lib/home/home_page.dart (~101.6k caractere) | Backup/permisii, codec, seed/sync; #163 policy pur cadence/eligibility live-location | Auth/session, subscriptions/cache, GPS stream/timer, push, Firestore writes, lifecycle, START/STOP | Caracterizează UID/team ownership și callbacks stale/dispose înainte de orchestration extraction; teste offline, interval/accuracy/threshold/heartbeat | GPS, permissions, Firestore și lifecycle; risc ridicat. #163 nu mută side effects. |
| Expenses — lib/expenses/expense_page.dart (~76.9k) | #138 amount parser, #156 per-diem parser, #158 legacy balance, #162 duplicate matcher | OCR/attachments, manual save, settlement legacy/v2, PDF | Teste contract pentru amount bounds, confirmed/pending, perechi beneficiar-distribuitor, prag duplicate, OCR fallback; abia apoi adapter/presentation seam | #158 depinde de #156; #162 sibling. OCR/storage async și ledgers diferite; risc ridicat. |
| Program/Grafic — lib/schedule/program_page.dart (~70.2k) | #137 save-error, #141 route selection, #148 work-date, #154 geocoder | Create/edit UI, state/lifecycle, START/STOP/pause/restart | Teste order/status/open/active, fixture 11 locații, save/reload; separă o proiecție pură eligibility/create după fixture | Models/callback globals; risc mediu-ridicat. Import area comună posibil conflict textual. |
| Map — lib/map/map_page.dart (~55.4k) | #139–#147 policies; #160 Maps/Waze URI; #161 marker widget | Mapbox/GPS controller, marker actions, sheets, tap/edit, permissions/lifecycle | Parity tests marker; înaintea controller extraction: plugin permission, mounted/dispose și callback tardiv | #160/#161 funcții diferite, dar aceeași pagină/import zone; risc mediu-ridicat. |
| Dashboard — lib/dashboard/dashboard_page.dart (~40.9k) | #137 errors, #153 city label, #154 geocoder, #159 status presentation | START/STOP writes, create/finish/wait, state coordination | Contract CAS/idempotency/team auth/stale replay înaintea orchestrator extraction | Firestore/finance; risc ridicat. Geocoder/status helpers sunt independenți. |
| Rapoarte/PDF — lib/reports/pdf_reports.dart (~28.2k) | Filename/format/save helpers; #157 Centralizer PDF projection | Multi-report generation, permissions/download/share, model mapping/PDF IO | DTO rows/totals/order/null status/date; text/hash golden și cancel/save errors; următoarea proiecție pură fără format changes | Financial formatting și lifecycle download; risc mediu-ridicat. |

#158 este singurul stack funcțional din loturile noi; celelalte (#159–#163) sunt siblings pe #137. Mai multe PR-uri adaugă importuri în zone apropiate din main.dart; pot apărea conflicte textuale la integrare fără suprapunere semantică. Nu există încă CI comun pe un candidat cumulativ.

### Blocaje și pași următori

- Rămân IN PROGRESS exact-head: #145 Native rerun 39344436266; #160 Native 39370471025; #161 Android/Native 39371522913/39371523027; #162 Native 39371034711; #163 Android/Native 39371563083/39371563029.
- #145 HEAD 7da7476dd8fc28f08e6105abfcdcce5d704329f3; Validate 39344436278 și Android 39344436245 SUCCESS. Native fusese anulat și rerun-ul exact-head este în curs de build.
- Acest document este în PR #148; după actualizare trebuie verificat noul HEAD al raportului și rulate workflows pe commitul documentar exact.
- Emulatorul și echipa sintetică nu validează configurația Firestore de producție, hardware GPS real, multi-process sau distribuția APK. Nicio schimbare Firebase live, merge, deploy, signing sau distribuire.
- Următorul pas autonom: finalizarea rundelor active, inspectarea logurilor și artifact SHA-256, actualizarea PR bodies cu rezultate exacte, validarea noului HEAD #148 și continuarea unei extrageri independente cu contracte păstrate.
- production_ready=false.


## Checkpoint continuare — 20 octombrie 2026, 06:30 UTC

Stări recitite din GitHub înainte de acest checkpoint. Toate PR-urile de modularizare #154–#167 sunt încă Open/Draft și nemergate. Run-urile SUCCESS sunt legate de SHA-ul de mai jos; cele marcate IN PROGRESS nu sunt certificate.

### CI exact-head și dovezi

| PR | HEAD | Validate | Android | Native | Artefact / dovadă | Stare |
|---|---|---|---|---|---|---|
| #154 | `dd209555054e247fd907f9b71608ab9cdaed335b` | 39363877750 SUCCESS | 39363877801 SUCCESS | 39363877751 SUCCESS | Artifact 12238413393, ZIP SHA-256 `31815a16004d56997c16ee913f264109626095e554b577162c4a38c8b54ccbc3`; PDF SHA-256 `25281c932adc9b80cd0b721a012b621d59f3c74bd5b808b67283f93578fde589` | SUCCESS; 11 rânduri Firestore și PDF verificate |
| #155 | `7b3dd70f6028a827c9bf89faf260d6635059068e` | 39362736082 SUCCESS | 39362736225 SUCCESS | 39362736043 SUCCESS | Artifact 12238402379, ZIP SHA-256 `7d096652f41cbff395544a9427c5fee4684f1c0f342e6749464512f7af36328b`; PDF SHA-256 `c51270c89c4eecbca1386f2f48f8a8b2e639962786679022cc6103c20fc160e7` | SUCCESS; două cold restarts și PDF verificate |
| #156 | `93861efab61b762a5e0b9ee9485232feb578326c` | 39369094268 SUCCESS | 39369094283 SUCCESS | 39369094381 SUCCESS | Artifact 12241092689, ZIP SHA-256 `e9327e78a37cffd63cafef79f00d0feaaf352008099ec50b03c81831a14c6405`; PDF SHA-256 `94e875a6c4cfb1604f174c101fce7ee5ff6a701766d3a822bf9052a9947ac417` | SUCCESS; parserul rămâne distinct de calculul legacy și ledger |
| #157 | `310368920f86be7e5a3a97298c4dd31714c6ee63` | 39368459523 SUCCESS | 39368459549 SUCCESS | 39368459469 SUCCESS | Native artifact 12240423292, ZIP SHA-256 `62aa1376521800245c2b8d20bc6fe882485a764ebc9b6f008dd87f2330d8b2f2`; PDF SHA-256 `cf3ccb06c9a8da57c3c442cbb2cd3c11e151fab14cfa7c2d05bb63f8dfb7872b` | SUCCESS |
| #158 | `8f77859eb6ab590e3aeafd69a8683be136a5404d` | 39369120334 SUCCESS | 39369120287 SUCCESS | 39369120306 SUCCESS | Native artifact 12240639885, ZIP SHA-256 `7342dae9d06da4da78c0120034c8cc41b36cae6045d8c07fd66ffe0fd2004f73`; PDF SHA-256 `9f60a1bf740a98d2313e5c8a7bba9448d45e0930ce9941d9518670ccf4ff569b` | SUCCESS; stacked peste #156 |
| #159 | `240fc94912ede6b970711ffddb55d724e710767b` | 39369245152 SUCCESS | 39369245161 SUCCESS | 39369245054 SUCCESS | Native artifact 12240509336, ZIP SHA-256 `f4257981471f29988358ba7517396e062d9fb990ab6ad51eda359c9fc4c7f2ca`; PDF SHA-256 `18e67824a9c3ac25e460ec9c8d5344564710698cdb9df9617a389ba1d80c158d` | SUCCESS |
| #160 | `d6f9ae9642423db1be07051816b2dc2e720065b8` | 39372374431 SUCCESS | 39372374407 SUCCESS | 39372374461 SUCCESS | Artifact 12242666262, ZIP SHA-256 `593a6c0fbdff22d9288b0b95d2c911746e6bdab2ae5ec0b9236471f24b3dc2c9`; PDF SHA-256 `2fd6f04e48dc4df651c96821d4dd7909057ff310d151baef797a01f5b190a5af` | SUCCESS; stacked pe #154 și moștenește fixul pickerului; nu duplică patch-ul |
| #161 | `c30c60794a812991328cb9094d8d1a8ea3b4ff0e` | 39371522926 SUCCESS | 39371522913 SUCCESS | 39371523027 SUCCESS | Native artifact evidence was not freshly re-downloaded for this checkpoint | SUCCESS |
| #162 | `f408eedd1325b0c45b528f960ce6cec93320d66a` | 39371034740 SUCCESS | 39371034683 SUCCESS | 39371034711 SUCCESS | Native evidence and PDF passed; exact artifact digest not refreshed in this checkpoint | SUCCESS |
| #163 | `f67a3bd9e5bd854b3b76c1622ee026d8a564516c` | 39371563027 SUCCESS | 39371563083 SUCCESS | 39371563029 SUCCESS | Native connected/restart/PDF passed; exact artifact digest not refreshed in this checkpoint | SUCCESS |
| #164 | `f1cece1b552cb45a7c8d97fe0a104d124e17e0b5` | 39374035581 SUCCESS | 39374035559 SUCCESS | 39374035607 SUCCESS | Artifact 12243632177, ZIP SHA-256 `b3d6409883b618e2fd771ca95f960c0cfddc3c4e4d3f487bb6002c972c1e197f`; PDF SHA-256 `7e1bc6ba14e274c521f7f0fb02b44a88698829e3fdd63798700836733d208465` | SUCCESS; same-SHA rerun a închis locatorul Craiova 02 |
| #165 | `f40267d9aed6c206eadfb3d95a25aaff3eb329af` | 39377002007 SUCCESS | 39377002272 SUCCESS | 39377002099 SUCCESS | Artifact 12244675348, ZIP SHA-256 `c79556183e4a9805dc2125dabb92ea467f6c418d5e80139294da82a41ab67309`; PDF SHA-256 `f300bb96b3b22e5e21e2eaa65426da54aff89e909889f9ff0c3e7e1458d05526` | SUCCESS |
| #166 | `8dce69c178438e89f2f5916b2f74c0d26dd1c72e` | 39378750766 SUCCESS | 39378750728 SUCCESS | 39378750720 first attempt FAILED in Kotlin plugin marker resolution; retry job 118484493941 passed APK build and is now in connected flow | First failed artifact 12244806628 was diagnostic only, ZIP SHA-256 `02375452a13db76650c2f919ebd6025c26f112ddafeed8cb9fb6239c3cde9b82`; no PDF | IN PROGRESS; no final Native/PDF claim |
| #167 | `19c9d2a84678c87d96169bd40bb1752accf1f4fd` | 39378529344 SUCCESS | 39378529273 SUCCESS | 39378529299 SUCCESS | Artifact 12244761885, ZIP SHA-256 `5748d22b81e6c2504ca8bc0f4796943cf9859c7ced6dc172cb1f8e35559ff400`; PDF SHA-256 `d915557781109b4d1d4249862c530e72d1fb1a4ce38b83d44d06dee007d8e58d` | SUCCESS; 11 rânduri, restart și validarea PDF confirmate |

### Diagnostic curent Native pentru #160

Prima încercare Native pe SHA superseded `32ddacd755ead3bd727c8b2f0e0e1f5fdc717f50` a construit APK-ul, apoi Connected UI nu a găsit `CheckboxListTile` pentru `Craiova 02`; PDF-ul nu a fost produs în acea încercare. Capul curent #160 `d6f9ae9642423db1be07051816b2dc2e720065b8` este stacked pe #154 și moștenește remedierea locatorului/scroll-ului; comparația #154 → #160 păstrează numai extragerea Maps/Waze. Validate, Android și Native sunt toate SUCCESS pe capul curent, inclusiv cold restart și PDF/checksum. Artefactul eșuat `12241726298` (ZIP SHA-256 `1c8bbe6cad848ea2492c4b09a20ff4478c78931dd2c509d4793ac2511c217ed0`) rămâne doar ca dovadă diagnostică istorică. Un rerun suplimentar al vechiului SHA pornit în timpul verificării curente este superseded și nu se folosește pentru certificarea PR-ului.

### Matricea actualizată a celor șase module mari

| Modul | Extrageri existente până la #167 | Responsabilități încă amestecate / următoarea extragere | Dependențe și risc |
|---|---|---|---|
| Home | codec/backup/permisii/sincronizare; politică live-location #163; categorie și allow-policy pentru alerte personale #167 | Lifecycle, listeners/subscriptions, cache, push tokens, GPS, navigare și operații Firestore; următorul pas cere contract de stare înaintea orchestration-ului | Permisiuni/Auth/timer/stream și Firestore; ridicat. Nu muta `canEditTeam` sau scrieri fără teste de autorizare/concurență |
| Expenses | parser bani #138; parser diurne #156; carryover legacy #158 (stacked peste #156); duplicate matcher #162; image compression/fingerprint #166 | UI/dialoguri, OCR/picker, încărcare și salvare, settlement legacy/v2 și PDF; următoarea etapă: contracte pentru pipeline OCR/save și integrare, fără calculator duplicat | #162/#166 sunt siblings cu hunk-uri distincte în `expense_page.dart`/`main.dart`; reconciliere la consolidare. Ledgerul nu este substitut pentru soldul legacy |
| Program/Grafic | save failure #137; route selection #141; work-date selection #148; geocoder #154; ordonare ID-uri graf #165 | editare și lifecycle-ul graficului, START/STOP/pause/restart, optimizare rută și persistență; următorul pas cere characterization înainte de mutarea orchestration-ului | Callback-uri și modele globale, team/date/GPS. #165 sibling pe #137; logică de rută cu risc ridicat |
| Map | geometry cache/point validation/route selection/reverse geocode/badges/schedules/location filters/categories #139–#147; URI #160 (green, stacked pe #154); marker widget #161 | Controller Mapbox/GPS, construirea markerelor, sheet-uri, tap/edit/navigation și lifecycle; următorul pas: contract marker/status/permission, apoi stateful lifecycle | Pluginuri, permisiuni, mounted/dispose, identitate echipă; #160 retry e blocaj curent, risc mediu-ridicat |
| Dashboard | mesaje de salvare #137; eticheta orașului #153; geocoder #154; prezentarea statusului #159 | START/STOP și state orchestration (create/finish/wait/write); următoarea extragere numai după contracte pentru starea și tranzițiile curente | Lock/CAS/idempotency și izolare echipă; scrieri cu risc ridicat, păstrează flows și corrections |
| Rapoarte/PDF | filename normalization; projection Centralizator #157; projection Work Graph #164 | Maparea modelului Centralizator și randarea/layout-ul PDF, calculul/formatările de raport și I/O/download; următorul pas: DTO/projection explicit și comparații text/hash înainte de extragere | Dependențe de record/status/date și sursa de date, risc ridicat de regresie vizuală/financiară |

### Concluzie și blocaje

- #154, #155 și #156 sunt SUCCESS pe SHA-urile exacte de mai sus. Cauza Craiova 03 pentru #154 rămâne locatorul global `TextField` și scroll-ul ambiguu al testului; pickerul a fost restrâns după eticheta câmpului și lista `CustomScrollView`. UI-ul a creat/reîncărcat 11 rânduri și PDF-ul a fost generat și verificat; nu s-a găsit defect PDF separat.
- #160, #165 și #167 sunt complet SUCCESS pe SHA-urile curente. #166 are Validate/Android verde, dar Native/PDF este încă în execuție după eșecul de rezolvare Gradle Kotlin la prima încercare.
- Aceste PR-uri sunt în principal siblings pe baza #137; #158 este stack justificat pe #156. Nu există încă un SHA consolidat care să conțină toate extragerile și să fi trecut CI complet. Importurile din `main.dart` și hunk-urile din `expense_page.dart` trebuie reconcilitate la compunere; nu copia patch-uri între siblings.
- Verificările folosesc emulator Firebase și echipe sintetice; nu certifică datele/proiectul Firebase de producție, hardware GPS sau configurația de distribuție. Nu s-a făcut merge, deploy, signed release ori distribuire APK. `production_ready=false`.

Următorul checkpoint va înlocui stările IN PROGRESS numai după terminarea joburilor, va adăuga digest-urile finale și va valida exact noul HEAD al raportului.
