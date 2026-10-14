# Checkpoint curent Home/Admin/identitate — PR #28


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


---

## Istoric — checkpointul precedent este păstrat integral

# Checkpoint Home sources — PR #28, 14.10.2026

## Rezultat și bază

Bază reală la începutul continuării: **6d5e417331c700ddb2e5b16481b128dfec26bf29**, CI **38493857756 5/5 SUCCESS**, checkout curat. Checkpointul transmis de proprietar a5892dbb era mai vechi: loturile 10–13 existau deja și nu au fost repetate. Reluare după întrerupere la **2026-10-14T03:06:26Z**, cu GitHub/local **8066e0c** și CI lot 15 încheiat; fără relansarea CI finalizat.

Start de măsurare al acestei continuări: **2026-10-14T01:10:20.075Z**. Ultima verificare a codului lot 16: **2026-10-14T03:11:58Z**, interval calendaristic **2h 1m 37.925s**, incluzând întreruperea conversației. Timpul activ și consumul de credite nu sunt măsurate. Durata până la ultima verificare a checkpointului documentației se raportează în răspunsul final, folosind același start; nu o confundați cu timpul activ.

## Loturi noi validate

| Lot | Commit final | CI | Flutter | Rezultat |
|---|---|---|---|---|
| 14. Fixture director/profil/înlocuiri A-B-A | fa6541042d9a14135dfd7ed7f6b756f0ee377b05 | 38494771474 | 166 PASS | 5/5 SUCCESS |
| 15. HomeIdentityQueries | 8066e0c5b1588cd9fc3cb9a0cca282c110f41465 | 38495164327 | 169 PASS | 5/5 SUCCESS |
| 16. HomeOperationalQueries | f6eaf325ba1dd5574c8e33ef42b581a8d97a32db | 38504724656 | 172 PASS | 5/5 SUCCESS |

Lot 14 inițial: **a2ba14055dc7a6f561e35cdb446fd55737a86d12 / 38494525784**, 165 Flutter PASS / 1 FAIL, celelalte 4 joburi SUCCESS. Presupunerea greșită era execuția imediată a callbackului post-frame. Corecția fixture verifică 0 callbacks înainte de scheduleFrame/pump și 1 după, inclusiv după reconectare. Nu s-a schimbat runtime, nu s-au slăbit controalele UID/cancel și nu s-au atins testele AuthGate KNOWN DEFECT. Rezultatul inițial rămâne documentat. Nu s-a trecut la lot 15 înainte de CI corectiv verde.

**9 teste Flutter noi**, trei per lot. Ultimul lot: **172 Flutter, 155 Python, 3 Node, 10 Firestore emulator PASS**, plus smoke Dart fără engine și build web. Local: 155 Python și 3 Node, Functions syntax/equivalence/diff/inventar PASS. Numerele sunt mărimea suitelor, nu suma artificială a execuțiilor repetate în CI. Flutter/Dart nu sunt instalate local. Fără Android end-to-end, Firebase live sau certificarea tuturor paginilor Home.

## Porturi și invariante

HomeIdentityQueries: users/uid pentru profil propriu, users pentru director admin și memberDirectory pentru membru. Home păstrează guard-ul !isAdmin la listenerul profilului, filtrele de vizibilitate, fallback cont propriu, membership și financial refresh. HomeOperationalQueries: teams/cars/locations/schedules/records, aceleași query-uri GLOBALE. Nu s-au adăugat filtre pe echipe sau alte schimbări de acces. Testul canEditTeam caracterizează verificarea client existentă, nu autorizarea server-side.

Ambele adaptoare sunt query-only, fără snapshots/listen/read/write/retry/polling, UID/profil/rezultate memorate ori cache nou. Constructorul HomePage păstrează compatibilitatea prin parametri opționali. Snapshots, callbackuri, sortări/cache-uri, seed/admin/auto-close, ordinea inițializării și anularea listenerelor rămân în Home. Cele două substituții identitate și cele cinci substituții operaționale permit reconstrucția byte-exactă a modulelor anterioare, inclusiv efectele secundare. Fișierele financiare nu sunt modificate în această continuare.

