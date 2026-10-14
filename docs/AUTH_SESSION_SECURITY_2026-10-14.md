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
