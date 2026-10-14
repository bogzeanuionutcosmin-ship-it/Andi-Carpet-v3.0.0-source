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
