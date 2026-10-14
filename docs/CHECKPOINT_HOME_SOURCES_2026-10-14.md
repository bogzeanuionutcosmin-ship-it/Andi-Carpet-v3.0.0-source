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
