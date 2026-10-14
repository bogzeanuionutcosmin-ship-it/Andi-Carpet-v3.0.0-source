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
