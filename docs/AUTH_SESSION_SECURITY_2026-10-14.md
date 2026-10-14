# AuthGate P1 — PR separat, Issue #31

## Mandat și bază

Autorizare expresă Issue #31, fără merge/deploy/APK/Firebase production/rules/config/versiune/migrări. Ramură fix/authgate-uid-session-isolation-20261014 din main **377f1fd5e73ae78a0df5cab58b09770c873cd167**, nu din #28. #28 rămâne c794c5d6d0252b4e9180ce6bbf16cd2aa455951d; #19/#20/#21/#29 HEAD-uri reverificate. Checkouturi anterioare curate, păstrate intacte.

Consultate documentele main ChatGpt/REGULI/ARHITECTURA/audit și auditul/checkpointul de identitate #28; nu se importă codul modularizării #28. Fixture Home este adaptat din test/support/home_sync_fixture.dart de pe #28 c794c5d, cu numai fakes/test rendering. Constructorii AuthGate/Home primesc SDK/effect inputs opționale pentru test; defaulturile și ordinea rămân identice. Nu se extrag query-uri sau module runtime din #28.

## Lot RED — înainte de corecție

Testele sunt acceptanță pozitivă (nu KNOWN DEFECT): A→B pending/profile error/null, State Home și listeners, ruta Navigator, logout/login, A→B→A cu callback A vechi, callback post-frame după dispose, inițializare reală FCM întârziată și GPS nativ întârziat. Control same UID/null/reconnect/error păstrează profil/rută. Streamurile/SDK-urile sunt strict sintetice, fără Firebase init/date live, GPS hardware, request HTTP ori token real.

Se folosește State Home real cu rendering substituit pentru a evita SDK acces secundar Dashboard/Documents. Profile UI pending și pagina Login sunt reale. FCM și GPS rulează metodele reale Home, cu SDK fake injectat/platform fake. Callbackul profil vechi este livrat adversarial după cancel pentru verificarea generației, nu presupunere despre livrarea normală a unui stream Dart.

Local: 107 Python, 3 Node și Functions syntax PASS; Flutter/Dart indisponibile. CI RED va trebui să demonstreze assertion failures relevante, cu toate testele compilabile și controlul same UID trecut. Nu se implementează corecția înainte de citirea rezultatului RED.


### Corecție fixture înainte de RED demonstrat

39398af4579afe39e6940901e28957121b7aa8c6 / CI 38515092462: patru joburi SUCCESS, Flutter compile failure (fake FirebaseMessaging.getToken omite serviceWorkerScriptPath), 41 pass/2 load failures. NU este dovada RED pentru P1. Semnătura fake este corectată; testele AuthGate rulează acum în AndiCarpetaApp reală, cu intrări SDK opționale și aceeași navigare/temă default. Adăugat dialog implicit root Navigator pentru a evita o reparație incompletă prin Navigator numai local. Corecția funcțională încă NU este aplicată.


## RED demonstrat — înainte de remediere

**51f864162dac73179c7f2dc54cf90df956363beb / CI 38515354927:** 42 Flutter PASS / 10 FAIL, fără compile/load errors. Cele 10 acceptance failures sunt exact: Pending Alice rămâne după B; B error/global rebuild arată Alice; State Home A încă mounted; route A persistentă; dialog A persistent; route A după logout; callback prima epocă A repopulează A nou; post-frame executat după dispose; token FCM scris după dispose; subscription GPS creată după dispose. Controlul same UID/null/reconnect/error și rute a TRECUT. Python/Node/Functions/emulator: celelalte **4 joburi SUCCESS**.

Acceptance file SHA-256 **e165bcd8b04227ff9b7cbb909baf419a9dc51d50838aef59a6070e9689397f67**. Fișierul și fixture-urile rămân byte-identice între RED și prima remediere GREEN; nu se schimbă aserțiunile.

## Lot de remediere — în curs de validare

AuthGate invalidează imediat profilul, erorile și ownership generation la UID diferit/logout. Profilul folosit la build trebuie să aparțină UID curent. Same UID cu currentUser valid păstrează fallbackul/streamul/profilul. Generație de profil + sesiune, mounted și SDK UID resping callbackuri vechi inclusiv A→B→A.

AndiCarpetaApp înlocuiește cheia Navigatorului ROOT numai la UID diferit/logout; astfel dispar și showDialog/root routes, nu doar Home. Callbackul raportează înlocuirea către vechiul AuthGate pentru a evita abonarea B inutilă înainte de noul Gate. Home primește ownership callback capturat pe generație, invalidat sincron înainte de dispose.

Se resetează exclusiv theme/fontFamily/personalBackgroundId la UID schimbat; branding/backgrounds globale/template/settings financiare/learning nu sunt resetate. Home verifică sesiunea la livrare stream, post-frame și după await înainte de operațiuni GPS/FCM/token write/subscription attach; montarea singură nu mai conferă ownership. Query-uri și formule financiare nemodificate; guard-urile UI existente din Home sunt îmbunătățite prin session guard.

