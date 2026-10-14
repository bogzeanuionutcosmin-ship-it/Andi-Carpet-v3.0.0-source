# Audit identitate / lifecycle — PR #28

## Bază și mandat

Verificat GitHub și local a5892dbbaf7b4563f5eb4f7740472f5a590203ad, checkout curat, PR Draft/Open, CI 38488631152 deja 5/5 SUCCESS. Start măsurat UTC 2026-10-14T00:39:20Z. Documentele obligatorii și Issue #30 rămân sursa de continuitate; deciziile aprobate nu se votează din nou. Cele cinci loturi precedente nu se repetă.

## Lot 10 — caracterizarea AuthGate

Fixture reutilizabil pentru streamuri auth/profile/settings, identități, cereri și cancel. Cele patru teste anterioare folosesc același fixture, fără schimbarea scenariilor. Patru teste noi etichetate explicit KNOWN DEFECT pentru caracterizare (nu acceptanță securitate), plus comutare rapidă/cancel. AuthGate primește opțional activePageBuilder: numai port UI, cheia/profile sunt aceleași; default rămâne exact HomePage original. State machine, UID guard, fallback/null, erori și cancel nu sunt schimbate.

### Problemă prioritară P1 — profil și pagină veche în intervalul A -> B

Cauză: _user devine B, _profileUid devine B și listenerul A este anulat, însă _profile A nu este golit și nu se cere imediat rebuild. Chiar dacă alte setări cer rebuild, build folosește _profile A. La eroare B, onError returnează fiindcă _profile!=null. Astfel durata expunerii poate fi nelimitată până la un snapshot B reușit (nu doar câteva milisecunde). Profile metadata/includeMetadataChanges și politica de reconectare nu sunt modificate.

Teste propuse/executate în CI pe SHA lot: pending UI real afișează Alice/email A după auth B; B error + settings rebuild păstrează A; evenimentele A după cancel sunt ignorate; noul snapshot B înlocuiește profilul. Pentru active branch un widget probe cu key/profile măsoară mount/dispose/tab: starea A supraviețuiește până la B, apoi key B resetează starea. Probe-ul nu este HomePage complet și nu pretindem validare Firebase live.

### Problemă prioritară P1 — route de A poate rămâne vizibilă după B

Navigatorul MaterialApp este în afara graniței Home keyed. Ruta push de A supraviețuiește reconstruirii paginii de bază B. Fixture-ul active page împinge un ecran cu identitatea A și confirmă că poate rămâne deasupra B. Demonstrație a compoziției AuthGate/Navigator, nu încă a tuturor paginilor reale Home. Paginile reale Home folosesc același Navigator.push și transportă obiecte de profil/date; impactul exact al fiecăreia necesită caracterizare.

### Ce nu demonstrează aceste teste

Nu demonstrează bypass Firestore Rules sau acces server-side la date interzise. Demonstrează retenție/afișare client a identității/stării deja încărcate a altui cont. În scenarii de schimbare cont pe dispozitiv comun, acestea sunt probleme de confidențialitate. CI verde al testelor KNOWN DEFECT înseamnă că defectul este caracterizat, NU că izolarea este corectă. Nu ascundem rezultatul schimbând așteptările pentru a declara securitatea rezolvată.

### Corecție propusă, separată și supusă aprobării

Pe schimbare reală UID: invalidare atomică profile/identity-bound state, afișare loading pentru B, unmount imediat Home A; reconectarea aceluiași UID păstrează profil valid. Introducere graniță de sesiune pentru rutele Navigator (reset/navigator keyed la schimbarea UID) și audit async GPS/FCM. Teste de acceptanță viitoare trebuie să ceară absența oricărei date A înainte de snapshot B, la B error, logout și după navigate. Este modificare funcțională/de securitate și necesită **aprobare expresă pentru PR separat**, conform mandatului actual; nu se implementează tacit în #28.

CI pe SHA lot urmează. După validare: Home fixture cu Firestore și efecte platformă injectate, fără mutarea logicii financiare/GPS/FCM. Dacă izolarea reală nu poate fi caracterizată sigur, continuă LoginPageView independentă. Fără merge/deploy/APK/live Firebase/rules/config/billing/migrări/versiune/Vision nou; PR #19/#20/#21/#29 sunt protejate.

## Rezultat CI inițial și corecție fixture

93da9d66ed1e5139f27dfbb1cf8f639e226cfe56 / run 38491865687: 153 teste Flutter PASS / 1 FAIL, celelalte 4 joburi SUCCESS. Eșecul este exclusiv presupunerea ordinii lifecycle: Flutter montează B înainte de dispose A, nu invers. Testul este corectat să ceară exact secvența observată mount A / mount B / dispose A. Verificările de profil A păstrat, starea A în intervalul UID și route A persistentă rămân neschimbate; CI le-a trecut și confirmă defectele în harness. Corecția nu ascunde defectele și nu modifică runtime. Run final corectiv urmează.


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