Fixture State Home real înlocuiește numai rendering-ul, pentru a evita I/O Dashboard/Documents. Scenarii noi: hidden admin/director/nickname/own fallback și limite echipă; own profile null/error/reconnect/post-frame/UID străin/dispose; keyed A-B-A cu exact 42 cancel pentru trei stări; query căi și laziness, sources independente/cancel; wiring porturi în ordinea originală; cinci erori operaționale cu date păstrate și reconectare fără duplicate.

## AuthGate și confidențialitate — P1 confirmat, nereparat

Dovezile din loturile 10–11 rămân valabile și testele KNOWN DEFECT trec în suitele noi: după auth A -> B, profilul/UI A poate rămâne până la snapshot B; eroarea B este ignorată cât există profil A. State Home real, tabul, datele deja încărcate și listenerul users/A rămân active în acel interval. Ruta A împinsă în Navigator poate supraviețui chiar și după profil B. Cancel standard Dart respinge evenimentele vechi în fixture; aceasta nu este o garanție pentru toate efectele async/platformă.

Impact: retenție/afișare client cross-account, inclusiv pe dispozitive comune; durata poate rămâne nelimitată până la un snapshot B reușit. Nu există din aceste teste dovadă de bypass Firestore Rules sau acces server-side neautorizat. CI verde de caracterizare NU înseamnă izolare corectă. Înlocuirile keyed din lot 14 testează starea după înlocuire, nu intervalul AuthGate defect.

Corecția propusă: invalidare atomică profile/identity state și unmount Home A la UID realmente diferit, loading B, fallback de reconectare numai pentru același UID, graniță de sesiune Navigator și audit async GPS/FCM. Necesită **aprobare expresă pentru PR funcțional/de securitate separat**, conform mandatului proprietarului. Nu este aplicată în PR #28. Acceptanța viitoarei corecții trebuie să ceară absența datelor A înainte de snapshot B, la eroare B, logout și pe rute push. Raportul detaliat: docs/AUDIT_IDENTITATE_LIFECYCLE_2026-10-14.md.

## Inventar și protecții

**188 Dart = 134 lib + 53 test/support + 1 script; 59 parts, 129 biblioteci totale, 75 independente în lib.** Snapshot docs/DART_DEPENDENCIES_2026-10-13.json regenerat și comparat integral cu o regenerare. Fără missing targets, orphan parts, duplicate declarations sau import/export cycles detectate. Audit lexical, nu dovadă de cod mort. Numărul parts nu a scăzut: progresul acestui mandat este infrastructura de test și separarea surselor, nu zero parts forțat.

Zero diff față de baza reală 6d5e417 în finance/home_financial_sync, PDF/reports/documents/download, OCR, map/Mapbox, assets, Functions, workflows, pubspec și Firebase rules/config/teste emulator. Main rămâne 377f1fd5e73ae78a0df5cab58b09770c873cd167. PR-uri protejate, HEAD-uri reverificate neschimbate: #19 d4da2872a566eba258e82b8597c023e03ceb9b56; #20 8ae220b41b5e9c1648151606f9443ba8fa68a90a; #21 d18b2523a31ead7eb65a04fe92a21276a4155c97; #29 545e0202755a8ee86a7b3406adccd469aac84f9e.

Numai ramura PR #28 actualizată; arborii GitHub/local comparați înainte de sincronizare, HEAD remote verificat înainte de update. Fără merge/main/deploy/APK/publicare web/date Firebase producție/rules/config/billing/migrări/versiune ori Vision duplicat. Acest checkpoint de documentație are CI propriu, verificat înainte de raportul final; SHA/run exact vor fi în descrierea PR pentru a evita autoreferința la propriul SHA.

## Următorul checkpoint

1. Verifică HEAD/CI real și acest raport; nu repeta loturile 10–16 sau CI încheiate. LoginPageView este deja separată.
2. P1 UID/Navigator: așteaptă aprobarea expresă pentru corecția pe PR separat; nu o aplica tacit în modularizare.
3. Continuă fixture settings/audit/admin/seed/maintenance, cu efectele documentate și fără suprimarea lor pentru un verde artificial; apoi porturi query-only limitate. Auditul admin ca State real încă nu este complet.
4. Caracterizează preferințele AppSettings comune root între conturi și callbackurile post-frame deja programate la dispose. Riscurile GPS/FCM late init/token ownership, reconectare/cache SDK real, finanțe/scope/generații și protecția backend rămân deschise.
5. Riscurile istorice START concurent, badge_v2, restore non-atomic și OCR/permisiuni nu sunt reparate de aceste porturi. Nu muta stările financiare/GPS/FCM fără fixture-uri suficiente.
6. Modularizarea integrală și auditul diferențial complet al regulilor rămân în lucru. Regulile/Issue #30 nu se reaproba. Vision/Error Log existent pe #19/#21 se reutilizează în etapa dedicată, fără implementare nouă în #28.


