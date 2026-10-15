# MISIUNEA VI — Vision/AuthGate hardening

Issue #39. Noua ramură `hardening/vision-authgate-v1-20261015`, din #38 `7a87d1d1d8bd7e1315cefa2d716832baca9c6679`, tree `3304deb0334f8a79205e983a25aeba97ecd2c97c`. Draft TEST/HARDENING DO NOT MERGE; base main numai pentru CI.

## Proveniență / preflight

#28 fd602ed, #29 545e020, #34 d84641b8a0ed719e61d9d48e150889febe673e9a, #35/#36 b2b1314 și main 377f1fd au fost verificate live. Nu exista altă ramură hardening. Checkout #38 curat. Sursele rămân nemodificate. Misiunile III–V nu sunt repetate.

## Lot 1 — coalescing local

Sursa read-only #34 folosește `_draining` și `_requestedRevision`, dar scrie din nou după fiecare flush succesiv fără schimbare și nu drenează un eveniment nou fără alt flush. Implementarea selectivă păstrează un singur Future activ, așteaptă restore, înregistrează snapshotul reușit și include revizia nouă apărută în timpul write. Un snapshot identic salvat nu este rescris; TTL poate produce un snapshot diferit chiar fără nou changed(). Failure same-revision oprește drain-ul; retry numai la flush explicit, fără timer/polling/rețea nouă. Formatul/cheia/statusul sunt păstrate.

Șase probe noi: 1200 flush-uri în spatele read → un snapshot; write blocat +1200 cereri → două snapshoturi; eveniment în timpul write fără alt flush → inclus; failure/retry aceeași revizie; TTL fără changed; late failure + revizie nouă → recovery final. Testele existente păstrează encode throw, read failure, pending/saved, restore merge și serializarea.

Înainte: fiecare apel flush al sursei #38 adaugă `.then` și o scriere (1200 apeluri → 1200 operații, concluzie statică, nu benchmark pe hardware). După: numerele 1/2 sunt asserted în teste deterministe și se raportează executate numai după CI.

Workflow-ul Android existent, neprotejat, acceptă în plus noua ramură izolată. Același entrypoint real, fără upload/install/deploy/config/secrets.

Local 167 Python PASS; Flutter/Dart nu sunt instalate local. CI pe commitul lotului este obligatoriu înainte de următorul lot publicat.

## Reluare

Lot 1 GREEN. Lot 2 pregătit, CI urmează; loturile 3–10 nu sunt încă publicate în acest checkpoint. Hardware/login Firebase/GPS/FCM/cameră/Keystore reale NEEXECUTATE. Fără merge/deploy/APK/web/producție/finanțe/roluri/paid AI.

## Validare lot 1 / PR #41

Commit 08492f64f5f4b8544d1bc151de8e39227f43bf88, tree ecacc77fbb7e8e09f6de12692da6a881103f8af5; merge-ref 70e57c245e096d0751a022f11d2de04a1f724d58 are exact același tree. Standard 38661750066 SUCCESS 5/5 (408 Flutter, 167 Python); identity 38661750070 SUCCESS 5 teste; Android 38661750057 SUCCESS, 134 teste + lib/main.dart debug compile. Logurile checkout verificate, plus git fetch merge-ref tree. Cele două bursturi sunt efectiv PASS, nu doar analiză.

## Lot 2 — presiune / retenție / ceas

Șase teste noi în vision_pressure_test.dart: 10000 duplicate/one drain/one snapshot; 150 amprente + mix resolved/severity; 48-char identifiers cu byte eviction; TTL exact șapte zile și NTP -30s/-2min la cold restore; input invalid ~2,6MB fără raw leak; count saturat și resolve/reopen. Politica de ceas existentă elimină evenimentele peste 1min în viitor: testăm limita, nu promitem păstrare peste rollback arbitrar. Zero runtime diff în acest lot. Numere/CI se completează după rulare; nu este benchmark hardware.

### Corecție de fixture lot 2

La revizuirea testului maximal-identifiers am observat că 150 rânduri valide maxime încap în 48 KiB; nu este corect să cerem eviction de bytes la această combinație. Proba folosește acum o limită injectată mai strictă, 4096 bytes, și identificatori exact48, păstrând toate assertions de cap/severity/restore. Limita de producție 48KiB/150 este în continuare verificată separat. Nu schimbăm runtime sau politica pentru a satisface o presupunere greșită de test. CI inițial/correctiv sunt raportate separat după observare.

## Lot 2 GREEN / lot 3 sécurité multi-compte

