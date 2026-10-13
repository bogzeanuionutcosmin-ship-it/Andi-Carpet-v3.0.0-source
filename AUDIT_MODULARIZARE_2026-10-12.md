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
