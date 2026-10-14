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

## MOD-HOME-SYNC-20261013 — separarea celor 5 grupuri de abonări Firestore din HomePage

**Bază:** `main` SHA `377f1fd5e73ae78a0df5cab58b09770c873cd167`, după integrarea PR #17/#18; PR-urile #19–#22 sunt lăsate nemodificate. Documentele obligatorii `ChatGpt`, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, arhitectura Vision și acest audit au fost recitite înainte de lucru.

**Înainte:** `lib/home/home_page.dart` ~95 KB, cu 15 abonări în blocurile de sincronizare de bază. **Acțiune pur structurală:** exact 5 metode (profil propriu, operațiuni, notificări, chat privat/grup, setări UI) — 14.820 caractere sursă, **10** abonări Firestore — sunt mutate textual, fără schimbarea instrucțiunilor, în `lib/home/home_sync_listeners.dart`, ca `extension _HomeSyncListeners on _HomePageState` în aceeași bibliotecă `main.dart`. Celelalte **5** abonări și orchestrarea `_startCoreSync` rămân în `home_page.dart`. Nicio schimbare a filtrării, ordinii, declanșării întreținerii, prelucrării mesajelor, datelor, permisiunilor ori anulării abonărilor în `dispose`.

**Dovadă de mutare:** după eliminarea celor 5 metode din original, reinserarea byte/text-exactă a blocului din noul `part` reconstruiește originalul `home_page.dart` fără modificări. Doar `part` nou și testele au fost schimbate în afara acestei mutări; codul de abonări nu a fost refactorizat semantic. În continuare folosim arhitectura intermediară cu `part of '../main.dart'`, **nu** biblioteci independente.

**Protecții:** testele istorice `test/repository_hygiene_test.py` sunt actualizate să citească metoda mutată și să verifice 15 abonări în total, ordinea de orchestrare, filtrele și erorile. Noul `test/home_sync_listeners_contract_test.py` verifică unicitatea celor 5 implementări, 10 listenere mutate și contractele de colecții, notificare, chat și setări. Testele structurale NU dovedesc comportamentul live; compilarea și testele Flutter în CI sunt obligatorii pentru noua extensie Dart.

**Risc:** extension pe `_HomePageState` poate implica avertismente Dart analyzer în contextul metodelor `State`; compilarea/web build + testele Flutter confirmă siguranța lotului pentru configurațiile CI. Următoarea etapă: separarea progresivă a serviciilor de stare și migrarea graduală de la parts către API-uri independente, fără extinderea accesului Firebase.

**Reguli:** fără modificări Firestore/rules/config/production, billing, deploy, main merge, APK release. Lotul rămâne PR Draft până la raportul CI final; nu declarați validat înainte de verdict.

## MOD-HOME-DIRECTORY-20261013 — audit lot consecutiv

Bază: PR #23 commit `2e4a7312a526908ede4965a87bcb25bd8edcc9ee` (nu `main`), pentru a păstra toate extragerile de abonări. Trei metode de sincronizare admin, definiții și director utilizatori mutate textual, fără editări în interior: 7645 caractere, 5 abonări. După acest lot, cele 15 abonări core se află în două fișiere dedicate (10 anterior + 5 acum), în aceeași bibliotecă prin extensii private. `_startCoreSync` și `dispose` rămân în HomePage. Reconstrucția exactă a sursei confirmă mutarea fără pierderi, dar NU echivalează cu teste funcționale; CI Flutter/Python/Node/Firestore emulator/Functions/web obligatoriu. Fără schimbare business, migrare, producție, Firebase, rules, billing sau deploy.

## MOD-HOME-FINANCIAL-20261013 — extragerea celor patru abonări financiare

**Bază cumulativă:** PR #26 HEAD `bbef8b3492c6d6e868a9726e3cf25fa6caa9af3c`; păstrăm extragerile PR #23 și #26, fără modificarea lor. Codul existent `_startFinancialSync` (2471 caractere, **4** abonări pentru `expenses`, `perDiems`, `finance`, `settlements`) a fost mutat textual în noul `part` `lib/home/home_financial_sync.dart`, extensie pe `_HomePageState`. Fișierul `home_page.dart` se reduce de la 72856 la 70385 caractere. **Reinserarea exactă a blocului reconstituie byte/text-exact versiunea din HEAD PR #26**.

**Invariante:** sfera `*` pentru admin ori drept `viewOtherDecont`, filtrarea obligatorie `teamId` pentru restul, reinițializarea numai la schimbare scope, anularea abonărilor existente înainte de refacere, tratarea scope-ului gol, ordinea celor patru streamuri, sortări și onError neschimbate. Callback-urile din sincronizarea operațiunilor/directorului/definițiilor încă apelează aceeași metodă. `dispose` continuă să anuleze `_financialSubscriptions`.

**Separare contabilă:** cele **15 abonări core** rămân în cele două părți extrase anterior; cele **4 abonări financiare** sunt distincte și nu trebuie însumate greșit. Nu se schimbă algoritmi, plăți, solduri, identificatori, schema Firestore, reguli, permisiuni ori fluxuri reale.

**Teste:** `test/home_financial_sync_contract_test.py` (unicitate, filtre, anulare, număr abonări și contracte). CI standard pentru Flutter, web, Python, Node, Functions și emulator trebuie verificat pe commitul final. Nu pretindem testare autenticată live; acesta rămâne un modul `part of main.dart`, nu o bibliotecă independentă.

**Interdicții:** fără merge în main, Firebase de producție, rules/config, deploy, APK publicat sau billing; Draft PR separat.

## MOD-HOME-FINANCIAL-WRITES-20261013 — separare exclusiv textuală a celor patru scrieri financiare

**Bază:** PR #27 HEAD `ef31e2e1f86ca87468184e81571342e9714d0f74` (cumulativ peste PR #23/#26). Blocul `_saveExpenseDirect`, `_savePerDiemDirect`, `_saveSettlementDirect`, `_saveFinanceDirect` — **6845 caractere** — a fost mutat textual, fără schimbarea niciunei instrucțiuni din metode, din `lib/home/home_page.dart` în `lib/home/home_financial_write_actions.dart`, extensie privată în aceeași bibliotecă Dart. HomePage: 70385 → 63540 caractere; față de `main` inițial: 95.321 → 63540 caractere. **Reconstituirea blocului în poziția inițială reproduce exact sursa din PR #27**.

**Sensibilitate financiară:** `_savePerDiemDirect` conține tranzacția de confirmare/refuz și jurnalul `receiptAudit`. **Nu am schimbat** verificarea Firebase Auth, identitatea beneficiarului/distribuitorului, identificatorii, tratamentul sumelor `parsePerDiemBani`, interdicția confirmării duble, documentul de tranzacție, respingerea datelor invalide sau permisiunile `canEditTeam`/`viewOwnDecont`. Testul nou `test/home_financial_write_actions_contract_test.py` verifică prezența unică a metodelor și contractele de securitate/tranzacție/colecții; testul de igienă vechi este adaptat să caute metoda mutată. Acestea sunt contracte structurale, NU teste de tranzacții pe producție.

**CI:** pentru HEAD final sunt obligatorii Flutter unit/widget + web build, Python suite/audit, Node, Functions și emulator Firestore. Rezultatul se consemnează numai după rulare. `part of main.dart` rămâne arhitectură intermediară; modularizarea completă nu este declarată gata.

**Restricții:** fără merge în main, deploy, modificări date/rules/config Firebase producție, migrare, APK release, schimbare versiune sau billing. PR Draft separat.

## CONSOLIDARE-PR-20261013 — inventar, alternative duplicate și consolidare în PR #28