Lot2 final 6ee5b257954fd573005defe393b1fa608b9f5bfe, tree908fc831fa307eb766e528e0af2b8166ff1c4d5c. Standard38662610600 SUCCESS5/5, 414Flutter/167Python, identity38662610626 SUCCESS5tests. Flutter checkout5265e8e; merge-tree verificat separat. Prima rulare38662503072 a fost anulată la publicarea corecției de fixture; nu există dovadă RED comportamentală revendicată. Android test-only38662610691 era încă în build la trecerea la următorul lot; numai lot1runtime este deja certificat Android, iar finalul va cere propria compilare.

Lot3: patru teste noi, trei platforme-simbol (android/web/windows) × cold restore al jurnalului device-wide + write-failure/RAM fallback, cu root AuthGate real și loginB; rebuilduri repetate nu afișează/copiază istoricul și nu șterg cache. Nu sunt rulări engine-web/windows sau hardware. Testul epocilor capturează callbackul Clipboard în A1, parcurge A→B→A2, invocă acel callback și cere zero copieri; copierea legitimă A2 funcționează. Ownership este closure-ul UID+epoch real, nu un bool substituit. UI numai test, nicio rută nouă runtime. CI lot3 urmează.

### Lot3 fixture RED / corecție

acff78e, standard38662978602:417PASS/1FAIL, numai TypeError RawTooltip→IconButton în testul nou care capturează callbackul. Cele trei cold-cache și cele414anterioare PASS; identity38662978613 SUCCESS. Corecție exclusiv finder: selectăm direct IconButton după tooltip, nu RawTooltip returnat de byTooltip. Assertions/fluxul/runtime neschimbate. CI corectiv urmează, nu declarăm GREEN anticipat.

## Lot3 GREEN / lot4 bootstrap-lifecycle

Lot3 corectiv b235f48466ba0e0f8222e56c8a0ea28cefa31543 / tree184d33416e1c4e9fcead34da980ddcb1d7406532. Standard38663228002 SUCCESS5/5, 418Flutter/167Python; identity38663227995 SUCCESS5. Runtime neschimbat; Android final va recertifica toate testele noi.

Lot4: două probe noi pe bootstrap real/porturi și persistență reală/lifecycle. Storage read blocat/eșuat, start dublu cu un singur read, handlers Flutter/async lipsă (presentError păstrat, false pentru async), Firebase init failure propagat exact și o singură încercare, fără a aștepta storage. Storm100×lifecycle share-one-drain; saved numai după write, detach fără schimbare nu multiplică snapshoturi. Kill rămâne best effort. Fără schimbare runtime. CI lot4 urmează.

## Lot4 GREEN / lot5 SDK epoch ownership

Lot4 bfa9dcc4af67bfc48694d56a302be68d8fc8792c / tree968d11eb407bb7b872da8250ae0c069b856ddadc. Standard38663598978 SUCCESS5/5,420Flutter/167Python; identity38663598984 SUCCESS5.

Lot5: șase widget tests noi pe State Home și closure UID+epoch AuthGate reale, cu plugin/effect boundaries fake. FCM A blocat la permission/requestPermission/getToken, B token+refresh legitime și eroare refresh observată o dată; A1 nu scrie/atașează nici după A→B→A2. GPS A blocat la service/checkPermission/requestPermission, B stream legitim și un cod constant la eroare; zero late attach A, cancel B exact. Fără token/poziții reale, fără HTTP/Firestore live, zero praguri sau runtime schimbate.

Limite dinamice explicite lot5: reverse-geocoding HTTP, boost250 și Web700 nu sunt executate de aceste șase probe. Sunt verificate în sursa înghețată (guard după await / revalidare la intrarea metodei). Fluxul live-location încă folosește HTTP și Firebase singleton direct; este necesar un fixture separat pentru a demonstra aceste subcazuri fără I/O, nu schimbăm fluxul operațional în această misiune. Fără certificare hardware/backgroundOS sau revocarea writes deja expediate. CI lot5 urmează.

### Lot5 cleanup corectiv / infrastructură

9bd6f97, standard38664031459:420PASS/6FAIL, exclusiv foundation debug-variable invariant după corpul testelor. Scenariile au parcurs assertions, dar addTearDown reseta platform override după verificarea Flutter. Corecție fixture-only: reset explicit înainte de întoarcerea fiecărui test; cleanup de siguranță existent păstrat, nicio aserțiune/runtime schimbată. Identity38664031428 SUCCESS5. CI corectiv urmează.

Exec-server local s-a deconectat după publicarea lot5; nu declarăm checkout local sincronizat ulterior. Continuare autorizată prin conector GitHub: bază/tree explicite verificate live, expected_sha, numai fișierele selectate și CI pe HEAD real. Drafturile locale nepublicate nu sunt încă livrabile; loturile următoare vor fi salvate în GitHub înainte de orice raport de final.
