# Modularizare identitate și servicii — PR #28 / Issue #30

## Contract de lucru

Continuare din HEAD validat, fără comportament nou. Regulile aprobate sunt registrul de referință, nu o listă de votat din nou. Nu se implementează Vision în acest PR și nu se integrează ramurile #19/#20/#21/#29. După modularizare urmează auditul diferențial cod/reguli, apoi Error Log și observabilitate reutilizând #19/#21.

## Limite inspectate

| Componentă | Dependențe și efecte | Separare sigură / limită |
|---|---|---|
| FirebaseUserProfile | User, DocumentSnapshot, UserFunction; fără I/O | Bibliotecă explicită. Factory și precedențe păstrate; lookup public partajat cu directory adapter. |
| QuickAccounts | SecureStorage const, cheie v1, JSON; parole locale | Următorul lot: storage injectat, format și opțiuni implicite neschimbate. Erorile read din plugin se propagă; JSON invalid revine la listă goală. |
| AuthGate | Auth/user/profile/settings streams, currentUser, lifecycle, UID guard | Adaptere numai după teste pentru ordinea streamurilor, reconectare, profil absent și dispose; nu modifica selecția paginii. |
| Firebase bootstrap | opțiuni platformă, fallback iOS nativ, background FCM entrypoint | Păstrează pragma, top-level handler și inițializarea lazy. Nu schimba config ori platform checks. |

## Lot 1 — FirebaseUserProfile

Clasa a devenit bibliotecă SDK independentă, re-exportată de main. Body equivalence verificată după `_functionFrom` → `functionFrom`; în directory sync se schimbă numai numele apelului. Nu se transformă datele aprobate în altă schemă și nu se schimbă drepturile. Teste directe cu User/DocumentSnapshot fake, fără app Firebase ori date live. Local 155 Python + 3 Node PASS, syntax/diff/inventar PASS. CI de identitate: d4d90a7796bb6899f8d9fac36e44db480d2ba82c / run 38482963824, **5/5 SUCCESS**.

Inventar: 161 Dart, 62 parts, 99 biblioteci. Acesta este inventar lexical; nu dovedește cod mort și nu înlocuiește teste de dispozitiv.

## Lot 2 — QuickAccountStore

Algoritmii și modelul devin Dart pur, cu I/O injectat prin trei callbackuri. Main păstrează pluginul, cheia/opțiunile și wrapper-ele existente; Settings califică numai tipul. Deduplicarea, limita la save, absența limitei la load, JSON/erori și apelul forget sunt păstrate. Teste în memorie cu date sintetice, fără stocare reală. Local 155 Python + 3 Node, syntax/equivalence/inventory/diff PASS. CI QuickAccounts: 0be4bce7d5054dc641b92f48dc7e6c94247438ac / run 38483520307, **5/5 SUCCESS**. Inventar 162/61/101.

## Lot 3 — politica de inițializare Firebase

Helper Dart pur pentru selectarea/acțiunile de inițializare; main furnizează predicate/acțiuni SDK lazy. VAPID și handlerul FCM cu pragma/gating rămân text-identice în biblioteca main. Configurația și ordinea main sunt păstrate. Teste pentru selecție, laziness, await și excepții fără retry/fallback. Local 155 Python + 3 Node, syntax/equivalence/inventory/diff PASS. CI bootstrap: 75279637b52cf588a26a6ec2d0a6d1a0b044e898 / run 38484010280, **5/5 SUCCESS**. Inventar 163/60/103.

## Resurse Vision existente — numai audit read-only

PR #19 la d4da2872a566eba258e82b8597c023e03ceb9b56 și #21 la d18b2523a31ead7eb65a04fe92a21276a4155c97 au deja Error Log, telemetry, Diagnostics și teste. #21 mai conține integrarea documentelor/offline smoke. Nu le duplicăm ori importăm în #28; după modularizare audităm implementarea și contractele pe acele ramuri înaintea extinderii. Acest inventar nu reprezintă acceptare pe dispozitiv/în producție.

## Lot 4 — AuthGateSources

Port callback read-only independent de biblioteca main, cu tipuri SDK explicite. Adapter default lazy în main, query-uri originale și metadata păstrate. Constructorul AuthGate permite surse opționale; state-ul fixează furnizorul la initState. Întregul body al state machine/lifecycle rămâne text-identic după înlocuirea expresiilor sursă. Nu este un bus Vision și nu adaugă observabilitate funcțională.

Teste widget de reconectare/pending/absent, UID switching/cancel, UI settings/duplicat/dispose și recuperare după eroare, folosind streamuri locale. Nu exercită încă HomePage activ, login/logout SDK sau autorizarea server-side. Local 155 Python + 3 Node, syntax/equivalence/diff/inventory PASS. CI AuthGateSources: 0414b6cdc7211bd5a95ff58664d97458b0111604 / run 38484621957, **5/5 SUCCESS**. Inventar 165/60/105.

## Pași următori după validare

1. Auditarea surselor de login și abonărilor Home după grupurile existente, înainte de mutarea stării. Fixture-uri pentru ordinea evenimentelor, UID și cancel; numărul de citiri/scrieri nu crește.
2. Nu se repară implicit token ownership, START concurent, badge_v2 sau restore non-atomic: sunt schimbări funcționale/securitate documentate separat.
3. Auditul diferențial final va marca aprobat+implementat / aprobat+neimplementat / parțial / clarificare tehnică / decizie nouă. Referințe: registrul existent și Issue #30; nu se reiau aprobările.
4. Vision Error Log/telemetry/Diagnostics din #19/#21 se inspectează și reutilizează în etapa dedicată; în #28 nu apar module Vision noi.


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