## CHECKPOINT-HOME-SOURCES-VALIDATED-20261014 — loturi 14–16

Lot 14 fa6541042d9a14135dfd7ed7f6b756f0ee377b05 / 38494771474 **5/5**; lot 15 8066e0c5b1588cd9fc3cb9a0cca282c110f41465 / 38495164327 **5/5**; lot 16 f6eaf325ba1dd5574c8e33ef42b581a8d97a32db / 38504724656 **5/5 SUCCESS**. Ultima suită: **172 Flutter + 155 Python + 3 Node + 10 emulator PASS**, smoke Dart și build web PASS; **9 teste Flutter noi**. Eșecul inițial lot 14 (165 pass/1 fail, timing post-frame) și corecția numai de fixture sunt documentate, fără modificarea testelor KNOWN DEFECT.

Inventar **188 Dart / 59 parts / 129 biblioteci totale / 75 independente lib**, regenerat identic, fără ținte lipsă/orfani/duplicate/cicluri. HomeIdentityQueries și HomeOperationalQueries separă numai selecțiile originale; state/callbacks/cache/efecte/cancel în Home, fără reads/writes/listeners suplimentare. **P1 AuthGate/Home/Navigator confirmat, nereparat; necesită aprobare pe PR funcțional separat.** Nu declara CI verde ca remediere a confidențialității.

Raport complet, timpi măsurați inclusiv întrerupere, commituri/teste/limite și pasul exact de reluare: **docs/CHECKPOINT_HOME_SOURCES_2026-10-14.md**. Urmează fixture settings/audit/admin/seed/maintenance și caracterizarea AppSettings/post-frame/GPS/FCM; nu repeta loturile 10–16. PR #19/#20/#21/#29 neatinse, fără producție/merge/deploy/versiune/Vision duplicat. Checkpoint exclusiv de documentație: CI pe SHA propriu se verifică înainte de raportul final; descrierea PR va conține SHA/run final.


## MOD-HOME-SETTINGS-LIFECYCLE-20261014 — lot 17

Reluare GitHub/local d9795f4f4f26630969009cfd1fa803052558f4b1, checkout sursă curat; loturile 10–16 și CI 38505140788 deja încheiat nu se repetă. Checkout separat în sesiunea actuală. Cinci teste Flutter noi, fără schimbare runtime: AppSettings comun A→B cu fallback la preferințele A până la date explicite B; setări globale parțiale/null/error/reconnect/clamps; callback background post-frame după dispose; callback vizual A după mount B; completion startup injectat A după dispose.

Testele de retenție și callback sunt KNOWN DEFECT de caracterizare, nu acceptanță a izolării. Testul startup dovedește doar lipsa anulării la granița HomePlatformEffects injectată, nu comportamentul hardware GPS/FCM. State Home real cu rendering substituit; date strict sintetice. Admin/seed/maintenance și token ownership reale urmează. AuthGate P1 rămâne confirmat și NEREPARAT, separat de aceste observații; remedierea se face numai pe PR distinct autorizat.

Runtime lib/ este byte-identic bazei. FixtureHomePage permite doar alegerea efectelor deja injectabile. CI pe SHA lot obligatoriu înainte de lotul următor; rezultatul și inventarul se actualizează în checkpoint. Fără main/merge/deploy/APK/versiune/rules/config/date Firebase producție/migrări/billing sau PR-uri protejate.


### Lot 17 — corecție așteptare normalizare font

b1bea4b132317ff0ee9bd10f51498635faf06b0a / CI 38508637600: 176 Flutter PASS / 1 FAIL; celelalte 4 joburi SUCCESS, inclusiv 10 emulator. Fixture-ul cerea Roboto literal, dar normalizarea runtime existentă îl convertește la Sans. Corecția cere Sans după profil A și după fallback B; nicio schimbare runtime sau slăbire a verificărilor retenției între conturi, callbackurilor după dispose ori KNOWN DEFECT. Revalidare integrală obligatorie înainte de lot 18.


## MOD-HOME-ADMIN-MAINTENANCE-FIXTURE-20261014 — lot 18

Lot 17 corectiv **da2fc85f257cb9905161cd5d77c4972b666d6b28 / CI 38508870095 5/5 SUCCESS**, **177 Flutter PASS**, smoke Dart și build web PASS. Eșecul inițial 176/1 al așteptării fontului este păstrat în raport. Nu s-a avansat înainte de verde.

HomePage primește maintenanceFirestore opțional, cu getter lazy care folosește exact FirebaseFirestore.instance implicit. Numai accesul la DB în maintenance/backup/seed/permission snapshots este injectabil; trei module runtime se reconstruiesc byte-exact după inversarea substituției și eliminarea declarațiilor portului. Nu se schimbă queries, filtre, writes, batches, ordinea, guard-urile sau comportamentul. Nu se execută migrări reale; fixture strict local.

