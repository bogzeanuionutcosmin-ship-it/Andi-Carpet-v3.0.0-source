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

## Lot 2 GREEN / lot 3 securitate multi-cont

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

## Lot5 GREEN / lot6 observabilitate prudentă

Lot5 corectiv c18647b9695e1c95dd3b2fd65852f5d3feb8101e / treef8edeabcc7fa8772782bdf25217e3f851ac1ea14. Standard38664331766 SUCCESS5/5,426Flutter/167Python; identity38664331769 SUCCESS5. Numai cleanup de fixture a necesitat corecție; cele șase assertions de ownership/zeroA/Blegitim sunt păstrate. Execserver local a revenit; reset--keep pe ramura proprie a sincronizat corecția remote și a păstrat drafturile locale.

Lot6: cinci widget tests noi în ExpensePage real, aceleași porturi/parser/form. Diurnă acknowledgement failure→un semnal+rollback original+zero retry; sumă primită settlement failure→un semnal fără suma/supplier; save Expense cu mutație locală apoi exception→semnal prudent, nu documentMissing/serverConfirmed; ownership revocat în timpul save failure→zero observație veche (nu drept financiar nou/cancel fictiv); sumă OCR grouped greșită fără exception→zero missing-document fabricat. Advisorul cere verificare și menționează că documentul ar putea exista. Verifier pur invocat numai în test cu serverConfirmed:false.

Fixture-ul Expense existent primește numai opțiuni de test: perDiems/override savePerDiem/saveSettlement/diagnostic owner, cu fallbackurile vechi. Zero lib/runtime/financiar/parser/rules diff. Contractele existente verifică în continuare unicitatea și guardurile tuturor celor13hookuri; sync diurnă este acoperit de proba V existentă. Transactions dispute/supplementary/backend ACL nu sunt certificate prin aceste fakes. CI lot6 urmează.

### Lot6 defect financiar preexistent / RED separat, NU remediat

3c823108, standard38664615297:429PASS/2FAIL. Prima cauză: TextEditingController folosit după dispose în expense_settlement_actions.dart::_money (amountC/fromC dispose la revenirea showDialog, înainte de finalul animației). Cadrul stricat contaminează testul OCR următor; celelalte429 trec. Sursa financiară este byte-identică #38: nu este regresie Vision și nu o schimbăm în mandatul VI.

Proba inițială strictă este păstrată textual, fără schimbarea aserțiunilor, în test/vision_settlement_controller.red.dart. Nu intră în descoperirea *_test.dart: aceasta este o probă RED explicită pentru un flux business BLOCKED, nu o acceptanță GREEN. Workflow-ul Android o execută separat și cere exit1 + mesajul exact controller-disposed + numele probei; dacă proba devine verde, caracterizarea cere revizuire. Nu se pretinde că formularul financiar funcționează. Cele patru probe Vision autorizate rămân neschimbate în suita normală; niciun test existent din #38 și nicio aserțiune AuthGate nu este slăbită.

Read source confirmă posibilă mutație locală receivedEntries înainte de save failure, fără rollback, păstrată ca risc distinct. Remedierea lifecycle/rollback financiar cere misiune separată. CI corectiv trebuie validat înainte de lot7.

## Lot6 GREEN pentru Vision, formular business rămâne RED / lot7 freeze

Lot6 corectiv c91f7a233b4d9ca540dd447c3375923baddda4da / tree7138737020485ff643af02aa9d209f274cb57102. Standard38664983837 SUCCESS5/5,430Flutter/167Python; identity38664983847 SUCCESS5. Android38664983870 a trecut atât testele Vision/AuthGate cât și pasul explicit knownRED, apoi a intrat în compile; nu revendicăm finalizarea acelui build înainte de rezultat. Formularul Sumă primită este în continuare BLOCKED/KNOWN RED, nu reparat.

Lot7: patru contracte Python noi în vision_hardening_freeze_test.py:21hashuri suplimentare pentru AuthGate/root/operațional/parser/telemetry/status/verifier/securityfixtures/configAndroid; allowlist strict de importuri fără transport/backend în Vision; fără timer/listă de Futures sau veche coadă în persistență; proba financiară RED și wrapperul CI nu pot fi slăbite. Corpul inițial al probei RED are SHA2568c82ee6e21b75ffe6404716983a702b191a8c3265be30c421aa6070e046d7644, identic textului din3c823108.