**Verificare GitHub pe 13.10.2026:** `main` SHA `377f1fd5e73ae78a0df5cab58b09770c873cd167`. PR #17/#18 sunt merged, însă PR #15, #19–#28 (cu excepția #17/#18) rămân separate și open/Draft, fiecare cu propriul rol. Nu se confundă buildul web verde cu versiunea live.

**Lanțuri suprapuse** (toate au verificări CI pe HEAD-urile proprii):
- PR #23 → **#24 → #25**: directoare, definiții, audit, apoi 4 abonări financiare;
- PR #23 → **#26 → #27 → #28**: aceleași directoare, definiții și audit, apoi 4 abonări financiare, PLUS cele 4 operațiuni de scriere financiară din #28.
- Comparație textuală între corpurile metodelor (fără învelișul extensiei): cele trei metode din #24 versus #26 au **7.644 caractere identice**; `_startFinancialSync` din #25 versus #27 are **2.470 caractere identice**. Nu se combină ambele `part`-uri, fiindcă ar dubla exact semnăturile private, ar crea erori Dart și ar adăuga/confunda abonări.
- Calea canonică aleasă: **PR #28**, cumulativ cu #23/#26/#27. Verificările suplimentare utile din #24/#25 pentru vizibilitatea membrilor, seed, convertoarele financiare și ordinea colecțiilor sunt integrate **în testele existente** pe #28, fără duplicarea claselor de teste sau a modulelor alternate. Nu se creează fișierele `home_catalog_sync.dart` din varianta paralelă.
- **PR #22**: cele cinci teste `lib/finance/per_diem_ledger_test.dart` nu erau descoperite de `flutter test test/`; testele sale mutate identic în `test/per_diem_ledger_edge_cases_test.dart` și gardul `test/ledger_test_discovery_test.py` sunt aduse în PR #28, cu ștergerea **exclusiv a copiei vechi a fișierului de TEST**, nu a codului `lib/finance/per_diem_ledger.dart`.

**Reguli:** acest checkpoint nu modifică logica aplicației, datele Firebase, plăți sau rules/config/chei/deploy; schimbări de cod doar în testele adăugate/întărite și eliminarea fișierului Dart de test mutat. CI standard pe commit nou este obligatoriu înainte de concluzie. Nu facem merge ori deploy prin această consolidare. PR #15 (diurnă manager) necesită audit separat și nu este automat considerat redundant; #19 (Vision), #20 (PDF), #21 (integrare) rămân independente, fără activare în producție. PR-urile #22/#24/#25/#23/#26/#27 rămân **istoric verificabil**; evitați integrarea lor separată după consolidare, iar închiderea lor se documentează explicit când PR canonic este verificat.

**Rămâne:** majoritatea `lib/home/home_page.dart` este încă în `part`, nu într-o bibliotecă independentă; ExpensePage, ProgramPage, MapPage, DashboardPage sunt mari; `badge_v2`, restore, OCR sume, GPS/background și DND sunt riscuri nerezolvate de această mutare. 12 grupuri de asseturi/config identice cunoscute nu sunt șterse automat.

## MOD-HOME-OPERATION-WRITES-20261013 — acțiuni de locație, program și execuții separate

**Bază:** commit consolidat PR #28 `570765bfbe989f652af14dff0b441b33e0ba74bb`, fără un PR nou. Exact patru metode `_deleteLocationDirect`, `_saveLocationDirect`, `_saveScheduleDirect`, `_saveRecordDirect` au fost mutate textual din `lib/home/home_page.dart` în `lib/home/home_operational_write_actions.dart` ca extensie privată în aceeași bibliotecă Dart, fără schimbarea vreunei instrucțiuni din corpurile metodelor. Bloc mutat: 3665 caractere; HomePage: 63540 → 59875 caractere. Reintroducerea exactă a blocului reconstruieste textul anterior de pe PR #28.

**Invariante:** admin exclusiv pentru ștergere/salvare locații, `editProgram` și `canEditTeam` pentru grafice, `editProgram` sau `editCentralizer` plus `canEditTeam` pentru execuții; aceleași documente Firestore, `SetOptions(merge:true)`, `Learning` cu datele originale, actualizările cache și `setState`. Nicio schimbare în OCR, plăți, diurne, permisiuni Firebase ori mecanisme de securitate server-side. În special, această separare nu rezolvă probleme raportate anterior în `Learning`/GPS/OCR; acestea cer analiză ulterioară.

**Validări:** test nou `test/home_operational_write_actions_contract_test.py` pentru integritate structurală a celor 4 metode, permisiuni, colecții, Learning/cache/UI; CI pe HEAD nou pentru Python, Flutter unit/web, Node, Functions și emulator Firestore. Contractele statice nu substituie verificările autentificate pe dispozitiv. Acest lot păstrează `part of main.dart` ca etapă intermediară, nu face separare într-o bibliotecă independentă.

**Livrare:** PR #28 rămâne Open/Draft, fără merge în main, deploy, date/rules/config producție, migrare financiară sau APK release. PR #15/#19/#20/#21 neatinse.

## MOD-HOME-AUDIT-PERSISTENCE-20261013 — audit acțiuni și persistență batch

**Bază:** PR #28 commit `d028686af286bc9b11bc5dcf284b44bb84bb284d`. Două metode existente, `_writeAuditRemote` și `_persistCoreData`, sunt mutate fără editări interne în `lib/home/home_audit_persistence.dart`, ca `extension _HomeAuditPersistence on _HomePageState` din aceeași bibliotecă Dart `main.dart`. Bloc mutat: 2485 caractere. `lib/home/home_page.dart`: 59875 → 57390 caractere. Reintroducerea blocului extras la poziția originală recreează exact sursa dinaintea acestui lot.

**Invariante de risc:** `dispose` și anularea abonărilor rămân în HomePage, împreună cu `me`, `isAdmin`, `canEditTeam`, `userName`, `log`. Auditul și jurnalul Learning nu sunt schimbate, inclusiv capturarea existentă `catch (_)`; nu se pretinde că auditul este acum infailibil. `_persistCoreData` rămâne admin-only, diferențializează cacheurile și face `batch.commit` înainte de actualizarea celor 4 cache-uri în memorie. Nu s-au schimbat colecțiile, autorizațiile, paginarea, opțiunile de merge sau tratamentul eșecurilor. Testul `test/home_audit_persistence_contract_test.py` apără contractele structurale, nu execută date live.

**Teste:** CI obișnuit Flutter unit/widget și web release, Python contracte, Node, Functions și Firestore emulator pe HEAD nou; rezultatul nu poate fi anticipat. Persistarea batch >500 documente și `catch (_)` din audit reprezintă eventuale riscuri de funcționalitate existente, nu se schimbă aici fără test și acord ulterior.

**Restricții:** PR #28 rămâne Draft, fără merge în `main`, deploy, Firebase live/rules/config, plăți, versionare sau APK.

## MOD-HOME-GPS-PUSH-NAVIGATION-20261013 — PR #28

Bază exactă: `c5fb50026daaa9d15d6af7381fe9c6226c52f583`, CI anterior run 38370622154 completed/success.
Au fost citite documentele obligatorii ChatGpt, registrul de reguli și arhitectura Vision; ordine păstrată: curățare, contracte, apoi Vision/Error Log.

Extragere textuală a **27 metode** în patru extensii private din aceeași bibliotecă:
- `home_push_notifications.dart`: 6 metode, popup, chat alert, token FCM și inițializare/permisiuni; 7.872 caractere.
- `home_live_location.dart`: 5 metode, stream nativ/adaptiv, reverse geocoding, throttling și salvarea locației; 10.110 caractere.
- `home_work_automation.dart`: 8 metode, selecție înregistrări, geofencing, confirmare START/așteptare și închidere legacy; 12.422 caractere.
- `home_navigation.dart`: 8 metode, unread chat, profil/director/notificări/despre/admin; 4.608 caractere.
HomePage **57.390 → 22.378 caractere**. Reinserarea tuturor blocurilor în pozițiile originale reconstruiește EXACT sursa de bază. Init/dispose/build, câmpurile și orchestrarea rămân în clasa State. Nu s-au schimbat instrucțiuni, praguri GPS, colecții, roluri, payloaduri, ordinea async sau fluxul financiar. Cele două listener-e FCM rămân în `_coreSubscriptions` și sunt anulate prin dispose; cele 15 listener-e Firestore core + 4 financiare sunt distincte.