## MOD-HOME-BACKUP-BATCH-FIXTURES-20261014 — lot 22

Reluare exactă din GitHub/local c794c5d6d0252b4e9180ce6bbf16cd2aa455951d, CI 38511071554 5/5 deja încheiat. Loturile 10–21 nu se repetă. Checkout nou curat; checkouturile istorice, inclusiv modificările nesalvate, sunt păstrate intacte.

Patru teste Flutter noi cu State Home real/rendering substituit, strict sintetice: backup 17 documente users/teams cu ID-uri repetate între colecții, payload nested/Timestamp/null și batches 8/8/1; eșecul celui de-al doilea batch păstrează primul batch și nu marchează automatizarea ca reușită; retenție 601 notifications și 301 backup items cu batches 300/300/1 și 300/1, items înainte de parent inclusiv backup gol; failure retention păstrează parent și nu citește următorul backup/nu face retry. Fake separă commitAttempts de commits reușite și permite eroare controlată înainte de commit; fără schimbare runtime lib/.

KNOWN DEFECT nou caracterizat: documentCount al backupului failed numără documente încercate (16) deși numai 8 sunt confirmate în fixture; primele items rămân fără rollback. Este comportament preexistent, NU reparat și nu dovadă de integritate a restaurării. Eșecul retenției poate lăsa un backup parțial purjat, cu parent păstrat. Fixture-ul simulează reject înainte de commit; nu certifică ambiguitatea network/SDK după commit server.

Local: 155 Python PASS, inventar 193 Dart/59 part/134 biblioteci totale/76 independente lib fără missing/orphan/duplicates/cycles. Flutter/Dart indisponibil local; CI standard plus identity emulator pe SHA lot se verifică înainte de următorul lot. AuthGate P1 și riscurile GPS/FCM/post-frame/settings/badge_v2 rămân NEREPARATE în #28. Fără modificări de producție, merge/deploy/APK/versiune, migrări reale sau PR-uri protejate.


## MOD-HOME-RETENTION-QUERIES-20261014 — lot 23

Lot 22 38eeae632f676442a4ff829d079fbf6982ed721a validat: CI standard 38524869964 5/5 SUCCESS plus identity 38524869959 SUCCESS. Toate cele patru teste noi de batch/failure au trecut; runtime lib/ a rămas byte-identic bazei c794c5d.

HomeRetentionQueries este bibliotecă SDK independentă query-only: notifications/backups, where createdAt isLessThan Timestamp furnizat explicit. Nu calculează timpul, nu schimbă clamp 1..365, nu adaugă order/limit/get/listen/write/cache/retry. Home calculează în continuare cutoff la același punct, face get, șterge în batches300 și șterge parent după items. Cele două substituții query și directivele main inversate reconstruiesc byte-exact fișierele anterioare. Nu se schimbă API-ul HomePage, ordinea sau ownershipul maintenance.

Trei teste Flutter noi pentru lazy query/no I/O, Timestamp exact/filtru strict, două DB independente/re-read fără cache și eroare propagată fără retry/write. Fixture strict înregistrează și cutoff-ul. Cele 11 teste State Home Admin/maintenance validează wiringul real și limitele 8/300, inclusiv caracterizările KNOWN DEFECT păstrate.

Local 155 Python PASS, diff/equivalence/inventar PASS. Inventar 195 Dart = 136 lib + 58 test/support + 1 script; 59 part, 136 biblioteci totale, 77 independente lib; fără missing/orphan/duplicate/cycles. CI standard plus identity pe SHA lot urmează; nu se avansează până la verde. AuthGate P1, GPS/FCM și riscurile de backup/migration existente sunt NEREPARATE. Nicio producție, merge/deploy/versiune sau PR protejat modificat.