171Python local PASS,116protectedhashes intacte. Contractele V existente13hookuri/publicUI/ownership sunt păstrate, nu duplicate. Matricea combinată includeUIDepoch×storage×lifecycle×platformlabels și SDKAndroidfake; nu o prezentăm drept produs cartezian exhaustiv sau hardware. Zero runtime în lot7. CI urmează; apoi loturile8–10 validare/audit/predare.

## Lot7 GREEN / lot8 Android-web fără release

Lot7 d220da5562bbc10012202a70a4bc2ac14ea58c54 / tree1360a2cdffb72f4547befbdd99a56308ccab6b38. Standard38665315100 SUCCESS5/5,430Flutter/171Python, identity38665315109 SUCCESS5; Node3/financial10/Functions/smoke/web sunt în standard.

Lot8 extinde numai workflow-ul compile-only existent, pe noua ramură, cu aapt după build: package com.example.andi_carpeta, versionName3.0.1/versionCode33 și lista de permissions sunt inspectate în runner, fără upload APK. Manifest/Gradle/pubspec/lock/signing sunt păstrate; nu schimbăm identificatorul sau versiunea. Eticheta internă _appVersionLabel3.0.0+32 diferă preexistent de pubspec3.0.1+33; trebuie reconciliată înainte de release, nu este remediată aici.

Testele rulează pe lib/main.dart real, nu smoke offline #34. CI pe acest workflow și ultimul HEAD se verifică la închidere; auditul/predarea următoare sunt numai documentație și nu cer repetarea loturilor de cod. Hardware/loginFirebase/GPS/FCM/cameră/Keystore real:NEEXECUTAT. CI build nu le certifică. Standard web-build este numai artifact CI, nu hosting/deploy.

## Lot9 — audit diferențial / contractele etapei următoare

Comparat #38 7a87d1d cu #34 LIVE d84641b (neschimbat la reverificare). Șapte module core Vision sunt identice sursei; bootstrap este adaptorul #38, absent în laboratorul #34. Diferența coverage este numai comentariu. #38 are _persistenceStarted și init/bootstrap unice înainte de Firebase, deci nu importăm adaptorul telemetry #34 care ar pierde această protecție. Coalescingul din lot1 este singura diferență lib a misiunii VI. Nu sunt importate Home/main/Expense monolitice, OCR/PDF/version/config din #34.

Inventar local:253Dart/59part/194biblioteci (include probaRED ca bibliotecă separată), fără missing/orphan/duplicate/cycles detectate; audit lexical, nu dovadă generală de cod mort. Niciun nou runtime seam nefolosit; verifier-ul neconectat este o limită intenționată moștenită. 116hashuri și21freezechecks trec. Source #28/#29/#34/#35/#36/#38/main toate revalidate neschimbate.

| Domeniu | IMPLEMENTAT | TESTAT-Fake | TESTAT-CI | TESTAT-HARDWARE | BLOCAT / DECIZIE / următorul contract |
|---|---|---|---|---|---|
| Coalescing/log bounded/status | Da, local | Read/write gates, bursts1200/10000, TTL/NTP, failure | Flutter430 și contracts; Android final obligatoriu | NEEXECUTAT | Nu certifică discul/Keystore real, kill best effort |
| UI diagnostics | Doar intern/test, refuz device-wide | A→B→A, cold restore, epoch, clipboard/rebuild/logout | Widget suites | NEEXECUTAT | Politică explicită + proiecție persistentă UID/epoch demonstrată înainte de acces public; developer nu devine admin |
| FCM/GPS ownership | Protecțiile #35 păstrate | B legitim + A întârziat la6gates | Flutter/identity, compilare finală | NEEXECUTAT | ReverseHTTP/boost250/Web700 neexecutate dinamic; cere fixture separat, fără modificarea pragurilor |
| Observații OCR/diurne/finance | 13hookuri existente păstrate | 4probe noi + probe V; fake mutation nu este server evidence | Pozitive în CI | NEEXECUTAT | Nicio auto-confirmare/retry/write nou |
| Formular Sumă primită | Preexistent, neschimbat | Repro strict RED controller-disposed | Rulare RED explicită, nu acceptanță verde | NEEXECUTAT | Remediere lifecycle într-un mandat separat; verificare rollback local separat |
| Verifier / Issue32 | Pur, NECONECTAT | Fără server evidence→pending | Pure suites | NEEXECUTAT | Drepturi/query ownership/fresh server evidence și idempotency cer contract separat |
| PDF | Magic păstrat, Million absent în baza #38 | Hashuri sursă | Protecții inventar existente | NEEXECUTAT | Integrare Million numai din original #20/sursă hash3bece2fa… într-un scope separat |
| Backup/migrare/Admin | Doar comportamentul moștenit | Caracterizări III păstrate | Suite originale păstrate | NEEXECUTAT | Atomicitate/preview/ownership/rollback și migrare badge rămân neimplementate |
| Learning GPS | Learning durate existent; nicio automatizare nouă | Doar fixture-uri existente | Regresii originale | NEEXECUTAT | Sosire/plecare adaptivă/START idempotent/STOP confirmat, protocol hardware separat |
| Costuri / AI / multi-device | Niciun provider sau colector cloud nou | Import/API contracts | 0 transport nou în Vision | Billing live NEEXECUTAT | Nu garantăm cost zero al întregii infrastructuri; niciun upgrade/paid API autorizat |
| Avatar | Amânat | Nu | Nu | Nu | Corp/animații constituie altă misiune |

