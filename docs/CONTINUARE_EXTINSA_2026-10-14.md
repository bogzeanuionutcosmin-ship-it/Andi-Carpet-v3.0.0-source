# Continuare extinsă PR #28 — misiunea 6163825575

Bază: b8ad0f87acb241000bba310948564aba8de1c01e. Loturile 10–24 și CI finalizat nu se repetă. Auditul de integrare 6163337665 rămâne baza recomandării viitoare #33 → #28 → #34, fără integrare în această misiune.

## Lot 25 — platforme GPS/FCM, numai fixture-uri

Opt teste noi execută init/dispose din State Home real, cu rendering substituit și plugin platforms înlocuite în test. GeolocatorPlatform caracterizează pornirea economică Android, servicii oprite, denied/request/refused, deniedForever, eroare stream/cancel și atașarea tardivă după dispose. FCM platform caracterizează denied/notDetermined/request, authorized null/blank token și provisional/getToken întârziat cu eroare. Firebase core este un mock Pigeon, fără proiect real. Nicio poziție, token util sau request HTTP nu părăsește fixture-ul.

KNOWN DEFECT: getPositionStream se poate atașa după dispose când service-enabled se rezolvă târziu; testul păstrează evidența comportamentului actual, nu certifică izolare. #33 are acceptanța de securitate și nu este portat aici.

Blocaj FCM rămas: tokenul util conduce la FirebaseFirestore.instance hard-coded; portul HomePlatformEffects înlocuiește efectul întreg, nu acel write. Testarea token owner/onTokenRefresh/getInitialMessage/onMessageOpenedApp cu scriere și navigare reale este NEEXECUTATĂ în acest lot. Nu adăugăm parametrii SDK sau sessionIsCurrent din #33. Success path GPS/liveLocations/reverse geocoding/hardware, delay250 de proximity boost și Web delay700 sunt NEEXECUTATE. Nici fakes nici emulatorul de autorizare nu certifică Android real sau cache SDK live.

Workflow identity primește numai cele două căi de teste, pentru validare pe SHA-ul lotului; configurația emulator/rules/job este neschimbată. lib/ și cele 116 hashuri protejate sunt intacte. Inventar: 197 Dart, 59 parts, 138 biblioteci totale, 77 independente în lib. 155 Python PASS local; Flutter/Dart indisponibile local, rezultatele CI se completează numai după execuție.

## Etapele următoare

Prima rulare 3c8b930 / 38533969624: patru joburi standard SUCCESS, identity 38533969678 SUCCESS; Flutter a rămas în unit/widget tests. Review-ul fixture-ului a identificat închiderea streamului tardiv așteptată fără pump în fake-async. Corecția este exclusiv test: închiderea este inițiată și evenimentul done este livrat prin pump, cu timeout60s pentru acest scenariu. Aserțiunile starts1/cancels0 după dispose rămân neschimbate; nu se prezintă această problemă de fixture drept RED funcțional. Noua rulare va avea SHA propriu.

2. AdminPanel: extrageri pure/proiecții fără writes; mixinurile State rămân.
3. Lifecycle: controle same UID/rebuild, registru KNOWN DEFECT și matricea de portare.
4. Dependențe: inventar și închidere explicită pentru biblioteci pure.
5. Backup: lacune failure/concurență, fără repetarea batches 8/300/350 deja acoperite.
6. Teste financiare/formatări prin API-uri existente, fără schimbare parser/politică.
7. Revalidare read-only #33/#34/#29 și conflicte la HEAD reale.
8. Checkpoint final și CI pe SHA exact; nimic neexecutat nu se declară verde.

Fără merge/deploy/APK/main/PR #33/#34/#29/producție/Firebase rules/data/config/billing/versiune.

### Corecție izolarea platformei în fixture

Logul Flutter disponibil după anularea primei rulări arată patru eșecuri de invariants: debugDefaultTargetPlatformOverride era resetat numai în tearDown, după verificarea bindingului. Resetarea este mutată în finally al fiecărui callback testWidgets, înainte de invariants. Prima rulare standard este CANCELLED (4/5 joburi SUCCESS, Flutter CANCELLED cu cele patru failures); identity SUCCESS. Corectivul 6cdd4b8 se înlocuiește cu acest corectiv înainte de verdict final. Sunt erori de fixture proprii, fără modificare lib/ sau slăbirea aserțiunilor.

47159c8 / 38534896652: standard 4/5 SUCCESS, Flutter FAILURE (timeout60s numai în scenariul de stream tardiv); celelalte șapte teste noi PASS. Resetarea platformei este validată. Curățarea este schimbată la anularea explicită a subscriptionului sintetic capturat; starts1/cancels0 înainte de această curățare rămân cerute. Nu se modifică Home sau presupune anulare runtime corectă.