Validare locală: **134 teste Python PASS, 3 Node PASS, syntax Functions PASS, git diff --check PASS**. 6 contracte noi pentru unicitate/lifecycle, proprietar token/vizibilitate, GPS, ordinea scriere→detecție, confirmare umană și unread/mark-read. Flutter/Dart nu sunt instalate local: Flutter test/web release, npm ci Functions și emulator Firestore demo se verifică în CI pe SHA nou. Rezultatul final și run vor fi înscrise în descrierea PR fără a folosi verdele vechi.

Riscuri existente reconfirmate, **necorectate pentru a păstra comportamentul**: START folosește verificare locală înainte de scriere, fără garanție contra concurenței; detecția GPS vine după scrierea liveLocations și nu rulează dacă aceasta eșuează; închiderea legacy consideră și Refuzată drept rezolvată, contrar specificației viitoare; payload GPS conține fotografia; delayed restart GPS nu are gard mounted. Sunt puncte de analiză/remediere ulterioară cu contracte, nu incidente de producție dovedite.

Modularizarea integrală **NU este finalizată**: `part` păstrează cuplarea; Home mai conține starea/orchestrarea/UI, iar Expense/Program/Map/Dashboard, PDF și modele cer continuare. Bibliotecile independente și testele funcționale autentificate/Android/background rămân de făcut. Nu se șterg assets, cacheuri sau module v2 pe presupuneri. PR #28 rămâne Draft; PR #15/#19/#20/#21 neatinse. Fără merge, deploy, Firebase live/rules/config, migrare, billing, versiune ori APK publicat.

## MOD-SCREEN-ACTIONS-20261013 — continuare cumulativă PR #28

Bază: `ded22405ba3d542e9f264eab11fbdf36ca22f411`, **CI run 38372097984 5/5 completed/success** verificat înainte de acest lot.
Separare textuală a **91 metode în 8 module**, fără editări interne. Verificare independentă: fiecare bloc din extensii există o singură dată în sursa Git de bază, iar eliminarea blocurilor reproduce EXACT fiecare pagină actuală. Pentru Dashboard s-au concatenat două blocuri separate din aceeași clasă. State/getterele/UI/override rămân în pagini, callbackurile neschimbate.

| Pagină | Caractere înainte → după | Module noi |
|---|---:|---|
| Decont | 76.911 → 19.722 | expense_settlement_actions, expense_per_diem_actions, expense_document_actions |
| Program | 66.377 → 17.370 | program_route_learning_actions, program_graph_actions |
| Hartă | 55.293 → 31.948 | map_verified_import_actions, map_location_actions |
| Dashboard | 39.856 → 24.344 | dashboard_work_actions |

Total mutat în acest lot: **145.053 caractere**; cumulativ în sesiune: **180.065 caractere / 118 metode / 12 module noi**. Include OCR/manual/deduplicare/documente/PDF, distribuiri/confirmări/refuzuri/contestații/suplimentări de diurnă, deplasări/încasări/calcule generale, Learning rutare/transfer zile, START/STOP/pauză/grafic/export, import GPS/poziționare și execuții dashboard. Nicio schimbare de praguri, drepturi, sume, colecții sau ordine async. Avansul diurnei, zero ca refuz reversibil, rollback confirmare, cele două tranzacții de contestație și Undo IEȘI sunt literal păstrate.

**Validare locală:** 141 Python PASS (7 contracte noi), 3 Node PASS, syntax Functions/diff-check PASS. Nouă teste vechi căutau codul în paginile de origine; au fost adaptate la sursa nouă fără slăbirea aserțiunilor. Flutter/Dart lipsesc local; Flutter test/web release, Functions dependencies și Firestore emulator demo se verifică în CI pe HEAD final. Rezultatul final SHA/run se înscrie în descrierea PR după terminare.

**Riscuri existente reconfirmate, necorectate:** transferul zilelor/START/crearea graficelor au salvări succesive și pot rămâne parțiale la eroare; importul GPS mută obiectele locale înainte de batch.commit; unele editoare modifică obiecte înainte de salvare; controller-ele dialogului OCR nu au dispose după animație; ascunderea UI admin nu este autorizare server-side. Geocoderele au output/fallback diferite și nu sunt unificate orbește. Nu se deduc incidente live din analiza statică.

**Inventar:** 113 fișiere Dart / 89 parts; nicio clasă duplicată, niciun part lipsă/neconectat; audit git păstrează 12 grupuri de assets/configuri identice cunoscute. `part of main.dart` rămâne tranzitoriu. Modularizarea integrală **NU este finalizată**: biblioteci independente, modele/PDF, starea/prezentarea paginilor și Map rendering/GPS, candidatele de cod mort și parsarea receivedEntries rămân de analizat. Cache-urile numai scrise nu sunt eliminate deoarece evaluarea `_encoded` poate influența erorile. Testele structurale/web nu înlocuiesc testele autentificate și fizice Android/background. Vision/Error Log rămâne prima implementare nouă ulterioară, fără activare aici.

PR #28 Draft/Open; PR #15/#19/#20/#21 neatinse. Fără merge, deploy, date/rules/config Firebase producție, migrare, billing, versiune ori APK publicat.

## Addendum 2026-10-13 — extragere catalog Home

PR #28 continuat de la HEAD `a01e8c98e48b023e325012deabb3735290563895`. `home/home_location_seed.dart` a fost înlocuit de `home/seed_operational_locations.dart`, bibliotecă independentă care importă numai modelele și enumurile. Wrapperul `_seedLocations()` și ordinea de inițializare au rămas. SHA-256-ul literalului catalogului Magic/Million este neschimbat: `82611ffb8f0f605a17e196f0196765dff3f0c923117997cdf34dc9048dbc9eb1`.

Nu s-a forțat izolarea `pdf_reports.dart`: PR #28 are download PDF `Future<void>`, PR #20 are `Future<bool>` anulabil pe nativ și share separat. Aplatizarea contractului ar pierde anularea; grafica depinde încă de helpers private din main, inclusiv unul comun cu JPEG. Generatorii, fișierele PV Magic/Million, Documents și fluxurile de download/share rămân neatinse. Hash Magic verificat cu manifestul protejat: `eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b`; Million există doar în PR #20, hash `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`.

Inventar regenerat: 133 fișiere Dart, 78 parts și 55 biblioteci; fără missing/orphan/duplicate/cicluri import-export. 151 teste Python, 1 Node, syntax Functions și diff-check PASS local. CI run `38388145518` pe `f6fe0370dd66a6694c172a0ad854939a4b8e57d8`: 5/5 SUCCESS, incluzând cele două teste Flutter noi și web build. Modularizarea completă rămâne nefinalizată.

Continuare structurală: `admin/admin_navigation_catalog.dart` devine bibliotecă Material independentă de main; wrapper-ele private cu semnăturile vechi rămân în main pentru callsite-urile Admin/dashboard. Catalogul nu accesează stare/Firebase. Test Dart acoperă toate 17 intrările icon/grup/asset; testul static cere adapterele și importul explicit. Inventarul actualizat: 134 Dart / 77 parts / 57 biblioteci; zero ținte lipsă/orfani/duplicate/cicluri. Local 151 Python, 1 Node, `node --check`, audit și diff-check PASS. CI run `38388935786` pe `ffb35c16b2c1d41e9fce42b1e9255159609b58c4`: 5/5 SUCCESS. Continuăm numai cu un lot structural independent.

