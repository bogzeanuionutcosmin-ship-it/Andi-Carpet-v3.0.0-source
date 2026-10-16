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

34f9b65 / 38535367840: același timeout60s izolat, 4/5 standard SUCCESS. Se păstrează verificările și se adaugă marcaje de fază ale fixture-ului pentru localizarea exactă a await-ului; cancel sintetic este inițiat fără await și pompat. Verdictul lotului încă NEVALIDAT până la CI verde.

## Lot 25 validat / lot 26 AdminPanel

2f2424592e7cd773d90b14f1178bcd10e996dfe9 / standard38535788487 5/5 SUCCESS, identity38535788576 SUCCESS. Suitele Flutter și build web/smoke Dart au trecut; numărul exact se preia din logul final. Marcajele de fază au permis încheierea curățării subscriptionului prin cancel inițiat și pump; aserțiunile defectului rămân intacte.

Lot26 extrage exclusiv proiecția destinatarilor activi în admin_member_projections.dart: același where(active), toList, sort lowercase, fără deduplicare/trim/modificare roluri. Main re-export păstrează accesul; Admin dialog/send/write/log/cancel este neschimbat. Inversarea substituției și eliminarea directivelor noi reconstruiesc byte-exact sursa bazei. Patru teste: filtre/ordinea/referințele/lipsa mutației, empty/duplicate/equal names, funcții profesionale distincte de role și dialog AdminPanel real cu select-all/cancel fără trimitere. Nu se certifică autorizarea server-side. Cele 13 parts Admin rămân pentru State/context și writes; niciun mixin nu este forțat.

## Lot 26 validat / lot 27 consolidare nonintruzivă

7e4ed074b22f9044729d0ecca0e1a3ed65e6c554 / standard38536190848 5/5 SUCCESS, identity38536190871 SUCCESS. Nicio schimbare de drepturi/writes; testul de dialog real a trecut.

Lot27 adaugă șapte teste Flutter și un contract Python: 12 rebuilds same UID/key păstrează State/tab/date/listeners/efectele; pierderea echipei anulează patru listeners și golește finanțele; parserul v2 pentru 200/200.00/200,00 și respingerea grupărilor de mii (comportamentul actual), precizie1ban/avans fără pending-as-paid; codec backup cu marker necunoscut/container independent și marker cunoscut invalid; două query reads simultane se încheie în ordine inversă fără cache/write. Proiecția Admin are dependency closure Dart pur fără SDK/Flutter/main/part. lib/ este byte-identic lotului26. Nu se modifică politica financiară, parserul OCR sau restore.

Etapa3 lifecycle și etapa4 dependențe sunt avansate prin probele de mai sus; matricea de portare se livrează în checkpoint. Etapa5 este PARȚIALĂ: codec și query race, fără restore UI/commit ambiguu/concurență migrare/backend cache live. Etapa6 este PARȚIALĂ: helper monetar v2, nu dialogul privat Expense și nu certificare OCR→Firestore. Unknown schema păstrată în codec nu înseamnă acceptarea ei la restore. Caracterizările AuthGate P1, settings tardive, maintenance și badge destructive rămân intacte.

## Checkpoint final de cod și starea celor opt etape

| Etapă misiune | Rezultat efectiv | Rămâne explicit NEEXECUTAT |
|---|---|---|
|1 GPS/FCM|8 platform SDK tests, inclusiv GPS tardiv KNOWN DEFECT; CI verde lot25|token util/save/refresh/initial/opened success, GPS write/geocoding/proximity250/Web700/hardware|
|2 Admin|proiecție pure +3unit/1dialog real cancel; CI verde lot26|edit/disable/delete/assign conturi/funcții, writes și erori UI reale|
|3 Lifecycle|sameUID12rebuilds +team-loss/cancel; registry și matrice transplant|cache SDK persistent, context/rute și fiecare await pe toate paginile; #33 neportat|
|4 Dependențe|closure pur proiecție, inventar complet fără cicluri/directive duplicate,78independente|cod mort neconfirmat nu este șters;59parts State păstrate|
|5 Backup|unknown/invalid marker și deep containers; overlapping read order|restore UI/parțial/timeout/commit ambiguu/migration concurrency/rollback/backend live|
|6 Contracte/teste|200 variante/grouping rejet/1ban/avans/pending,156Python și protected hashes|dialog privat Expense și OCR→Firestore cap-coadă|
|7 Integrare read-only|4perechi merge-tree, SHA-uri și audit distinct/matrice completă|arbore combinat și CI de integrare, orice merge|
|8 Continuity|ChatGpt/audit/inventar/checkpoint și PR la SHA final|niciun lucru promis în fundal|

Lot25 final2f24245/38535788487 +identity38535788576:206 Flutter. Lot26 7e4ed07/38536190848 +identity38536190871:210 Flutter. Lot27 **8ae3b4c4f51c7d2385a72a0ef9bbe6ab9aadd342 /38536842858 +identity38536843047:217 Flutter**,156Python,3Node,smoke Dart/build web PASS. Emulator counts se raportează după citirea logurilor. Sunt19Flutter și1Python noi față de b8ad0f87. Checkpointul de documentație se validează pe SHA propriu și se raportează în PR.

200Dart=137lib+62test/support+1script;59parts,141libraries totale,78independente lib. Regenerarea inventarului și116 hashes PASS. Runtime diff față de b8ad0f87 numai admin_member_projections.dart, o expresie recipients în communications și directive main; restul lib byte-identic. Testele financiare protejate/fișierele OCR/PDF/assets/rules/config sunt intacte.

**Pas precis de reluare:** citește SHA/CI actual și acest raport, nu repeta loturile25–27. Extinde AdminPanel UI read-only/cancel/projections cu porturile existente; pentru token-write FCM, restore și mutații private documentează ce seam suplimentar ar fi necesar înainte de schimbare. Nu adăuga sessionIsCurrent/protecțiile #33 sau hook-urile Vision fără mandat de integrare separat. Prioritizează noi fixture-uri fără live I/O, apoi biblioteci clar independente; dacă private State blochează, treci la următoarea componentă sigură. Reconfirmă #34 aflat în lucru în altă sesiune.

Main rămâne377f1fd;#33 a5f43ef și#29 545e020 neschimbate;#34 a avansat extern, auditul este pinned4fea0e8. Checkout #28 curat/sincronizat la finalul codului; documentația are CI propriu înaintea încheierii. Fără merge/deploy/APK/main/PR33/34/29/producție/Firebase rules/data/config/billing/versiune.