Cinci teste noi cu State Home real/rendering substituit: Admin cu 18 listeners (audit + global finance), ordinea citirilor seed/migration și badge_v2 fără scrieri; audit error/reconnect/cancel; backup dezactivat dar retenție încă activă cu item-delete înainte de parent-delete; KNOWN DEFECT badge legacy șterge funcțiile și golește functionIds/effectivePermissions member; snapshot funcții active recalculează numai permisiunile schimbate; KNOWN DEFECT maintenance in-flight continuă o ștergere sintetică după dispose, fără duplicate la două evenimente pending. Fiecare citire este scriptată; apelurile neașteptate sunt înregistrate chiar dacă runtime le prinde. Aceste teste nu certifică backend, Android/FCM/GPS ori AdminPanel UI de editare a conturilor.

Riscurile de retenție AppSettings/post-frame și badge_v2/maintenance sunt caracterizate, nu reparate. AuthGate P1 rămâne NEREPARAT și cere PR separat autorizat. Fișierele financiare/GPS/FCM, rules/config, date reale și PR-urile #19/#20/#21/#29 nu se modifică. CI pe SHA lot urmează înainte de orice extragere query-only.


### Lot 18 — corecție fake WriteBatch pentru opțiuni absente

5dd9b007fc1134546f4e4dacbfeca31cd5066876 / CI 38509312314: 181 Flutter PASS / 1 FAIL; celelalte 4 joburi SUCCESS. Fake WriteBatch interpreta parametrul opțional null ca SetOptions la set fără merge, provocând TypeError în migrarea sintetică. Corecția fake distinge null de SetOptions, fără schimbare runtime sau reducerea aserțiunilor destructive badge_v2. Toate efectele și verificările KNOWN DEFECT rămân. CI corectiv complet înainte de extragere.


## MOD-HOME-SYSTEM-QUERIES-20261014 — lot 19

Lot 18 corectiv **bb8a756670b45a4fe8b73cd5a1ecdb653982b9bd / CI 38509542005 5/5 SUCCESS**, **182 Flutter PASS**, smoke Dart/build web PASS. Eșecul fake SetOptions este documentat; runtime și aserțiunile riscurilor nu au fost schimbate.

HomeSystemQueries, bibliotecă SDK independentă query-only: meta/uiSettings și audit orderBy at descending limit500 exact. Fără snapshots/listen/get/write/retry/polling sau cache/state/UID în port. Home păstrează guard !isAdmin înainte de audit, ordinea settings→audit, toate callbacks/efectele maintenance, setările mutate, fallback/error/cancel și cele 18 listeners Admin / 14 member. Două module listeners se reconstruiesc byte-exact după inversarea substituțiilor; constructor opțional compatibil.

Patru teste noi: căi/laziness/lipsa listenerelor; surse DB independente/cancel; member wiring fără audit, reconnect/errors păstrând settings; admin wiring cu audit și maintenance reale în fake strict. Testele structurale mută numai verificarea expresiilor SDK în adapter, păstrând guard/ownership/callback checks în Home. Un contract local căuta încă doc(uiSettings) în Home; relocat în adapter înainte de commit, cu toate cele 155 Python PASS apoi.

Riscurile AuthGate P1, AppSettings comun, post-frame după dispose, badge_v2 și maintenance după dispose sunt confirmate/caracterizate și NEREPARATE. GPS/FCM ownership hardware nu este validat. CI pe SHA lot obligatoriu înaintea următorului lot. Fără migrare reală, merge/deploy/producție/versiune sau PR-uri protejate.


## MOD-IDENTITY-EMULATOR-CONTRACTS-20261014 — lot 20

Lot 19 **2744054f260024c2a6717eed024f422d326a63f3 / CI 38509919885 5/5 SUCCESS**, smoke Dart/build web și suitele existente PASS. Cinci teste emulator noi în entrypointul existent, fără schimbarea workflow-ului/regulilor: profil privat own/foreign/list/admin/inactive-admin; B nu poate citi/scrie pushTokens A; audit admin-only și actorUid propriu; self-escalation rol/active/functionIds/effectivePermissions/funcții interzisă; uiSettings public/global read caracterizat expres inclusiv unauth, writes member interzise.

Date strict sintetice în demo-andi-carpet, seed numai cu security rules disabled în fixture; assertion-urile folosesc regulile reale ale repository-ului. Cele 10 teste financiare anterioare și regula avansului sunt păstrate. Nu se modifică date/reguli/config Firebase reale, Functions sau billing. Aceste teste sunt contracte backend simulate, nu remediere AuthGate și nu validare cache/Android/FCM/GPS live.

