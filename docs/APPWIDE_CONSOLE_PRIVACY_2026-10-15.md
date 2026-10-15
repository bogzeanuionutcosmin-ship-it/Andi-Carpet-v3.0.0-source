# AndiCarpet — privacy logging (extindere aplicație întreagă) — 15.10.2026

**Proveniență:** PR #51 HEAD `bc058bc9c11f8fb249ee842bf45f50a3817ddc27`, care a reparat mesajele Home GPS/FCM/Learning și are CI verde pe HEAD. Ramură separată, fără modificarea #51, #50, #49 sau `main`.

## Audit sursă

Arborele GitHub al bazei #51 conține 681 intrări, inclusiv sursele Dart din `lib/`. Auditul manual programatic al apelurilor directe `debugPrint/print` din fișierele Dart a identificat încă **șase** expresii cu date necontrolate în trei module de geocodare și Learning:

| Fișier | Locuri identificate | Expunerea posibilă |
| --- | --- | --- |
| `lib/dashboard/dashboard_work_actions.dart` | viaServer / viaNominatim | text brut `$e`, în fallback și `$value` (nume/adresă căutată) |
| `lib/schedule/program_graph_actions.dart` | viaServer / viaNominatim | text brut `$e` și `$value` |
| `lib/schedule/program_route_learning_actions.dart` | read routing history / write routing choice | text brut `$e` la eșec de acces Firestore |

Această constatare este **audit de cod**, NU dovadă de exfiltrare, colectare într-un backend sau de logare pe hardware real. Jurnalul Vision local cu evenimente `area/code` este separat.

## Schimbare tehnică

Au fost înlocuite **doar cele șase mesaje controlate de aplicație** cu marcaje fixe, explicite: `dashboard_server_failed`, `dashboard_nominatim_failed`, `program_server_failed`, `program_nominatim_failed`, `routing_history_read_failed`, `routing_choice_write_failed`. Blocurile `catch` continuă să aibă aceleași returnări și efecte; variabilele de excepție devenite nefolosite sunt eliminate fără mutarea ori repetarea operațiilor.

**Nu s-au schimbat:** HTTP request URL/body, proxy, Firebase, geocoding source order, Learning logic, scoring route, permisii, autentificare, datele utilizatorilor, acces Firestore, diagrame, sume sau rularea GPS/FCM. Nu se adaugă transport de loguri, SDK sau servicii noi.

## Protecție permanentă

`test/appwide_console_privacy_test.py` adaugă **3** verificări descoperite automat de CI-ul standard:
1. TOATE apelurile `debugPrint(...)` din `lib/**/*.dart` acceptă numai un **literal fix fără `$`**, deci nu pot imprima direct UID, adresă din geocodare, token, excepție sau OCR prin interpolare. Testul este lexical și nu inspectează un transport indirect sau loguri OS/SDK.
2. Nu există `print(...)` direct ori `debugPrintStack(...)` brut în sursele Dart inspectate.
3. Cele șase marcaje de eroare există o singură dată în modulele operaționale așteptate. Testele privacy existente în #51 (Home), freeze și contractele Vision rămân active.

Nu modificăm hashurile altor fișiere protejate, nu dezactivăm vreo aserțiune și nu ștergem istoricul probei RED din #49.

## CI și continuare

PR Draft separat, neaprobat pentru merge/deploy. Verificați **HEAD-ul și toate workflowurile pe ultimul commit**, inclusiv standard 5/5, identity, Android debug build/metadata și numerele reale de teste. Compilarea APK în CI nu înseamnă publicare, instalare sau validare pe hardware.

**Separare de Luna:** Misiunea VII se desfășoară în #50 și nu este atinsă aici. După finalizarea acesteia, o eventuală integrare va necesita concilierea atentă a `ChatGpt` și a hashurilor `test/vision_hardening_freeze_test.py` din #50/#51; acestea nu sunt combinate acum. Finance SQL/Firebase rules, roluri, avansuri, billing, producție și release rămân interzise.

**Limitări:** nu putem pretinde absența tuturor excepțiilor sau stackurilor de la pluginuri/OS și nici confidențialitate absolută. Controlul se aplică doar apelurilor console directe din aplicație, iar o modificare viitoare poate necesita extinderea scannerului pentru alte API-uri de logging.