PR #20 rămâne separat. Download anulabil (`Future<bool>`) și share nu se aplatizează la contractul PDF #28 (`Future<void>`); rapoartele și PV-urile rămân protejate. PR #29 și regulile/datele sale nu se modifică.

CI pentru commitul documentar de după Admin: run `38389244180`, 5/5 SUCCESS. `ui/icon_badge_catalog.dart` a fost apoi desprins ca bibliotecă independentă Material; main importă și reexportă același API public. Corpul sursă, fără directiva part, este SHA-256 identic cu baza: `06a837cfd5d39a547e65d8a69a0f2a7097515d41c371da10513b8b53f81fcefd`. Teste Dart directe verifică icon/badge/asset mappings și compatibilitatea reexportului; testul Python fixează hashul corpului.

Inventar curent: 135 fișiere Dart / 76 parts / 59 biblioteci, fără lipsuri/orfani/duplicate/cicluri. Local 151 Python PASS, 1 Node PASS, syntax Functions, toate cele 116 hashuri protejate și diff-check PASS. CI-ul lotului curent urmează.

### Corecție CI — helper privat folosit din part

Run `38389669780` a încheiat 4/5: Flutter a eșuat la compilare deoarece `interactive_member_badges.dart` (part of main) nu mai putea vedea `_badgeGraphic`, privat în biblioteca extrasă. 52 teste au trecut; 5 fișiere de test au fost blocate de eroarea de compilare, nu de aserțiuni. Celelalte patru joburi au trecut. Corecție: `badgeGraphic` public în biblioteca nouă și wrapper privat `_badgeGraphic` în main cu aceeași semnătură. SHA al corpului normalizează numele și rămâne identic. Commit corectiv `b503f0ffbd44d0660e71aee360319d61f70f8466`, CI run `38390010291`, 5/5 SUCCESS.

Următorul lot: componenta `ui/empty_state.dart` este desprinsă cu import Material explicit și wrapper `_Empty` în main, păstrând callsite-urile. Corpul widgetului, după normalizarea numelui clasei, rămâne SHA-256 `2be8dc91332ee092c2c7858b6c9f36cf40f8efe2377190996b549d11fcba6c92`. Test Dart verifică renderul direct; inventar nou 136 Dart / 75 parts / 61 biblioteci, zero missing/orphan/duplicate/cicluri. Teste locale și hashurile PDF protejate PASS; CI pentru acest lot încă trebuie verificat.

CI run `38390449115` pe `9ba22143a734d83ac1b9d410e88b2079f577c946`: 4/5 SUCCESS. Flutter a eșuat la compilare pentru că `EmptyState` avea constructorul vechi `const _Empty`; 52 teste au trecut, 6 fișiere nu s-au putut compila, celelalte joburi au trecut. Constructor redenumit la `EmptyState`; wrapper-ul privat main neschimbat. Hashul sursei normalizează atât clasa cât și constructorul. Corecția `f95233dbdc50b44219306d9fcc18e1da25a0ade9`, run `38390758123`, a trecut 5/5.

Lotul următor izolează `MoneyCard` (titlu, valoare și callback) din `summary_cards.dart` în `ui/money_card.dart`, cu wrapper privat main păstrat. Corpul original după normalizarea numelui este SHA-256 `e7326bf0fe3d3798ec246f094e6d53f4221abc08a7942b94b1438b80ad77c16b`. Separarea nu schimbă sau mută formulele din Expense; testul direct verifică formatarea și callbackul. Inventar 138 Dart / 75 parts / 63 biblioteci; fără anomalii import-export. Local 151 Python/1 Node și cele 116 hashuri protejate PASS. CI pentru `48eda76f705f5b64cafc01ad955d77fab23c9859`, run `38391208890`: **5/5 SUCCESS** (Firestore emulator, Node, Functions, Python/security, Flutter tests și web build).

## MOD-SCREEN-ACTIONS-CI-FIX-20261013

CI run 38372790209 pe `23d88a4cad17eb21ae9e3af34e4023641a796928`: 4 joburi SUCCESS, Flutter FAILURE la compilarea widget_test, înainte de build web. Cauză exactă: în extensia Decont, `const DropdownMenuItem(value: _legacySettlementKey, ...)` nu poate rezolva implicit constanta statică a State în context const. Corecție strictă: `value: _ExpensePageState._legacySettlementKey`; aceeași valoare/instanță const/comportament, fără schimbare business. Nu eliminăm const și nu schimbăm identificatorul legacy.
Contractul pentru module verifică acum explicit pagina corectă (MapPage, nu alt *_page.dart din același director), unicitatea metodelor în toate extensiile aceluiași State și referința statică calificată. Testele Python 141 PASS; Flutter/web trebuie reverificate în CI pe noul SHA. Dovada textuală din lotul inițial rămâne validă pentru mutare; singura ajustare ulterior este această calificare de simbol static, documentată explicit. Nicio altă logică modificată; fără merge/deploy/Firebase live/APK.

## MOD-MODEL-LIBRARIES-1-20261013 — biblioteci cu importuri/exporturi explicite

PR #28, bază `0866bb8`, CI anterior 38373059059 5/5 SUCCESS. Cele cinci fișiere models enums/status/categorii/defaults/labels devin biblioteci independente de main, cu dependențe explicite și re-export în main pentru compatibilitatea callerilor. Corpurile sunt integral identice după înlocuirea directivelor; nicio regulă de business/financiar schimbată. Inventar lib/test complet în `docs/DART_DEPENDENCIES_2026-10-13.json`, script read-only `scripts/audit_dart_dependencies.py`; 89 → 84 parts, fără import/export cycles, ținte lipsă ori declarații duplicate în aceeași bibliotecă. Modelele cu Color/IconData păstrează Material, nu sunt încă un domain layer fără Flutter.

145 Python + 3 Node + syntax/diff-check PASS local; 5 teste Dart noi pentru acces direct și identitatea re-exportată/defaulturi/badge/culori/permisiuni. Flutter/web/emulator/Functions dependencies se verifică în CI pe SHA nou înainte de următorul lot. Raport complet și audit PDF: `docs/MODULARIZARE_BIBLIOTECI_DART_2026-10-13.md`. PDF reports/helpers identice cu PR #20 (blobs comparate); fluxurile Magic/Million/download/asseturi rămân intacte. PR #29 rămâne separat: fișiere OCR/teste/emulator/doc și reguli financiare neatinse, fără integrare.

Urmează extragerea publicului graphDefaultName înainte de modele centrale, apoi date/Learning. Singletonul privat Mapbox și utilitarele PDF private blochează conversia izolată a rutării/PDF; nu se forțează. Cacheuri/receivedEntries/asseturi doar analizate, nicio ștergere pe presupuneri. Fără merge/deploy/Firebase live/rules/config/billing/APK. Modularizarea completă nu este terminată; rezultatul CI final este consemnat în descrierea PR.

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

Bază: HEAD PR #28 `e37552a5b90d4f967e5db8cdf77c61120998e2d7` (CI 5/5 success, run `38466275696`). `section_visual_helpers.dart` este convertit din part în bibliotecă Material independentă; dependența `AppSettings` este explicită. Main importă/re-exportă API-urile publice și păstrează `_plainBackgroundColor` ca wrapper privat pentru callerii din părți. Corpul funcțiilor este identic după redenumirea `_plainBackgroundColor` → `plainBackgroundColor`; mapările, mesajele, durata și culorile rămân neschimbate.