Fără cod modularizat sau commituri #28 absorbite: cele trei fișiere runtime existente în main sunt editate punctual. Local 107 Python/3 Node/Functions syntax PASS; CI complet pe noul SHA urmează.

### Limite care nu trebuie ascunse

Nu se revocă retroactiv documentele pushTokens A deja stocate pe server și nu se garantează că o notificare FCM OS deja expediată pentru A dispare de pe dispozitiv. Curățarea/reatribuirea securizată a tokenurilor și recipient matching server-side necesită follow-up dedicat; rules/config/date production sunt intacte. Nu se șterge cache-ul persistent SDK și nu se anulează/rollback un write deja expediat. Maintenance/migrări administrative deja în curs și autorizarea server a altor colecții sunt riscuri separate, nu reparate automat de root reset. Testele acoperă SDK fake, fără Android/GPS/FCM hardware/live Firebase.


## GREEN demonstrat — aceeași suită

**ec6b389b194376a85f6975c75088c25b06b6cbdd / CI 38516118964 5/5 SUCCESS:** toate cele 10 acceptanțe anterior FAIL sunt PASS, controlul same UID PASS, **52 Flutter PASS**, build web PASS; 107 Python, 3 Node, 10 emulator financiar și Functions PASS. Fișierul acceptance și fixture-urile sunt byte-identice cu RED 51f8641, hash păstrat. Corecția P1 client este demonstrată pentru aceste scenarii; nu se declară securitatea întregului produs certificată.

## Lot regresii suplimentare

Șase teste noi fără schimbare runtime: same UID păstrează tema/fontul dar B resetează exclusiv personal și păstrează global; State Home echipă/decont A→B cu cache nou și cancel scope financiar A; sesiunea se invalidează înainte de frame/dispose și respinge snapshot personal vechi; FCM activ scrie owner corect/refresh apoi cancel; GPS activ se atașează normal și cancel; system Back funcționează normal în aceeași sesiune. Noul fișier importă doar helperii publici din suita de acceptanță, fără a modifica testele RED/GREEN. CI pe noul SHA urmează.


## Regresii validate și control suplimentar root chrome

4a770da00364c5a0eafff4f91a27070ff2c7f3f2 / CI **38516475803 5/5 SUCCESS**, **58 Flutter PASS**, build web PASS; toate cele șase regresii noi trec. Navigator root reset nu garantează singur că ScaffoldMessenger din MaterialApp pierde mesajele SnackBar private. Se adaugă un test de acceptanță suplimentar pentru SnackBar A→B, înainte de eventuala corecție a ownership-ului messenger. Nu este schimbat runtime în acest lot.


## RED/GREEN suplimentar — ScaffoldMessenger

**58724b34efb382dcd77a3875e02a0b3a2f0ab57f / CI 38516742854:** 58 Flutter PASS / **1 FAIL** exact SnackBar privacy assertion; alte 4 joburi SUCCESS. Textul «Private snackbar a» rămânea vizibil în loading B după resetarea Navigatorului. ScafoldMessenger aparține MaterialApp deasupra Navigatorului și păstra coada/mesajul curent.

Se înlocuiește și cheia ScaffoldMessenger pe același UID transition/logout, fără schimbarea mesagerului la same UID. Nu se folosește doar hideCurrentSnackBar cu animație/coadă reziduală. Mesajele și bannerele messenger sunt state ale sesiunii, spre deosebire de brandingul global. Testul SnackBar și acceptanțele originale sunt neschimbate. GREEN pe noul SHA urmează; până atunci izolarea întregii suprafețe testate nu este declarată finală.


## ScaffoldMessenger GREEN și auth stream error ownership

**72aca0102294c3938a8581ffcbbe9218906064c1 / CI 38516940394 5/5 SUCCESS**, **59 Flutter PASS**, build web PASS. Testul SnackBar anterior FAIL este PASS fără editarea testului; core acceptance file neschimbat.

Review-ul final verifică și calea auth stream onError: SDK currentUser poate indica UID B în timp ce streamul livrează o eroare; fallbackul profilului A nu este legitim în această situație. Se adaugă acceptanță pentru ruta A și control pozitiv pentru auth stream error cu SDK UID A neschimbat, fără modificare runtime în acest lot.


## Auth stream error RED și remediere

**cd2dc174d8dfe6d3cfd1d911b66aea47da79e79e / CI 38517375349:** **60 Flutter PASS / 1 FAIL**, exact SDK UID B + auth stream error păstrează ruta «Auth error private a»; alte 4 joburi SUCCESS. Controlul auth stream error cu SDK UID A neschimbat este PASS.

Handlerul auth onError reverifică SDK currentUser; dacă UID diferă (inclusiv logout), folosește _handleAuthChange pentru invalidare/root boundary și nu păstrează profilul/ruta precedente. Eroarea cu același UID păstrează fallbackul legitim. Testele sunt byte-identice cu RED; GREEN pe noul SHA urmează.