P1 retenție UI/profile/Home/Navigator rămâne confirmat și NEREPARAT. Rezultatele backend nu pot fi extrapolate la orice colecție sau la efectele async vechi; UI deja încărcat nu este șters de un denial server. CI integral pe SHA lot obligatoriu înainte de checkpoint.


### Lot 20 — respectarea contractului de hash protejat

5eee1b758be752c7cdb532dd0e384095a5f9b82d / CI 38510201809 a fost trimis înainte de verificarea integrală a rezultatului local. Python local 154 PASS / 1 FAIL: hashul tests/firestore/diurna.test.cjs este protejat de contractul PDF/routing. Fără slăbirea testului sau schimbarea manifestului, entrypointul financiar este restaurat byte-exact. Cele cinci teste de identitate sunt mutate în tests/firestore/identity-lifecycle.test.cjs cu workflow NOU dedicat test-identity-lifecycle.yml (PR/manual, demo emulator, contents:read); workflow-urile existente și configurațiile sunt intacte.

Corecția trebuie validată în toate cele 5 joburi standard PLUS jobul dedicat identity emulator. Total emulator final 10 financiar + 5 identitate, numai după rezultate verificate separat. Acest addendum corectează mențiunea anterioară de folosire a entrypointului existent: acesta rămâne integral protejat. Nicio regulă Firebase/producție/migrare/deploy modificată.


## MOD-HOME-AUTOMATIC-BACKUP-FIXTURE-20261014 — lot 21

Lot 20 corectiv **1bf882e8222c067162951a63d61e8903f5945e2d**: **CI 38510323578 5/5 SUCCESS** + **38510323665 identity emulator 1/1 SUCCESS (5 tests)**. Suite standard 186 Flutter/155 Python/3 Node/10 financial emulator, smoke Dart/build web PASS. Inițial 5eee1b7 / 38510201809: Python failure hash protejat, Flutter cancelled de noul commit, celelalte 3 joburi SUCCESS; nu se confundă cancelled cu build eșuat.

Două teste Flutter noi, fără modificare runtime: backup automat cu cele 15 citiri originale, status running→complete și marcarea meta/backupAutomation doar după succes, actorUid/merge/order; eroare de citire cars→failed cu mesaj controlat, fără citiri ulterioare/retry/marcaj de succes. Date complet sintetice, zero documente copiate, fără producție. Testele de rollback după scrieri parțiale sau batches de 8/300/350 nu sunt acoperite de aceste două cazuri.

Fixture strict respinge SDK neprevăzut; toate caracterele de defect preexistente rămân. P1 AuthGate/Home/Navigator și ownership GPS/FCM nu sunt remediate. CI complet standard plus workflow identitate rămân obligatorii. Numărul part nu se forțează.


## CHECKPOINT-HOME-ADMIN-IDENTITY-VALIDATED-20261014 — loturi 17–21

Bază GitHub/local **d9795f4f4f26630969009cfd1fa803052558f4b1**, checkout original curat, CI 38505140788 deja încheiat, fără repetarea loturilor 10–16. Lucru într-un checkout separat; transfer GitHub cu expected_sha și comparație tree byte-exact înainte de sincronizare locală.

| Lot | Commit validat | CI standard | Flutter | Rezultat |
|---|---|---|---|---|
| 17 — setări comune/post-frame/startup întârziat | da2fc85f257cb9905161cd5d77c4972b666d6b28 | 38508870095 | 177 | 5/5 SUCCESS |
| 18 — Admin/audit/seed/maintenance/badge | bb8a756670b45a4fe8b73cd5a1ecdb653982b9bd | 38509542005 | 182 | 5/5 SUCCESS |
| 19 — HomeSystemQueries | 2744054f260024c2a6717eed024f422d326a63f3 | 38509919885 | 186 | 5/5 SUCCESS |
| 20 — backend identitate separat | 1bf882e8222c067162951a63d61e8903f5945e2d | 38510323578 | 186 | 5/5 SUCCESS + identity 38510323665 SUCCESS |
| 21 — backup automat complet/failure | 177ea01ae97b90aaa9a5c063fd561d59d9a95848 | 38510700021 | 188 | 5/5 SUCCESS + identity 38510700028 SUCCESS |

**16 teste Flutter noi, 5 teste emulator noi. Final cod: 188 Flutter, 155 Python, 3 Node, 10 financial + 5 identity emulator PASS; smoke Dart și build web PASS.** Local: 155 Python, 3 Node, Functions și identity-test syntax, equivalence/diff/inventar/116 protected hashes PASS. Flutter/Dart nu sunt instalate local; nu există validare Android/GPS/FCM/Firebase live. Mărimea suitelor nu este suma repetărilor CI.

Inventar **193 Dart = 135 lib + 57 test/support + 1 script; 59 part, 134 biblioteci totale, 76 independente în lib**. Snapshot comparat cu regenerarea integrală; fără missing/orphan/duplicate/cicluri detectate. Inventar lexical, nu dovadă de cod mort. 59 part sunt păstrate pentru cuplajele private reale.