Testele directe acoperă accent/fallback, setările de fundal/light-dark și SnackBar succes/eroare. Python: 154 teste PASS; Node: 3/3 PASS; scriptul de audit Dart: 151 fișiere, 68 parts, 83 biblioteci, fără targeturi lipsă/orfani/duplicate/cicluri; integritatea blocului Mapbox și fișierele protejate trec. `git diff --check` PASS. Flutter/Dart lipsesc local; CI run [38474876381](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38474876381), commit `c992eb8e35561e47c585cc8d40e093d0b3dd6c19`: **5/5 SUCCESS**, inclusiv Flutter/widget și build web.

Nicio modificare în state/branding global, PDF/download/share, Mapbox, OCR, PR #29, diurne/finanțe, reguli sau date Firebase. Următorul pas numai după CI verde: audit read-only al următorului widget/helper UI cu dependențe explicite; PageShell și tema rădăcină rămân blocate de brandingul global mutabil.


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


## MOD-LOGIN-INPUT-HELPERS-20261014 — lot 8

HomeDefinitionSources validat pe 750f4cfae4178ab471239f0ca09e178f59e255fe / CI 38487396034 **5/5 SUCCESS**. Codul inițial b8e2e5c3436d186554f4cbae8b19e5eafa0c419d a avut CI 38487194974 cu Flutter failure (140 pass/1 fail): testul compara cu un nou controller.stream, nu instanța capturată în fake. Corecții numai fixture: 70ed3924c05624771d555812ad50c7102c86f9a2 (broadcast pentru close fără listener), apoi 750f4cf (identitate cu streamul capturat). Nicio modificare runtime pentru aceste remedieri. Nu s-a avansat la alt lot înainte de validarea finală.

Friendly error și normalizePhone sunt acum funcții independente în login_input_helpers; wrapper-ele private rămân în LoginPage. Corpurile sunt textual păstrate după exportul numelor. Teste directe pentru toate cele 7 coduri, fallback SDK inclusiv mesaj gol/null, excepții non-auth și normalizare ASCII fără schimbarea prefixelor. Nu este sanitizare Vision sau politică nouă de telefon/parolă. Local 155 Python, 3 Node și equivalence/diff/inventar PASS; Dart/Flutter numai CI. Urmează CI pe SHA-ul lotului, apoi checkpoint validat pentru reluare cu fixture-uri Home mai ample. Restricțiile existente se păstrează.


## MOD-INSTALL-FLOWS-LIBRARY-20261014 — lot 9

Lot 8 helpers login b4727ec886425ffbe4b4e3577738c9622c9c43e7 / CI 38487808200 **5/5 SUCCESS**, inventar 173/60/113. Dialogurile Android/Apple devin bibliotecă independentă cu Flutter, AppSettings și helper UI explicite. Main păstrează wrapper-ele private și callerii, renunță la part și importă biblioteca cu alias. Launcher opțional tipizat ExternalUrlLauncher, default cu același launchUrl externalApplication. Texte, trim/Uri.tryParse, dialog/confirmare, mounted și tratarea rezultatului/erorilor sunt păstrate. Nicio nouă politică de URL și nicio descărcare/publicare APK efectuată.

Teste widget fără launcher real: cancel fără apel, URL gol/invalid, URI trim și apel unic/false, rezultat întârziat după dispose, excepție fără retry și instrucțiuni Apple. Echivalență textuală după export și substituție launcher PASS. Local 155 Python și diff/inventar PASS; CI pe SHA de lot urmează înainte de checkpoint final. Contractele #20, ramurile independente și producția rămân protejate.


## CHECKPOINT-LOGIN-HOME-INSTALL-VALIDATED-20261014 — reluare PR #28

Bază reluare 0b6e315585037281adb35ed7f1d93ea6556c0ae5 / CI 38485021337 deja 5/5; remote/local au coincis, checkout curat. Cele patru loturi anterioare nu au fost repetate. În această continuare s-au terminat **cinci loturi structurale**, validate înainte de următoarea etapă:

| Lot | Commit de cod / final validat | CI final | Rezultat |
|---|---|---|---|
| 5. LoginAliasResolver, HTTP injectat | f347625f2eb1ebd5592557b2dd9ca6374d27d80d | 38486333669 | 5/5 SUCCESS |
| 6. LoginActions / widget DI | a04a0ba4c044da9a7781589144ae971fa6cbef5c | 38486724314 | 5/5 SUCCESS |
| 7. HomeDefinitionSources | b8e2e5c3436d186554f4cbae8b19e5eafa0c419d; final 750f4cfae4178ab471239f0ca09e178f59e255fe | 38487396034 | 5/5 SUCCESS |
| 8. Helpers login | b4727ec886425ffbe4b4e3577738c9622c9c43e7 | 38487808200 | 5/5 SUCCESS |
| 9. Dialoguri install, launcher explicit | 3d22dc3a709ae2dc88c0c56c80da769cd06b112e | 38488238685 | 5/5 SUCCESS |

Home a necesitat două corecții numai de fixture: 70ed3924c05624771d555812ad50c7102c86f9a2 (broadcast pentru close fără listener), 750f4cf (comparație cu streamul capturat). CI 38487194974: failure Flutter (140 pass / 1 fail), celelalte patru joburi success. Run 38487314041: cancelled prin concurrency la commitul corectiv; nu a fost re-așteptat. Rezultatul relevant este 38487396034, complet verde. Aceste remedieri nu schimbă aplicația.

Testele noi folosesc exclusiv date sintetice, HTTP/SDK fake, streamuri locale și launcher injectat. Acoperire: alias request/bypass/timeout/late completion/error; validare/login/reset/creare pending/eroare profile/dispose LoginPage; surse globale Home lazy/query/metadata/ordine/error/reconnect/cancel fără replay sau listener nou; fallbackuri mesaje/telefon; dialoguri confirm/cancel/URL/dispose/error/Apple. Testele Home sunt de port, nu end-to-end Home/GPS/FCM/finanțe. Nu declarăm sesiunea Firebase reală ori token expiry live testate. Flutter/Dart lipsesc local; CI verifică unit/widget, domain Dart fără engine și build web împreună cu celelalte patru joburi. Local 155 Python + 3 Node PASS, Functions syntax și echivalență textuală PASS.

Inventar final regenerat: **174 Dart (129 lib, 44 test, 1 script), 59 parts, 115 biblioteci totale; 70 biblioteci independente în lib**. Fără ținte lipsă, parts orfane, duplicate în aceeași bibliotecă sau cicluri detectate. Regenerare comparată byte-identic cu snapshotul. Inventarul lexical nu demonstrează cod mort. Nicio eliminare de cod prin presupunere.

Verificare protecție: zero diff față de 0b6e315 în finance, reports/PDF/documents/download, OCR, map/Mapbox, assets, Functions, workflows, pubspec și rules/config/teste Firestore. Main rămâne 377f1fd5e73ae78a0df5cab58b09770c873cd167. PR #19 d4da2872a566eba258e82b8597c023e03ceb9b56, #20 8ae220b41b5e9c1648151606f9443ba8fa68a90a, #21 d18b2523a31ead7eb65a04fe92a21276a4155c97 și #29 545e0202755a8ee86a7b3406adccd469aac84f9e: HEAD-uri verificate neschimbate. GitHub connector publică numai #28 cu expected HEAD lease; arborii locali/remoti sunt comparați înainte de sincronizare. PR rămâne Draft/Open. Fără merge/deploy/APK publicat/Firebase live/rules/config/billing/migrări/versiune nouă.

### Riscuri rămase și pasul exact de reluare

