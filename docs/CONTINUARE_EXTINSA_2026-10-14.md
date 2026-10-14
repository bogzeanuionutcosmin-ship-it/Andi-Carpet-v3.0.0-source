# Continuare extinsă PR #28 — misiunea 6163825575

Bază: b8ad0f87acb241000bba310948564aba8de1c01e. Loturile 10–24 și CI finalizat nu se repetă. Auditul de integrare 6163337665 rămâne baza recomandării viitoare #33 → #28 → #34, fără integrare în această misiune.

## Lot 25 — platforme GPS/FCM, numai fixture-uri

Opt teste noi execută init/dispose din State Home real, cu rendering substituit și plugin platforms înlocuite în test. GeolocatorPlatform caracterizează pornirea economică Android, servicii oprite, denied/request/refused, deniedForever, eroare stream/cancel și atașarea tardivă după dispose. FCM platform caracterizează denied/notDetermined/request, authorized null/blank token și provisional/getToken întârziat cu eroare. Firebase core este un mock Pigeon, fără proiect real. Nicio poziție, token util sau request HTTP nu părăsește fixture-ul.

KNOWN DEFECT: getPositionStream se poate atașa după dispose când service-enabled se rezolvă târziu; testul păstrează evidența comportamentului actual, nu certifică izolare. #33 are acceptanța de securitate și nu este portat aici.

Blocaj FCM rămas: tokenul util conduce la FirebaseFirestore.instance hard-coded; portul HomePlatformEffects înlocuiește efectul întreg, nu acel write. Testarea token owner/onTokenRefresh/getInitialMessage/onMessageOpenedApp cu scriere și navigare reale este NEEXECUTATĂ în acest lot. Nu adăugăm parametrii SDK sau sessionIsCurrent din #33. Success path GPS/liveLocations/reverse geocoding/hardware, delay250 de proximity boost și Web delay700 sunt NEEXECUTATE. Nici fakes nici emulatorul de autorizare nu certifică Android real sau cache SDK live.

Workflow identity primește numai cele două căi de teste, pentru validare pe SHA-ul lotului; configurația emulator/rules/job este neschimbată. lib/ și cele 116 hashuri protejate sunt intacte. Inventar: 197 Dart, 59 parts, 138 biblioteci totale, 77 independente în lib. 155 Python PASS local; Flutter/Dart indisponibile local, rezultatele CI se completează numai după execuție.

## Etapele următoare

2. AdminPanel: extrageri pure/proiecții fără writes; mixinurile State rămân.
3. Lifecycle: controle same UID/rebuild, registru KNOWN DEFECT și matricea de portare.
4. Dependențe: inventar și închidere explicită pentru biblioteci pure.
5. Backup: lacune failure/concurență, fără repetarea batches 8/300/350 deja acoperite.
6. Teste financiare/formatări prin API-uri existente, fără schimbare parser/politică.
7. Revalidare read-only #33/#34/#29 și conflicte la HEAD reale.
8. Checkpoint final și CI pe SHA exact; nimic neexecutat nu se declară verde.

Fără merge/deploy/APK/main/PR #33/#34/#29/producție/Firebase rules/data/config/billing/versiune.