### Eșecuri păstrate și corectate

- b1bea4b132317ff0ee9bd10f51498635faf06b0a / 38508637600: 176 Flutter PASS/1 FAIL, alte 4 joburi SUCCESS. Așteptare literală Roboto greșită; normalizare runtime existentă Sans, corectat exclusiv fixture-ul.
- 5dd9b007fc1134546f4e4dacbfeca31cd5066876 / 38509312314: 181 Flutter PASS/1 FAIL, alte 4 SUCCESS. Fake batch trata SetOptions null greșit; corectat fake, păstrând verificările destructive badge_v2.
- 5eee1b758be752c7cdb532dd0e384095a5f9b82d / 38510201809: Python failure hash financiar protejat, Flutter CANCELLED de corectiv, celelalte 3 joburi SUCCESS. Commit trimis înainte de verificarea integrală a rezultatului Python local (154/1). Fișierul financiar restaurat byte-exact, fără schimbare manifest/test de protecție. Noile teste au fișier și workflow emulator propriu.

Nu s-a trecut la următorul lot înainte de validarea corecției; niciun test KNOWN DEFECT nu a fost slăbit.

### Ce s-a schimbat structural

HomeSystemQueries este query-only, păstrează meta/uiSettings și audit orderBy(at descending)/limit500. Home păstrează guard admin, snapshots, listeners, callbacks, cache, settings mutate, efectele maintenance și cancel. Două module listeners se reconstruiesc byte-exact după inversarea substituțiilor. API-urile existente sunt păstrate prin parametri opționali/re-export.

maintenanceFirestore opțional face testabile seed/permission/migration/backup folosind aceeași logică reală; default lazy FirebaseFirestore.instance și ordinea sunt păstrate. Trei module se reconstruiesc byte-exact după inversarea injectării. Nu s-a executat nicio migrare reală; fixture-urile înregistrează numai scrieri sintetice.

Workflow NOU test-identity-lifecycle.yml rulează numai emulatorul demo pe PR/manual, cu contents:read. Workflow-urile existente, rules/config, Functions, PDF/assets/financiar/OCR/map/versiune și suita diurna.test.cjs protejată sunt intacte față de baza d9795f4. Toate cele **116 hashuri protejate** verificate.

### Riscuri confirmate/caracterizate, NEREPARATE

- **AuthGate P1:** profil/UI/Home/listeners A pot rămâne între auth B și profil B sau la eroare B; ruta Navigator A poate supraviețui profilului B. PR #28 nu implementează remediul.
- AppSettings comun păstrează tema/fontul A până la câmpuri explicite B; null/error/missing fields folosesc fallbackul existent. Nu confundăm setările globale legitime cu preferințele personale.
- Callback background/own-profile post-frame programat poate rula după dispose și după mount B; măsurat prin State Home real/rendering substituit.
- Migrarea legacy badge_v2 șterge definiții și golește atribuiri member; reprodusă numai în fixture strict.
- Maintenance in-flight poate continua o ștergere după dispose; backup dezactivat nu dezactivează retenția existentă.
- Startup injectat neanulat după dispose este demonstrat numai la granița HomePlatformEffects; nu este test al hardware-ului. Auditul sursei GPS/FCM constată lipsa unor reverificări mounted/identitate după await, înainte de token write/attach listeners sau de subscription GPS întârziată. Exploatarea reală și ownership multi-dispozitiv NU sunt validate.

Backend emulator respinge private foreign profile get/list, token A prin identitate B, audit read member/inactive admin și self-escalation role/active/functions/effectivePermissions. uiSettings read este global/public inclusiv unauth prin regula existentă — caracterizare, nu remediere. Aceste verificări nu șterg datele deja afișate și nu demonstrează izolarea tuturor colecțiilor/cache-urilor SDK. **Nu există din aceste scenarii dovadă de bypass Firestore; nici garanție generală de securitate.**

**Remediate:** exclusiv erorile proprii de fixture/transfer structural menționate; niciun defect funcțional/securitate preexistent nu este declarat reparat. START concurent, restore/OCR și riscurile financiare istorice rămân.

### Următorii pași exacți

1. Verifică HEAD/CI real din PR; loturile 10–21 și checkpointurile verzi NU se repetă. HEAD final de documentație și CI propriu se raportează în PR după verificare, evitând autoreferința imposibilă.
2. Fixture-uri platformă reale pentru GPS/FCM la await/dispose/UID/logout, ownership token, atașări tardive și cancel; nu muta stări înainte de acestea.
3. AdminPanel account/function actions ca UI real (edit/disable/assign/delete/failure); emulatorul de permisiuni și fixture-ul Home nu le înlocuiesc. Seed cu colecții goale, backup non-empty/batches8, retenție300, migrare350/failure sunt încă neacoperite dinamic integral.
4. Callbackuri Navigator și root settings, reconectare/cache SDK real, generații/scope financiar. Extrage numai surse independente după fixture-uri, fără forțarea part.
5. Home are 14 parts, Admin 13, auth 3, expenses4/map4/schedule3 și celelalte ecrane încă folosesc main/private state; acestea sunt grupuri de fișiere, nu număr de defecte.
6. Corecția P1 rămâne pe PR funcțional distinct, autorizat expres; planul de acceptanță este în auditul identitate/lifecycle. Issue #30 și Vision/Error Log #19/#21 se reutilizează ulterior; nicio implementare nouă aici.