Million original din #34 reverificat SHA2563bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23; assets/pv_magic.pdf eaf7be7d1ff77aafaa328c1ffd08c8e3c668f689104be432436cf5fb40eaaa6b. Niciun asset schimbat.

Lot8 code/CI checkpoint7eaa3aa783e8ceadfe8360b926862bcd5e0c5fd1/tree f40b33193e188036e9fc07824938b607f0f252df; commitul9 este numai acest audit și ChatGpt. Validarea finală include și metadata aapt, probaRED și lib/main.dart real. Nu facem CI redundant manual pentru fiecare paragraf; ultimele trei checkpointuri documentare sunt certificate de ultimul HEAD verificat, conform politicii Issue39.

## Lot10 — închidere și predare

Toate loturile sigure au fost parcurse, în ramură izolată. Nu declarăm formularul financiar reparat sau toate subprobele SDK executate. Sinteză:28teste Flutter pozitive noi (402→430),4contracte Python noi (167→171),1probă business RED explicită cu corpul original păstrat. A01–A12/C01–C08 și fixture-urile de securitate sunt byte-identice cu #38; toate116hashuri protejate intacte.

| Lot | Commit final / corecții | Standard / identity | Teste și fișiere principale |
|---|---|---|---|
|1 coalescing|08492f64|[38661750066](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38661750066) / [38661750070](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38661750070)|408Flutter,167Python;6noi; vision_local_persistence + coalescing tests; Android38661750057 SUCCESS134+compile|
|2 presiune|f0ca23d2→6ee5b257|[38662610600](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38662610600) / [38662610626](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38662610626)|414Flutter,167Python;6noi; vision_pressure_test|
|3 epoch/cache|acff78e3→b235f484|[38663228002](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38663228002) / [38663227995](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38663227995)|418Flutter,167Python;4noi; session_cache_matrix|
|4 bootstrap/lifecycle|bfa9dcc4|[38663598978](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38663598978) / [38663598984](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38663598984)|420Flutter,167Python;2noi; bootstrap_lifecycle_adversarial|
|5 SDK|9bd6f97e→c18647b9|[38664331766](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38664331766) / [38664331769](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38664331769)|426Flutter,167Python;6noi; sdk_epoch_matrix; HTTP/boost/Web700 rămân fără probe dinamice|
|6 observabilitate|3c823108→c91f7a23|[38664983837](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38664983837) / [38664983847](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38664983847)|430Flutter,167Python;4pozitive+1RED; Expense fixture/tests; wrapper knownRED în workflow|
|7 freeze|d220da55|[38665315100](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38665315100) / [38665315109](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38665315109)|430Flutter,171Python;4contracte noi; hardening_freeze|
|8 Android metadata|7eaa3aa7|Certificate pe HEAD final, după ultimul doc-only checkpoint|Workflow compile existent + inspecție aapt package/version/permissions, fără artifact APK|
|9 audit|702587908114619d2d3879b7864e62d383d91ec3|Certificate pe HEAD final|Numai raportul și ChatGpt; matrice status, surse/inventar/riscuri|
|10 predare|SHA/tree și CI final în descrierea PR41 după execuție|UltimulHEAD se validează, nu este presupus GREEN|Numai raportul și ChatGpt; fără autoreferință imposibilă la propriul hash|

