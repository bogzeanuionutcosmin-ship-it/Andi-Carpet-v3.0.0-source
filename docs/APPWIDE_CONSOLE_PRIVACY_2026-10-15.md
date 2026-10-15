# AndiCarpet — privacy console beyond Home: Dashboard fix / Routing known unsafe (15.10.2026)

**Proveniență:** PR #51 HEAD `bc058bc9c11f8fb249ee842bf45f50a3817ddc27`, cu reparația Home validată. PR Draft nou pe ramură proprie, fără modificarea #50/#51/#49/main.

## Audit read-only al surselor

Arborele de bază verificat conține 681 intrări GitHub. Au fost inspectate apelurile directe `debugPrint` și `print` din fișierele Dart din `lib`. Au fost identificate **șase** mesaje necontrolate, în trei module:

| Modul | Probleme din sursa de bază | Decizie |
| --- | --- | --- |
| `lib/dashboard/dashboard_work_actions.dart` | 2 × `$e`, dintre care una și `$value` cu adresă/nume căutat | **REPARATE** punctual |
| `lib/schedule/program_graph_actions.dart` | 2 × `$e`, dintre care una și `$value` | **RĂMASE KNOWN UNSAFE** |
| `lib/schedule/program_route_learning_actions.dart` | 2 × `$e` la Firestore read/write | **RĂMASE KNOWN UNSAFE** |

Aceasta este dovadă de **sursă**, nu că datele au ajuns în backend ori că au fost observate efectiv pe un telefon.

## Corecție efectivă, limitată la Dashboard

Au fost înlocuite numai două mesaje din `lib/dashboard/dashboard_work_actions.dart` cu:
- `[geocode] dashboard_server_failed`
- `[geocode] dashboard_nominatim_failed`

Au fost eliminate doar variabilele de excepție nefolosite în aceste două blocuri `catch`; căile HTTP/Firebase, autentificarea, ordinea server → Nominatim, parsing, rezultat returnat și UI rămân nemodificate. Nu există nou transport, stocare sau serviciu cu plată.

## Restricție de integritate identificată în CI

Inițial am înlocuit și cele patru mesaje din două module `schedule`. **CI Python a respins acele modificări**, deoarece ambele module sunt incluse în manifestul imutabil `docs/ROUTING_PDF_PROTECTED_2026-10-13.json` cu **116 SHA256 protejate**:
- `program_graph_actions.dart`: SHA256 obligatoriu `0ad775da6ee079bca134bf0ef126a3d0a4cfe8f8ba3d6dcf256192931a6a2f35`
- `program_route_learning_actions.dart`: SHA256 obligatoriu `61a4c3544ead87343ef1ec04cefea81d689dcb6fb421cd80c4ad987274635145`

**Am restaurat ambele surse byte-identic la baza #51**. NU am schimbat manifestul, nu am dezactivat tests/freeze, nu am schimbat algoritmul Grafic/Learning. Cele patru loguri nesanitizate **nu sunt reparate** și necesită o autorizare distinctă de schimbare a surselor protejate, cu justificare old/new și verificare completă.

## Protecție automată

`test/appwide_console_privacy_test.py`, descoperit de suita Python standard, are **5 teste** (3 controale de bază + 2 probe adversariale pentru scanner):
1. Enumeră toate apelurile `debugPrint` din `lib/**/*.dart`, cere literal fix fără `$`, **cu exact patru excepții explicite `KNOWN_UNSAFE_ROUTING`**, fiecare legată de sursa și textul original. Orice caz nou din afara allowlistului eșuează. Cele patru rămân numărate și vizibile, **nu sunt numite GREEN privacy**.
2. Respinge apeluri directe `print()` și dumpuri `debugPrintStack()`.
3. Verifică cele două coduri constante noi Dashboard.

Acestea sunt **contracte de sursă** (nu un parser Dart complet și nici un test al logurilor native OS/SDK). Testele existente PR #51 pentru Home, `VisionErrorTelemetry.report`, `vision_hardening_freeze` și `routing_pdf_boundary_test.py` rămân obligatorii. Nu modificați răspunsul așteptat doar pentru a masca un eșec.


### Hardened scanner, fără modificări runtime

Verificarea lexicală a fost întărită după primul CI GREEN pe baza de cod:
- `KNOWN_UNSAFE_ROUTING` este acum verificat cu **`Counter` și exact o apariție per pereche (fișier, expresie)**; o a doua interpolare cu text identic nu mai poate trece prin deduplicarea accidentală a unui `set`.
- Literele fixe sunt verificate cu expresie întreagă `fullmatch`, în locul unui simplu început/sfârșit de ghilimele. Astfel, `'prefix' + privateValue + 'suffix'` este respins, chiar dacă începe și se termină cu ghilimele.
- Sunt executate două probe sintetice ale scannerului: respingerea dinamicii (`$uid`, `$value/$error`, concatenări și expresii), respectiv a unui al doilea apel brut duplicat în sursa protejată.
- Aceste teste **NU repară cele patru excepții cunoscute**, nu simulează date reale și nu deschid canale noi de logging. Niciun fișier Dart, manifest de protecție, regulă Firebase sau workflow nu a fost schimbat în această întărire.

## CI, independență și limite

- Runul inițial al PR-ului pe modificarea intermediară a arătat **3 teste privacy noi PASS, dar 2 erori SHA256** pentru `schedule`; acestea au determinat revert, nu modificarea manifestului. **Nu raportați runul inițial ca verde.**
- Pentru HEAD final verificați standard CI 5/5, Identity, Android real compile-only. Fără APK instalat/publicat, Firestore producție, date reale sau billing.
- Luna lucrează autonom în Issue #48 / PR #50. Nu am editat această ramură, nu am integrat PR #50 și nu am intervenit asupra comportamentului financiar sau asupra ACL backend.
- Orice combinare cu #50 necesită review al `ChatGpt`, al hashurilor freeze și rularea CI pe tree combinat, nu presupunerea că două PR-uri verzi sunt automat compatibile.

**Nicio modificare de producție, merge, deploy, publicare APK/web, cost nou sau schimbare de permisiuni.**