### Protecții și stare

Main și HEAD-urile #19/#20/#21/#29 reverificate neschimbate la reluare; reconfirmare după checkpoint în PR. Fără merge/deploy/APK/publicare web/modificare versiune, date/rules/config Firebase producție, billing ori migrări. Checkout-ul curent este curat/sincronizat la finalul codului; checkpointul documentației are validare separată standard + identity. Checkoutul anterior a fost păstrat intact.


## Plan de remediere P1 — numai PR separat autorizat

| Graniță | Acceptanță viitoare | Dovezi/limite actuale |
|---|---|---|
| Auth/profile | UID diferit invalidează imediat profilul/state A și arată loading B; fallback numai same UID | KNOWN DEFECT client confirmat; NU implementat |
| Home/listeners | Home A demontat imediat, sursele vechi anulate și evenimente tardive respinse prin sesiune/generație | Cancel Dart și keyed replacement testate după profil B, nu în intervalul defect |
| Navigator | Rute/dialoguri A nu supraviețuiesc schimbării identității/logout | Ruta A persistentă caracterizată; fiecare pagină reală încă necesită fixture |
| Personal settings | Separă global legitim de personal; nu păstrează preferințe personale A ca fallback B fără decizie explicită | Shared object și callback tardiv reproduse; schimbarea resetului este funcțională |
| GPS/FCM | Owner UID și generația operațiunii verificate după await și înainte de write/attach; resurse tardive imediat anulate | Audit sursă + graniță injectată; hardware și SDK callback reale netestate |
| Maintenance | Verificare sesiune/autorizație înaintea loturilor noi, fără presupunerea că un write deja expediat poate fi anulat/rollback automat | Continuare după dispose în fixture; batch/failure parțial necesită cazuri noi |
| Backend | Păstrează denial pentru profil/token străin și self-escalation; teste toate colecțiile sensibile relevante | 5 identity emulator PASS, fără extrapolare la întreaga aplicație |

Pe PR de remediere, testele de acceptanță cer ZERO date A după UID B, inclusiv înainte de profil B, la eroare/null, logout, comutări rapide, rute push și callbackuri întârziate. Se păstrează caracterizarea istorică separat; testele KNOWN DEFECT verzi nu sunt certificat de reparație. Nu există autorizare implicită pentru acest PR din modularizarea #28.


## MOD-HOME-BACKUP-BATCH-FIXTURES-20261014 — lot 22

Reluare exactă din GitHub/local c794c5d6d0252b4e9180ce6bbf16cd2aa455951d, CI 38511071554 5/5 deja încheiat. Loturile 10–21 nu se repetă. Checkout nou curat; checkouturile istorice, inclusiv modificările nesalvate, sunt păstrate intacte.

Patru teste Flutter noi cu State Home real/rendering substituit, strict sintetice: backup 17 documente users/teams cu ID-uri repetate între colecții, payload nested/Timestamp/null și batches 8/8/1; eșecul celui de-al doilea batch păstrează primul batch și nu marchează automatizarea ca reușită; retenție 601 notifications și 301 backup items cu batches 300/300/1 și 300/1, items înainte de parent inclusiv backup gol; failure retention păstrează parent și nu citește următorul backup/nu face retry. Fake separă commitAttempts de commits reușite și permite eroare controlată înainte de commit; fără schimbare runtime lib/.

KNOWN DEFECT nou caracterizat: documentCount al backupului failed numără documente încercate (16) deși numai 8 sunt confirmate în fixture; primele items rămân fără rollback. Este comportament preexistent, NU reparat și nu dovadă de integritate a restaurării. Eșecul retenției poate lăsa un backup parțial purjat, cu parent păstrat. Fixture-ul simulează reject înainte de commit; nu certifică ambiguitatea network/SDK după commit server.

Local: 155 Python PASS, inventar 193 Dart/59 part/134 biblioteci totale/76 independente lib fără missing/orphan/duplicates/cycles. Flutter/Dart indisponibil local; CI standard plus identity emulator pe SHA lot se verifică înainte de următorul lot. AuthGate P1 și riscurile GPS/FCM/post-frame/settings/badge_v2 rămân NEREPARATE în #28. Fără modificări de producție, merge/deploy/APK/versiune, migrări reale sau PR-uri protejate.


