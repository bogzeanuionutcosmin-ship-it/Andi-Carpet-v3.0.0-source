# Misiune extinsă II — PR #28

Mandat: comentariul6164787480. Bază GitHub/local6851cd7b612e282b7b384446f61a711564658e38, standard38537913840 SUCCESS, identity38537913933 SUCCESS. Checkout nou curat; nu se repetă loturile25–27.

## A — Admin (lot29)

Două proiecții independente fără dependențe: compareAdminAccountData et adminAssignedFunctionIds. Substituțiile sunt inversabile byte-exact; main import/reexport compatibil. Comparator pending-first păstrează status explicit, name/email fallback și sort case-sensitive; assigned păstrează empty-list precedence, legacy fallback, toString, whitespace/null values și set independent. Nu stabilește autoritate sau drepturi.

Șapte teste Flutter noi:100perechi comparator/cazuri-limită, assignment legacy/list/aliasing și cinci widget tests AdminPanel real. Empty și inactive-only opresc dialogul; duplicate display names cu ID distinct, cancel fără/cu selectare;35membri scroll/select ultimul/cancel; edit funcție în dialog/cancel păstrează obiect original/rights. Sentry FirebasePlatform contează fiecare app access inclusiv exceptions înghițite. Cerem zero Firebase access, zero log/onChanged, roles/permissions intacte. Nu se certifică writes administrative/server authorization.

156 Python PASS local. Flutter/Dart indisponibile local; CI exact în curs după publicarea lotului, nu declarat verde anticipat. Inventar204Dart/59parts/145libraries/79independent lib, fără missing/orphan/duplicates/cycles. Cele116protected hashes intacte.

## B–F — rămase

B FCM: singleton Firestore în savePushToken/openChat; port opțional pushFirestore propus numai ca seam, fără modificarea algoritmului. SDK messaging fixture necesită refresh/initial/opened controllable. Guards #33 nu se portează.
C restore: Admin backup singleton/FilePicker; confirm dialog automatic precede orice DB access. Full restore non-atomic; partial snapshot, failure/retry/timeout/race necesită fixture acces la DB. Nu se inventează rollback.
D OCR: image_picker și recognizeTextFromImage hard-coded, private State/extension; saveExpense deja injectat. Harness trebuie să execute widget/form/save; regex-only nu se declară cap-coadă. Parserul rămâne protejat de mandat.
E: noi lifecycle scenarios/conversii numai dacă justificabile; FunctionDefinition importă Flutter pentru Color, nu se etichetează Dart pur.
F: reverificare read-only HEAD33/34/29, fără integrare/ref moves.

Fără merge/deploy/APK/main/PR33/34/29/Firebase production/rules/config/billing/versiune sau schimbări de comportament.

### Eșec inițial păstrat
20675e1/38541395111:223FlutterPASS/1FAIL,4alte standardSUCCESS;identity38541395031SUCCESS. Focused function editor cancel dispose controller înainte de reverse animation (runtime nemodificat). Testul cere eroarea exactă et whitelist numai cascade framework observate; zeroFirebase et drepturi intacte rămân obligatorii. Nu este remediere; KNOWN DEFECT explicit. CI corectiv urmează.
