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