1. **Fereastra AuthGate la schimbare UID:** _handleAuthChange actualizează _user, iar _listenProfile schimbă _profileUid și anulează streamul vechi, dar nu golește imediat _profile și nu reconstruiește imediat Home. Profilul/Home anterior poate rămâne până la noul snapshot. ValueKey(profile.uid) izolează starea numai când se primește profilul nou. Constatare din cod, NU confirmare de scurgere live; testul existent UID validează rezultatul după profilul nou și ignorarea vechilor evenimente, nu intervalul anterior. Este comportament preexistent, nemodificat de loturile curente. Necesită fixture dedicat și decizie de remediere comportamentală/securitate, fără corecție implicită aici.
2. Home financial: cancel nu este awaited, callbacks nu verifică scope/generație; cache-uri/priming se pot muta înainte de mounted. Nu presupunem că SDK livrează evenimente după cancel. Fixture-urile viitoare trebuie să caracterizeze evenimente întârziate și separarea UID/team/rol fără a modifica drepturile ori numărul citirilor/scrierilor.
3. GPS/FCM init async poate continua după dispose; post-frame theme callback, token ownership și cache/settings partajate necesită teste specifice. Nu muta starea/abonările financiare sau identity-sensitive înainte de izolarea acestor efecte.
4. Urmează fixture-uri Home complete pentru restul surselor (own profile, director, operations, notifications/chat/settings/audit), apoi porturi limitate cu cancel și teste UID/reconnect/dispose. Alternativ sigur: LoginPageView separată de controllers/state, navigare UI independentă, Dashboard/Program helpers după analiză; nu forța monolitul și nu urmări zero parts.
5. Auditul diferențial complet NU este încheiat: modularizarea rămâne deschisă. Ulterior clasifică regulile existente (aprobat+implementat / aprobat+neimplementat / parțial / clarificare tehnică / decizie nouă), folosind registrul și Issue #30 fără reaprobare generală. Prima funcționalitate nouă rămâne Vision/Error Log/Diagnostics pe PR dedicat, reutilizând #19/#21; în #28 nu apar funcții Vision noi. Contractele #20 și diagnosticul #29 se păstrează separat.

Acest checkpoint adaugă doar documentație, inventarul regenerat și eliminarea unei linii goale EOF din helperul login. Codul funcțional este validat la 3d22dc3; CI complet se verifică și pentru commitul checkpointului înainte de raportul final. La reluare verifică HEAD-ul GitHub și acest CI, fără repetarea loturilor/rulărilor deja încheiate. Descrierea PR conține SHA/run exact ale checkpointului final; checkoutul trebuie să fie curat. Creditele și durata totală a sesiunii nu sunt disponibile ca măsurători verificabile.


## MOD-AUTH-IDENTITY-CHARACTERIZATION-20261014 — lot 10

Reluare GitHub/local a5892dbb / CI 38488631152 deja 5/5, checkout curat. AuthGate activePageBuilder opțional permite fixture UI cu același key/profile; default HomePage și state machine sunt păstrate. Fixture auth comun și 4 teste noi caracterizează explicit profil A înainte de B/eroare B, active page/tab, route A peste B, comutări A-B-C/cancel/late events. Raport P1/cauză/impact/soluție propusă în docs/AUDIT_IDENTITATE_LIFECYCLE_2026-10-14.md. Verdele testelor KNOWN DEFECT nu înseamnă izolare corectă; CI pe SHA urmează. Corecția UID/Navigator este funcțională/de securitate și necesită aprobare expresă pe PR separat, nu este aplicată în #28. Urmează Home fixtures și/sau LoginPageView în loturi structurale validate. Restricțiile și ramurile independente rămân integrale.


## MOD-HOME-LIFECYCLE-FIXTURE-20261014 — lot 11

AuthGate lot 10 validat: dee55c97690fe06fcd286541d390f466457cdc93 / CI 38492063377 **5/5 SUCCESS** (154 Flutter). Inițial 93da9d6 / 38491865687: 153 pass/1 fail numai din ordinea Flutter mount B înainte de dispose A; fixture corectat, verificările defectelor păstrate. P1 UID/profile/Navigator confirmate în harness; necesită aprobare de remediere funcțională separată, nu sunt reparate în #28.

HomePage primește syncFirestore opțional și HomePlatformEffects (startLocation/initializePush), cu fallbackurile originale. Numai selecția DB core/financial și apelarea efectelor startup se adaptează; query-uri/condiții/cache-uri/ordinea/cancel și logica financiară rămân identice. Fixture Firestore local strict înregistrează fiecare listen/cancel și respinge operații neașteptate. FixtureHomePage folosește State-ul real Home prin createState moștenit; numai element.build este înlocuit cu SizedBox, pentru a nu porni I/O Dashboard/Documents. Nu este test complet UI/Android/live Firebase.

Patru scenarii noi: 14 abonări member în ordinea exactă înainte de efecte, cancel/dispose; toate grupurile core member + profil/chat/notificări/settings și reconectare/error fără noi abonări; scope team financiar 4 cancel/clear/late events/dedup fără scrieri; AuthGate cu State Home real A păstrat în tranziție și B nou după snapshot. Audit admin/maintenance/seed/GPS/FCM hardware încă necesită fixture-uri distincte: nu se suprimă ori mută aceste efecte nesigure. Cache-urile private nu sunt expuse sau modificate. CI pe SHA lot urmează; înainte de verde nu se avansează. Urmează porturi read-only limitate ori LoginPageView.


## MOD-LOGIN-PAGE-VIEW-20261014 — lot 12

Home lot 11: 28aa0504ebc6b1d9c406eacbd405f41190c192d7 / CI 38492570449 **5/5 SUCCESS**, inclusiv cele 4 fixture-uri State Home. În fixture, State-ul real A/UID/cache/listener users/A rămâne activ până la profil B; defectul P1 este confirmat dincolo de probe-ul UI. Cancel/reconnect/team scope funcționează în scenariile simulate fără noi listeners. Admin/maintenance/hardware și paginile UI reale nu sunt certificate.

LoginPageView este bibliotecă Flutter independentă cu logo/install/backdrop, callbacks și controllers explicite; LoginFormControllers împrumută cele 6 instanțe, fără a le crea/dispose. Constructorul LoginPage și State-ul submit/reset/validation/actions/dispose rămân identice. Body visual verificat textual după substituția parametrilor/callbackurilor; textele, câmpurile, autofill și busy/obscure sunt păstrate. Trei teste directe UI: conținut injectat/callbacks/ownership, creare pending/submit confirmare, busy/disabled/spinner; cele 6 teste LoginActions existente rămân regresii ale wiring-ului real. CI pe lot urmează, apoi checkpoint verificat înainte de limita sesiunii. Fără modificări funcționale/securitate, Vision nou sau ramuri/producție protejate.


## MOD-HOME-MESSAGE-QUERIES-20261014 — lot 13

LoginPageView lot 12: 60d543c4d48771cae01073d5d6643510b5352693 / CI 38493025007 **5/5 SUCCESS**. După fixture-urile Home validate, HomeMessageQueries separă numai selecția query-urilor notifications/chat privat/grup. Adapterul Firestore păstrează ramura admin/member, where userId/recipientId, order createdAt desc și limit20. Constructor HomePage primește opțional portul. Query construction este lazy; portul nu apelează snapshots/listen, nu stochează UID și nu adaugă cache/retry/polling. snapshots, callbacks, priming/dedup, mounted, erroare și cancel rămân textual în Home după substituția expresiilor sursă. Număr și ordine listeners identice.

Două teste directe cu Firestore fake verifică member/admin/UID/ordine/limită/lipsa abonărilor și query-uri separate pentru A/B. Cele patru fixture-uri State Home și caracterizările AuthGate rămân regresii ale integrării. Acesta nu este acces live sau validare backend a regulilor. CI pe lot urmează. Pas următor: checkpoint complet; admin/maintenance, navigate din paginile reale, GPS/FCM și restul surselor identity-bound se abordează ulterior cu fixture-uri dedicate. P1 AuthGate/Home/route nu este corectat în #28; aprobarea unui PR funcțional separat este necesară.