Trees 1–7 în aceeași ordine:ecacc77fbb7e8e09f6de12692da6a881103f8af5;908fc831fa307eb766e528e0af2b8166ff1c4d5c;184d33416e1c4e9fcead34da980ddcb1d7406532;968d11eb407bb7b872da8250ae0c069b856ddadc;f8edeabcc7fa8772782bdf25217e3f851ac1ea14;7138737020485ff643af02aa9d209f274cb57102;1360a2cdffb72f4547befbdd99a56308ccab6b38. Metadata local/index/remote a fost comparată la fiecare publicare; corecția5 prinAPI a folosit base-tree explicit verificat și diff limitat la3fișiere. Tree8f40b33193e188036e9fc07824938b607f0f252df; tree9dc3ad1d91b8e388b2e394e30b595a842687e08d7.

### Reluare exactă / condiții deschise

Verifică SHA/CI/tree final în [PR41](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/41), apoi checkout exact. Nu repeta loturile1–7 sau misiunileIII–V. Dacă ultimulCI este încă pending/RED, finalizează întâi verificarea. Mesajul cu HEAD exact se publică în descrierea PR după CI, fără commit suplimentar care ar invalida checkpointul.

Muncă sigură rămasă în sfera probelor: fixture separat pentru reverseHTTP/boost250/Web700, cu zero I/O și fără schimbarea comportamentului GPS. Nu sunt certificate dinamic aici. Formularul _money controller lifecycle/rollback, drepturile Issue32, UI public/proiecție persistentă UID, Million, backup/migrare/Learning și release/hardware cer scope distinct conform matricei. Nu converti knownRED financiar în GREEN prin relaxarea probei; o reparație autorizată va actualiza explicit caracterizarea.

PR41 rămâne Draft TEST/HARDENING DO NOT MERGE. Fără merge/deploy/publicare web/APK/instalare, date/rules/config producție, roluri, finanțe, billing/servicii plătite sau schimbări pe ramurile sursă. La final se verifică checkout curat și arbore identic merge-ref/branch, standard5/5, identity5teste, Android real+metadata+knownRED. Aceste rezultate finale se raportează efectiv după încheiere, nu anticipat în acest fișier.

## Reluare din 39e7ed21 — lot5 SDK, completare nativă

HEAD #41 reverificat 39e7ed21, checkout curat. Cinci probe noi test-only în vision_live_sdk_delays_test.dart și fixture platform separat: HTTP success/failure A1 întârziat după A→B→A2, boost250/relax250 întârziate după invalidare, plus control pozitiv activ al ambelor retunings exact la250ms. Folosesc State Home și closure UID+epoch AuthGate reale, http.runWithClient/MockClient și FirebaseFirestorePlatform fake; nu substituie metodele private și nu copiază algoritmul. B primește poziție și scrie legitim un liveLocations/b; orice write A sau restart vechi e interzis. Accuracy100 în datele sintetice oprește explicit automatizarea operațională independentă. HTTP pending nu ajunge la transport; alte operații Firestore sunt neimplementate/throw.

Zero lib/runtime/dependențe/config changes; sursele și proba financiară RED rămân înghețate. 171 Python local PASS. Flutter absent local; cele5 probe sunt PREPARATE, nu încă PASS până la CI. Următoarea subetapă după GREEN: Web700 în browser real de test, fără Firebase/web deploy. Hardware și SDK live rămân NEEXECUTATE.

### Native CI inițial RED, investigație de fixture
1e5e6670/tree3bfe9c51: standard38672158866 434PASS/1FAIL; Android38672158834 160PASS/1FAIL (compilarea nu a rulat), identity38672158853 SUCCESS5. Cele patru stale-owner probe trec; controlul pozitiv nu vede al doilea stream la250ms. Nu reducem așteptarea și nu schimbăm runtime. Adăugăm observație transparentă Zone.createTimer (forward către timerul real FakeAsync) și assertions de scheduling în probele negative, pentru a exclude un PASS vid; controlul pozitiv păstrează exact pragul și cerința de retuning. Rezultatul următor rămâne de verificat înainte de Web700.

### Control pozitiv: cancel SDK și ceasul testului
ad3e67bd/tree99f60769: Android38672506902 confirmă cele patru negative, inclusiv timer250 programat efectiv (boost1/relax2); controlul pozitiv încă RED. Trace exact după250: check,enabled,check,stream,listen,check,enabled,enabled,check,cancel; settings1/timer1. Deci algoritmul a programat și declanșat timerul, apoi așteaptă cancelFuture al StreamController; nu este lipsă de boost. Fixture-ul drenează acum coada async reală prin tester.runAsync la acel punct, fără avansarea ceasului FakeAsync: assertions rămân1stream la249 și2la250, respectiv3după relaxare. Nu substituim cancelul/metoda runtime și nu introducem toleranță de timp. CI urmează; nu certificăm încă rezultatul.