## MOD-HOME-SEED-MIGRATION-PERMISSION-FIXTURES-20261014 — lot 24

Lot 23 dce2a41be8e0af0a37aead184c57203a64c6cbcc validat: CI standard 38525369939 5/5 SUCCESS plus identity 38525369895 SUCCESS; 195 Flutter, smoke Dart/build web PASS.

Trei teste Flutter noi, runtime lib/ byte-identic lotului 23: colecții goale la startup → 103 locații în ordinea catalogului, cu suprafețe/categorii/active păstrate, și cele 4 categorii + funcția admin; migrare badge_v2 sintetică cu 350 definiții și 351 membri → batches350/350/3, toate delete înainte de admin/users și markerul de versiune ultimul; permission snapshot 501 membri → un singur batch501, rejection controlat vizibil în coreSyncError, fără retry automat și reluare numai la snapshot de funcții ulterior.

Migrarea rămâne KNOWN DEFECT: șterge definițiile și golește atribuiri/drepturi ale membrilor inclusiv între batchuri. Nu este executată real și nu este reparată. Testul de permission501 caracterizează clientul și eroarea injectată, NU certifică acceptarea unui asemenea batch de server/SDK real sau limita backend; fake-ul permite succesul la reluare exclusiv pentru a verifica eliberarea guardului in-flight. Riscurile de migrare failure/parțial și batch mare rămân pentru PR funcțional distinct.

Local 155 Python PASS, diff/inventar PASS; 195 Dart/59 part/136 biblioteci totale/77 independente lib. CI standard plus identity pe SHA lot obligatoriu înainte de checkpoint. GPS/FCM plugin/hardware real, AdminPanel account/function UI și cache SDK rămân neacoperite integral; nu se confundă Home State fixture cu acestea. AuthGate P1 rămâne NEREPARAT în #28. Fără migrări reale, producție, main/merge/deploy/APK/versiune, rules/config/billing ori PR-uri protejate.


## CHECKPOINT-HOME-RETENTION-BATCHES-VALIDATED-20261014 — loturi 22–24

**Reluare reală c794c5d6d0252b4e9180ce6bbf16cd2aa455951d → cod validat 61e517cc031c44bf45b65839a0537419a4898922.** Checkpointul d9795f4 transmis de proprietar era mai vechi; GitHub și Personal Context au confirmat loturile 17–21 deja încheiate. Loturile 10–21 și CI-urile lor nu au fost repetate. Checkout nou curat; checkouturile istorice și modificările lor nesalvate au fost păstrate intacte.

| Lot | SHA validat | CI standard | Identity emulator | Flutter | Rezultat |
|---|---|---|---|---|---|
| 22 — backup8/retention300/failures | 38eeae632f676442a4ff829d079fbf6982ed721a | 38524869964 | 38524869959 | 192 | 5/5 + identity SUCCESS |
| 23 — HomeRetentionQueries | dce2a41be8e0af0a37aead184c57203a64c6cbcc | 38525369939 | 38525369895 | 195 | 5/5 + identity SUCCESS |
| 24 — seed empty/badge350/permission failure | 61e517cc031c44bf45b65839a0537419a4898922 | 38525907269 | 38525907278 | 198 | 5/5 + identity SUCCESS |

**10 teste Flutter noi; 198 Flutter, 155 Python, 3 Node, 10 financial + 5 identity emulator PASS**, smoke Dart și build web PASS pe fiecare lot. Fără eșecuri CI sau corecții necesare în aceste trei loturi. Local: 155 Python/3 Node, Functions și identity syntax, diff, echivalență și inventar PASS; Flutter/Dart nu sunt instalate local. Testele folosesc date sintetice/SDK fake și State Home real cu rendering substituit; nu sunt teste Android/GPS/FCM/Firebase live sau restaurare end-to-end.

### Schimbare structurală și echivalență

HomeRetentionQueries este singura bibliotecă runtime nouă: două selecții notifications/backups where createdAt isLessThan cutoff Timestamp explicit. Fără ceas/clamps/query filters noi/order/limit/read/listen/write/retry/cache. Home păstrează calculul cutoff la același punct, get, ordinea notifications→backups, batches300, delete parent după items, startup/guard/in-flight/error handling. Cele două substituții și directivele main inversate reconstruiesc byte-exact fișierele bazei. API HomePage neschimbat. Loturile 22 și 24 nu modifică lib/.

Backup non-empty verificat la batches8/8/1, ID identic în colecții distincte, payload nested/null/Timestamp păstrat, status/owner marker după succes. Failure după primul batch păstrează items și status failed fără marker de succes/retry/rollback. Retenție verificată cu 601 notificări, 301 items și parent gol; failure păstrează parent și oprește următoarele citiri. Seed startup gol verifică 103 locații și 4 categorii + admin. Badge migration350/350/3 păstrează ordinea și markerul ultimul, inclusiv ștergerea/golirea preexistentă. Permission501 caracterizează un batch unic, error și guard eliberat numai pentru un eveniment ulterior.