## CHECKPOINT-AUTH-HOME-LIFECYCLE-20261014 — patru loturi noi validate

Start măsurat al acestei misiuni: **2026-10-14T00:39:20Z**, baza GitHub/local **a5892dbbaf7b4563f5eb4f7740472f5a590203ad**, CI 38488631152 deja 5/5 SUCCESS. Checkout curat la reluare; ultimele 5 loturi nu sunt repetate. Durata completă până la ultima verificare va fi calculată la final, cu precizie de secundă; nu există valori măsurate de credite.

| Lot | Commit final validat | CI | Rezultat |
|---|---|---|---|
| 10. AuthGate identity/route characterization | dee55c97690fe06fcd286541d390f466457cdc93 | 38492063377 | 5/5 SUCCESS |
| 11. State Home real / sync + platform effects DI | 28aa0504ebc6b1d9c406eacbd405f41190c192d7 | 38492570449 | 5/5 SUCCESS |
| 12. LoginPageView independentă | 60d543c4d48771cae01073d5d6643510b5352693 | 38493025007 | 5/5 SUCCESS |
| 13. HomeMessageQueries | dca1ae0c18e029df9d6a81897ae3ecea27bf20ae | 38493437203 | 5/5 SUCCESS |

Commitul inițial lot 10 **93da9d66ed1e5139f27dfbb1cf8f639e226cfe56**, CI **38491865687**: 153 Flutter pass/1 fail, celelalte 4 joburi success. Eșecul presupunea dispose A înainte de mount B; Flutter face mount B înainte de dispose A. Commitul dee55c9 corectează numai ordinea așteptată, fără eliminarea sau slăbirea verificărilor de defect. Runtime AuthGate state machine și corecțiile de securitate nu sunt schimbate. Nu s-a avansat la Home înainte de CI corectiv 5/5.

### Investigație prioritară — P1 confirmat, nereparat

**Reprodus în CI:** după auth A -> B, înainte de profil B, pending UI real păstrează numele/email A; o eroare B este ignorată cât există _profile A. Active page probe păstrează identitatea/tab A, inclusiv la currentUser B + null tranzitoriu. Separat, fixture cu **State-ul real Home** confirmă păstrarea instanței montate A, currentUserId A, datele Cached Alice, tabul A și listenerul users/A. Când vine profilul B, se creează State B nou, tab0, own listener users/B; State A este disposed și old subscriptions anulate. Evenimentele vechi după cancel sunt ignorate în streamurile Dart simulate.

Navigator route A împinsă în harness rămâne vizibilă deasupra paginii B chiar după profil B. Nu este remediată prin ValueKey al Home. Home State fixture înlocuiește **numai rendering-ul** cu SizedBox; nu certifică toate paginile/navigarea reală/hardware sau Firebase live. Nu există dovadă de bypass Firestore Rules din aceste teste. Există dovadă de retenție/afișare client cross-account a datelor deja încărcate, relevantă pe dispozitive comune. Nu declarăm aplicația sigură pe baza CI: testele KNOWN DEFECT sunt caracterizare și rămân marcate astfel.

**Soluție propusă și necesitate de aprobare:** pe UID realmente diferit, invalidare atomică profile/state și loading B, unmount A imediat, păstrarea fallbackului numai pentru reconectarea aceluiași UID; graniță de sesiune pentru Navigator/rute, audit async GPS/FCM. Necesită **aprobare expresă pentru corecție funcțională/de securitate într-un PR separat**. Nu se aplică în #28, conform mandatului. Testele de acceptanță ale corecției vor trebui să ceară zero date A afișate înainte de B sau la eroare B, logout și route push. Raport complet: docs/AUDIT_IDENTITATE_LIFECYCLE_2026-10-14.md.

### Home — caracterizare și limite

Patru teste State real: 14 core member subscriptions în ordinea originală înainte de location/push; own profile/director/teams/cars/locations/schedules/records/definitions/notifications/private/group/settings; eroare/reconnect fără noi abonări; scope financiar t1 -> t2 cu 4 cancel, clear și respingerea vechilor events; dispose -> toate activeCount0; UID real A/B prin AuthGate. Filtrele și query-urile sunt capturate de Firestore fake strict, fără server/live data. Queryurile notification admin/member, private UID și group createdAt desc limit20 sunt verificate separat. Nu există retry/polling/cache sau listen nou în portul HomeMessageQueries; ownership snapshots/listeners rămâne în Home.

SyncFirestore opțional schimbă numai sursa DB core/financial; HomePlatformEffects schimbă numai selecția callbackurilor startup. Defaulturi, momentul accesării SDK, ordinea și apelurile originale rămân. Financial body este identic după unica înlocuire FirebaseFirestore.instance -> _syncDb; nicio formulă, tranzacție, condiție sau permisiune modificată. Nu s-a forțat separarea State financiar/GPS/FCM.

**Rămâne deschis:** fixture admin/audit/seed/maintenance, callbackuri async/post-frame în întregul UI, GPS/FCM hardware/late init/token ownership, reconectare SDK/cache real și protecție server-side. Streamurile testate respectă cancel standard Dart; nu se presupune că au acoperit toate callbackurile platformei sau backend-ul. Cache-urile private și logica finanțelor nu sunt mutate/curățate implicit.

### Teste, inventar și protecții

CI pe fiecare lot: Flutter tests/domain Dart fără engine/build web, Python source/security, Node, Functions syntax/dependencies și Firestore emulator — toate 5 joburi success. Ultimul lot de cod: **163 Flutter PASS**; **13 teste noi** (4 AuthGate, 4 Home, 3 LoginPageView, 2 query selection). Local **155 Python + 3 Node PASS**, Functions syntax și diff/equivalence/inventar PASS. Emulator: **10/10 PASS** în 38493437203. SDK Flutter/Dart indisponibil local; nicio testare Android/live Firebase/publicare.

Inventar: **183 Dart (132 lib, 50 test, 1 script), 59 parts, 124 biblioteci totale, 73 independente în lib**. Regenerat cu script și comparat byte-identic; fără missing/orphan/duplicate/cicluri detectate. Numărul parts nu a scăzut în această misiune: prioritare au fost fixture-urile și interfețele, nu o țintă numerică artificială. Auditul lexical nu demonstrează cod mort.

Zero diff față de baza a5892dbb în lib/finance, reports/PDF/documents/download, OCR, map/Mapbox, assets, Functions, workflows, pubspec, rules/config/teste Firestore. Singura schimbare în home_financial_sync este sursa DB injectabilă, verificată textual. Main rămâne 377f1fd5e73ae78a0df5cab58b09770c873cd167. HEAD-urile verificate neschimbate: #19 d4da2872a566eba258e82b8597c023e03ceb9b56; #20 8ae220b41b5e9c1648151606f9443ba8fa68a90a; #21 d18b2523a31ead7eb65a04fe92a21276a4155c97; #29 545e0202755a8ee86a7b3406adccd469aac84f9e. Numai #28 primește commituri cu expected HEAD lease; arborii local/remote comparați înainte de sync.

**Pas exact de reluare:** verifică HEAD-ul real și CI checkpoint din descrierea PR; nu repeta loturi/runs încheiate. Citește acest checkpoint și raportul lifecycle. Prioritizează aprobarea separată a remediului P1; în modularizare continuă fixture admin/audit și porturi read-only own profile/directory/operations/settings, după caracterizarea efectelor și fără noi reads/writes. LoginPageView este deja separată, nu se re-extrage. Nu muta stări financiare/GPS/FCM înainte de fixture-uri suficiente. Auditul diferențial complet și modularizarea integrală rămân deschise; registrul/Issue #30 nu se reaproba. Vision/Error Log #19/#21 se reutilizează ulterior pe PR dedicat, fără variantă nouă în #28.

