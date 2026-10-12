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
