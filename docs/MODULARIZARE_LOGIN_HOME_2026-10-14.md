# Login și abonări Home — continuare PR #28

## Baza verificată

HEAD GitHub/local 0b6e315585037281adb35ed7f1d93ea6556c0ae5, checkout curat, PR Draft/Open, CI 38485021337: 5/5 SUCCESS deja încheiat. Cele patru loturi identitate/storage/bootstrap/AuthGate sunt păstrate. Issue #30 și documentele obligatorii sunt referințe; regulile aprobate nu sunt repropuse.

## Audit LoginPage și identitate

LoginPage este part din main: AppSettings, branding/backdrop/install, Flutter/controller/UI, FirebaseAuth/Firestore, HTTP/JSON. Nu are listener sau cache de sesiune și nu folosește QuickAccountStore. Login alias -> endpoint fix -> signIn -> autofill; email direct evită HTTP. Înregistrare: createUser -> updateDisplayName -> set users/uid cu active=false/status=pending; operațiile nu sunt atomice. Numele este citit din controller după await-uri: păstrăm acest contract existent. Resetarea cere email și apelează sendPasswordResetEmail. Mesajele SDK și mounted/busy rămân în state.

AuthGate citește currentUser, authStateChanges, users/uid cu metadata și UI settings. Null tranzitoriu folosește currentUser; profilul valid supraviețuiește erorilor de reconectare. Profil absent -> MissingProfile, inactiv -> PendingApproval, activ -> Home cu ValueKey(uid). Schimbarea UID anulează profilul vechi; callbackul are UID guard. Logout rămâne în Home/Settings și pagina pending. QuickAccounts din Settings face reautentificare înainte de memorare și signIn direct la comutare; SecureStorage și formatul v1 sunt deja testate separat. Nu există aici o politică nouă pentru token expirat: testele adapterelor simulează erori, nu validează SDK live.

## Inventar Home (surse și efecte existente)

| Grup | Surse Firestore / condiții | Efecte și stare |
|---|---|---|
| Definiții | locationCategories, backgrounds, functions | Defaults dacă empty; seed admin; caches categorie/funcție; settings.customBackgrounds și post-frame; functions repornește financial și permission snapshots admin |
| Director | admin: users; membru: memberDirectory | userTeamCache, hidden IDs, profil personal/temă, fallback cont propriu; membership apoi financial |
| Profil propriu | users/currentUserId numai non-admin | Locație/notificări/theme/font/group seen; post-frame callback |
| Operațional | teams, cars, locations, schedules, records | Caches și liste sortate; teams membership/financial; locations seed admin; records auto-close async |
| Notificări | admin toate notifications; membru where userId==UID | known IDs/priming, popup, own unread, listă |
| Chat privat | chatMessages where recipientId==UID | hidden senders/read/deletedFor, known IDs/priming, popup și unread |
| Chat comun | groupChatMessages order createdAt desc limit20 | recent docs, known IDs/priming, group seen, popup/unread |
| Setări | meta/uiSettings | AppSettings partajat, Learning/branding/backup; maintenance admin |
| Audit | admin: audit order at desc limit500 | listă audit |
| Financiar | expenses/perDiems/finance/settlements: toate pentru admin/viewOtherDecont, altfel where teamId==scope | scope guard; cancel vechi/clear liste; patru listeners; callbacks doar mounted, fără generation guard |
| Push/GPS | onTokenRefresh, onMessageOpenedApp în core; Geolocator separat | init async, token ownership; timer/position stream separate, fără schimbări în acest lot |

Ordine init: UID fix din profile -> liste/defaults -> definitions -> directory -> own profile -> operations -> notifications -> chat -> settings -> audit/seed/migration admin -> financial -> adaptive GPS -> push async. Fiecare stream Firestore existent are un listen; SDK gestionează reconnect fără retry aplicație. Numărul exact activ depinde de rol/scope/push: nu presupunem un total constant.

Dispose: cancel core în ordinea adăugării, cancel financial, timer, position subscription, apoi super. Cancel nu este awaited. La scope financiar nou: setează scope, cancel și clear vechi, clear liste, abonează patru query-uri. Caches sunt per Home state, settings este partajat cu root. UID este late final; ValueKey(uid) în AuthGate produce o stare nouă la schimbare cont.

## Limite și blocaje, fără corecție funcțională implicită

Callbackurile financiare vechi nu verifică generația/scope după cancel, iar unele caches/priming/popups sunt mutate înainte de mounted. Nu afirmăm că s-a produs o scurgere live; nici CI verde nu exclude curse SDK/dispose sau post-frame întârziat. Mutarea stării ori introducerea generation guards ar necesita analiză și teste distincte, nu o corecție ascunsă. Background/push init async și scrierile operaționale nu se mută în această etapă.

Puncte viitoare Vision: rezultatul login/alias, profil/sesiune, erorile coreSync și starea source streams pot alimenta ulterior colectorul existent #19/#21 prin contracte sanitizate. Nu se loghează parole/aliasuri/tokenuri/chat/GPS și nu se implementează observabilitate nouă aici.

## Lot 5 — LoginAliasResolver

Bibliotecă independentă SDK/HTTP cu callback post injectat. Body păstrat textual după numele metodei și înlocuirea http.post cu callback; wrapper privat LoginPage și constructorul UI păstrate. URI/header/JSON/password/trim/timeout15s/erori și lipsa retry sunt identice. Teste sintetice: bypass email, request exact unic, răspuns gol/non200, JSON invalid, eroare transport, timeout și completion întârziat fără retry. Fără Firebase live.

CI pe SHA de lot urmează; nu se trece la următorul lot până la 5/5 SUCCESS. Pas următor: porturi LoginPage pentru Auth și profil, fără mutarea state machine-ului, apoi surse Home după grupuri sigure.


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
