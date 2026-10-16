# Vision — punte de widget către sesiunea reală, fără modificarea AuthGate

**16 octombrie 2026 · Shiva · numai Draft · munca Luna PR #55 neatinsă**

## Ce a fost verificat înainte

- PR #68 HEAD `617a1e8a013b4b5b20bc1e87c3e2d15c488efc59`: standard CI 5/5 (480 Flutter / 215 Python), Identity și compilare debug Android SUCCESS.
- `lib/auth/auth_gate.dart` conține `sessionIsCurrent` care validează `_sessionGeneration`, UID din profil, UID SDK, `mounted`. Callbackul este deja expus de `activeSessionPageBuilder`, deci nu este nevoie de modificarea acestei surse `part` protejate în acest lot.
- PR #55 al Lunei este candidat financiar separat, `production_ready=false`, fără integrare a noilor reguli în Home implicit; nu este modificat.

## Implementare

`lib/vision/vision_authenticated_session_scope.dart` adaugă `VisionAuthenticatedSessionScope`, widget care primește de la viitorul *caller autorizat* două condiții **independente**:

1. `sessionIsCurrent` este predicatul autoritativ AuthGate pentru UID **și** generație, NU un UID-only/flag UI.
2. `sessionEpochKey` este un obiect **unic pentru fiecare login/generație**; nu se reutilizează UID-ul sau un token static. Un `false` observat închide definitiv lease-ul **acelei epoci**. Numai o cheie de epocă nouă, însoțită de un predicat AuthGate valid, poate crea un jurnal nou.

La init se creează un lease strict RAM doar pentru owner valid; `didUpdateWidget` invalidează vechea epocă la token diferit, respectiv păstrează jurnalul numai dacă tokenul este identic și **vechiul** predicate încă validează. La `build`, predicatul se verifică din nou: `builder` primește `null` pentru orice sesiune neverificată. `dispose` invalidează coordonatorul; callbackurile întârziate nu mai pot scrie. Acest widget nu adaugă rută, nu pornește global telemetry, nu stochează UID, nu citește Firebase și nu persistă în cloud.

**Ce a fost evitat:** inițial un design fără token distinct ar fi acceptat un nou lease la tranziția `false→true` pe aceeași closure, deschizând posibilitatea unei reactivări greșite. Contractul a fost întărit înainte de validarea finală, astfel încât o epocă invalidată **nu mai poate fi reactivată** fără dovada explicită a uneia noi.

## Teste

- `test/vision_authenticated_session_scope_test.dart`: șapte widget teste cu owner autentic simulat: admitere, A1→B→A2, același UID cu generație nouă, rebuild benign fără pierderea istoricului, revocare monotonă chiar dacă callbackul revine `true`, logout/dispose cu callback întârziat și predicate throwing.
- `test/vision_authenticated_session_scope_contract_test.py`: cinci verificări de sursă pentru token distinct, fail-closed, absența transportului/storage/telemetry și contractul existent al AuthGate.
- Workflow `verify-vision-modular-android.yml` este activat pentru branchul nou, strict compilare Android debug pe `lib/main.dart`, fără distribuire ori deploy.

## Condiții obligatorii înainte de utilizare în aplicația finală

- **Nu este montat în Home, AuthGate, Navigator sau `main.dart`.** Încă nu există flux vizibil pentru utilizator și nici evenimente reale distribuite către lease; integarea de producție rămâne [Issue #63](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/issues/63).
- AuthGate curent nu exportă automat `sessionEpochKey` ca obiect; viitorul integrator trebuie să demonstreze generarea sa distinctă pentru fiecare auth epoch, mai ales același UID revenit. Folosirea `ValueKey(profile.uid)` **nu este suficientă**.
- Încă este necesară revocarea explicită `clear/revoke` și înlocuirea Navigator la logout, înaintea afișării altui utilizator. Dacă un callback este fals și revine adevărat **fără ca ownerul/hostul să observe falsul și fără un token nou**, nicio componentă de UI nu poate deduce singură ruptura de sesiune.
- Nu se deblochează jurnalul singleton `VisionErrorTelemetry.log`; datele lui vechi nu pot fi atribuite în siguranță utilizatorilor. Teste reale pe Android/iOS/Windows/web pentru lifecycle/offline și verificări pe arborele combinat sunt necesare.
- Zero citiri/scrieri Firestore noi, servicii plătite, polling, telemetry globală sau scripturi Firebase noi. Fără modificări la cele 116 hashuri, regulile de securitate, fișierele financiare, `main` sau producție.

**CI final:** verifică SHA, standard 5/5, Identity și integrated Android pe **același HEAD**; nu pretinde PASS din rapoartele PR #68. Status DRAFT / DO NOT MERGE.