Acest checkpoint conține documentație, inventar și eliminarea unei linii goale EOF în fixture auth; CI complet va fi verificat pentru SHA checkpoint înainte de raportul final. PR #28 rămâne Draft/Open, checkout curat și sincronizat. Fără merge/deploy/APK/publicare web/Firebase live/rules/config/billing/migrări/schimbare versiune. Final SHA/run exact sunt în descrierea PR, pentru evitarea unei referințe imposibile la propriul SHA din același commit.


## MOD-HOME-IDENTITY-SOURCES-FIXTURE-20261014 — lot 14

Reluare reală GitHub/local **6d5e417331c700ddb2e5b16481b128dfec26bf29**, checkout curat, CI **38493857756 5/5 SUCCESS** deja încheiat. Cele patru loturi 10–13 sunt prezente; nu sunt repetate. Issue #30 rămâne registru al aprobărilor, fără vot nou. P1 AuthGate/Home/Navigator este confirmat în fixture-urile validate, nereparat; necesită aprobare expresă pentru PR funcțional separat.

Trei teste noi pe State Home real (rendering substituit ca în fixture-ul existent): director member cu admin ascuns/director vizibil/nickname/own fallback/membership și limite canEditTeam; profil propriu null/error/reconnect/temă/post-frame/UID străin fără listener/dispose; înlocuiri keyed A -> B -> A cu liste/tab proaspete, late events/erori ale surselor anulate și exact 42 cancel pentru trei stări cu 14 core listeners. Testele keyed exercită înlocuirea Home după profil nou, NU repară și NU acoperă intervalul defect AuthGate înainte de acel profil.

Nicio schimbare runtime, permisiune, finanțe, query, listener ori cache. Preferințele AppSettings comune root nu sunt declarate izolate de aceste teste: fixture-uri separate pe stare; retenția preferințelor și callbackurile post-frame deja programate rămân de caracterizat. Admin/seed/maintenance și GPS/FCM live rămân limite. Local 155 Python + 3 Node, Functions syntax și diff/inventar PASS; Flutter/Dart sunt executate numai în CI. Inventar **184 Dart / 59 parts / 125 biblioteci totale / 73 independente lib**. CI pe SHA lot trebuie verificat înaintea următorului lot. Urmează query-only port own-profile/directory, fără mutarea callbackurilor, după verde.


### Lot 14 — rezultat inițial și corecție fixture

a2ba14055dc7a6f561e35cdb446fd55737a86d12 / CI 38494525784: **165 Flutter PASS / 1 FAIL**, celelalte 4 joburi SUCCESS. Testul profilului propriu presupunea callback onSettingsChanged imediat după două pump-uri. Codul existent folosește addPostFrameCallback fără a solicita singur un cadru; tema este actualizată, callbackul rămâne amânat până la un cadru ulterior. Fixture-ul cere explicit 0 callbacks înainte de scheduleFrame/pump și 1 după; aceeași caracterizare la reconectare. Nicio schimbare runtime sau slăbire a verificărilor UID/cancel/late events; defectele KNOWN DEFECT existente rămân intacte. Riscul callbackurilor post-frame după dispose rămâne deschis. CI corectiv complet obligatoriu înainte de următorul lot.


## MOD-HOME-IDENTITY-QUERIES-20261014 — lot 15

Lot 14 validat **fa6541042d9a14135dfd7ed7f6b756f0ee377b05 / CI 38494771474 5/5 SUCCESS**, 166 Flutter PASS. Inițial a2ba140 / 38494525784: 165 pass/1 fail exclusiv timing post-frame în fixture; corectat cu verificarea explicită amânare/cadru, fără schimbare runtime ori slăbire UID/cancel.

HomeIdentityQueries este bibliotecă SDK independentă cu două selecții lazy: ownProfile(uid) -> users/uid și directory(isAdmin) -> users sau memberDirectory. Portul nu face snapshots/listen/read/write/retry/polling și nu reține UID, profil ori rezultate. Constructor HomePage compatibil, identityQueries opțional; default db deja existent. Home păstrează guard-ul !isAdmin pentru profil propriu, filtrele de vizibilitate, fallback, cache-uri, setări/post-frame, membership/financial, ordinea și toate cancel-urile. Reconstrucția celor două fișiere anterioare după substituția expresiilor query este byte-exactă; nicio editare în callbackuri. Starea financiară, GPS/FCM, seed/migrare/maintenance rămân nemodificate.

Trei teste noi: căi own/member/admin și lipsa listenerelor; A/B independente cu cancel separat și re-query fără cache; wiring port injectat pe State Home real în ordinea director/profil, o singură abonare și dispose. Cele 7 teste State Home și testele AuthGate KNOWN DEFECT rămân regresii. Testele structurale caută expresiile SDK în noul adapter și ownership/filtre în Home, fără pierderea controalelor de securitate. Local 155 Python + 3 Node, syntax/equivalence/diff/inventar PASS. Inventar **186 Dart / 59 parts / 127 biblioteci totale / 74 independente lib**. CI pe lot urmează înainte de checkpoint final.

P1 AuthGate/Home/Navigator este prioritar, confirmat în harness și nereparat; corecția necesită aprobare pe PR separat. Admin/seed/maintenance, callbackurile post-frame deja programate după dispose, preferințele root între conturi, GPS/FCM hardware/token ownership și Firebase live rămân limite. Fără merge/deploy/APK/web publicat/rules/config/date producție/billing/migrări/versiune ori Vision duplicat. PR #19/#20/#21/#29 neatinse.


## MOD-HOME-OPERATIONAL-QUERIES-20261014 — lot 16

Reluare după întrerupere, verificare UTC **2026-10-14T03:06:26Z**: GitHub/local 8066e0c5b1588cd9fc3cb9a0cca282c110f41465, checkout curat. Lot 15 / **CI 38495164327 5/5 SUCCESS**, **169 Flutter PASS**, build web reușit; CI încheiat nu a fost relansat. Loturile 10–15 sunt păstrate.

HomeOperationalQueries devine bibliotecă SDK independentă pentru teams/cars/locations/schedules/records. Păstrează query-urile GLOBALE existente, fără where/order/limit nou și fără restrângere sau extindere implicită a accesului. Portul nu execută snapshots/listen/read/write/retry/polling, nu stochează rezultate și nu mută starea. Constructor HomePage primește operationalQueries opțional, default folosește db deja existent. Callbackurile, sortările, cache-urile, membership/financial refresh, seed locații/admin și auto-close records rămân în Home și sunt byte-exacte după inversarea celor cinci substituții query și eliminarea selecției portului. Ordinea/cancel/numărul subscriptions sunt păstrate.

Trei teste noi: cele cinci căi globale fără abonări/filtre; două surse DB distincte cu evenimente/cancel separate; port injectat în State Home real, ordine, cinci erori păstrând datele, reconectare fără listeners noi, echipă străină canEditTeam=false, dispose/late event. Fixture rendering substituit, fără Android/GPS/FCM/Firebase live; selecția globală existentă nu reprezintă dovada izolării backend pe echipe. Testele structurale păstrează verificările SDK în adapter și ownership/efectele în Home. Local 155 Python + 3 Node, Functions syntax, echivalență/diff/inventar PASS; **188 Dart / 59 parts / 129 biblioteci totale / 75 independente lib**. CI complet pe SHA lot urmează înainte de checkpoint.

P1 AuthGate/Home/Navigator rămâne prioritar și nereparat, cu aprobare necesară pe PR funcțional separat. Nu sunt mutate financiar/GPS/FCM/admin maintenance ori implementările Vision #19/#21. Nicio modificare main/PR #19/#20/#21/#29, rules/config/date Firebase producție, billing, migrare, versiune, deploy/APK/web publicat.