### Inventar și integritate

**195 Dart = 136 lib + 58 test/support + 1 script; 59 part, 136 biblioteci totale, 77 independente în lib.** Snapshot regenerat și comparat byte-identic, fără missing targets/orphan parts/duplicate declarations/cycles detectate. Audit lexical, nu dovadă de cod mort. Nu s-a forțat conversia part.

**116 hashuri protejate PASS.** Zero schimbări în auth/GPS/FCM/financiar/PDF/OCR/map/assets/Functions/workflows/pubspec/Firebase rules/config/teste financiare protejate. Singurele schimbări lib sunt adaptorul, două expresii în home_backup_maintenance și import/export main. Main 377f1fd5e73ae78a0df5cab58b09770c873cd167; PR #19 d4da2872a566eba258e82b8597c023e03ceb9b56, #20 8ae220b41b5e9c1648151606f9443ba8fa68a90a, #21 d18b2523a31ead7eb65a04fe92a21276a4155c97, #29 545e0202755a8ee86a7b3406adccd469aac84f9e — HEAD-uri verificate neschimbate în sesiune.

Publicare numai ramura #28, cu expected_sha și fără force. Arborele Git local a fost comparat cu arborele remote înainte de sincronizare; checkout curat și sincronizat după fiecare lot. Checkpointul de documentație final are SHA/run propriu verificat separat; descrierea PR va conține valorile exacte, evitând autoreferința imposibilă.

### Riscuri confirmate/caracterizate, NEREPARATE

- AuthGate P1: profil/Home/listeners/Navigator A pot supraviețui schimbării în B; niciun remediu aplicat în #28. Verdele KNOWN DEFECT nu certifică izolarea.
- AppSettings comun și callbackuri post-frame după dispose/mount B; maintenance in-flight după dispose; GPS/FCM fără reverificări suficiente după await, nevalidate hardware/SDK real.
- Badge_v2 șterge definiții și golește atribuiri; noul test confirmă și ordinea între batches350. Eșecul migrației și concurența dintre seed/migration rămân fără acoperire dinamică completă.
- Backup failed păstrează items deja confirmate și documentCount include documente încercate, nu numai cele confirmate (fixture16/8); retention poate lăsa parent cu items parțial purjate. Eroarea injectată este înainte de commit; ambiguitatea network după commit server nu este testată. Restaurarea non-atomică rămâne.
- Permission snapshot trimite toate cele 501 writes într-un singur batch în fixture. Rejection/retry pe eveniment nou sunt caracterizate; fake-success nu certifică acceptarea backend/SDK sau limita reală.
- START concurent, OCR/financiar, scope/generații și riscurile istorice rămân.

**Remediate în această continuare: niciun defect funcțional/de securitate preexistent.** Nu au existat erori de refactor/fixture care să necesite corecții; doar infrastructură de test și separare structurală. Nu se slăbesc teste sau contracte pentru a masca defecte.

### Pas exact de reluare

1. Verifică HEAD real și CI final din PR; nu repeta loturile 10–24.
2. GPS/FCM: fixture SDK/platformă pentru serviceEnabled/checkPermission/requestPermission/getPositionStream, respectiv notificationSettings/getToken/saveToken/onTokenRefresh/getInitialMessage. Blochează fiecare await controlat, comută UID/dispose/logout și înregistrează owner, atașările, write paths și cancel. HomePlatformEffects injectat NU înlocuiește această validare. Delayed proximity250 și Web700 trebuie caracterizate; păstrează defectele ca atare în #28.
3. AdminPanel UI real: edit/disable/assign/delete/failure pentru conturi/funcții; fixture Home permission/seed nu îl certifică. Seed/migration concurente și migration failure/parțial, backup retry/restore/ambiguitate commit și cache SDK/reconnect rămân.
4. Home are 14 parts, Admin13, auth3, expenses4/map4/schedule3 și celelalte ecrane dependente de main/private state. Extrage numai componente independente/adaptoare după fixture-uri, fără schimbări de comportament.
5. Plan remediere P1 separat: invalidare atomică la UID diferit, fallback numai same UID, graniță Navigator, ownership/generații post-await/settings. Acceptanță ZERO date A înainte de profil B și la error/null/logout/late callbacks. Nicio implementare în #28; PR distinct și autorizare expresă sunt necesare pentru schimbarea funcțională.
6. Issue #30 și Vision/Error Log #19/#21 rămân pentru etapa ulterioară, fără implementare duplicată.

PR #28 rămâne Draft/Open. Fără merge/main/deploy/APK/publicare web/modificare versiune/date/rules/config Firebase producție/billing/migrări reale sau modificări ale PR-urilor protejate.
