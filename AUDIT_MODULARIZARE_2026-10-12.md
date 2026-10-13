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
