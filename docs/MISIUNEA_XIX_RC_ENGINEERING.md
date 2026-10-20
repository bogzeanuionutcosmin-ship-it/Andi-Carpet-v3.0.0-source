# Misiunea XIX — candidat izolat

Comanda XIX autorizează remedieri, teste sintetice și builduri în ramuri Draft.
Regulamentul main8452159 păstrează modularizarea înaintea noilor automatizări,
CI pe SHA final și aprobarea separată pentru merge/producție.

## Defecte și contracte

- Writerul general anterior putea recrea o intervenție ștearsă și suprascrie o
  editare concurentă. Noul writer folosește baseline local și tranzacție, cu
  retry identic pentru același ID. Nu rezervă START între dispozitive cu ID-uri
  distincte. Slotul canonic de intervenție și activarea exclusivă a writerelor
  necesită un contract separat; nu este introdusă o coadă offline.
- Metadatele legacy Map/List sunt comparate recursiv după valoare, fără a
  rescrie câmpurile necunoscute. Guardurile locale START/FINAL rămân single-flight.
- Fereastra uzuală a turei nu invalidează o intervenție reală la 13:00/22:00.
  Execuțiile deschise rămân disponibile peste limita calendaristică. Asocierea
  explicită a unui START timpuriu cu o altă zi/grafic rămâne de demonstrat.
- Restore manual/automat: preflight, inventar server limitat, un singur batch
  pentru maximum400 mutații inclusiv metadata. Backupurile mari sunt refuzate
  înainte de scriere. `meta/backup` păstrează metadatele anterioare de export.
  Nu există lock de mentenanță exclusiv și nici snapshot global al bazei.

## Dovezi inițiale și verificarea finală

HEAD8024722: Validate39076482915 și APK39076482901 SUCCESS. Native39076482990
a reprodus START reușit urmat de lipsa STOP la22:58, la ensureVisible linia52.
Testele pinned RED/GREEN verifică separat comparația nested și limita12:30.
CI final și HEAD-urile actualizate sunt în descrierile PR-urilor și raportul XIX.

Testul conectat folosește Auth/Firestore native SDK și componentele Dashboard/
Centralizator cu writerul real și PDF real. Crearea graficului folosește acum formularul ProgramPage, cu cele 11 locații
selectate în UI și confirmate prin citire Source.server fără cache/scrieri în
așteptare. Markerul graphCreatedThroughUi este obligatoriu în observații;
artefactele vechi fără acest marker sunt respinse. Activarea graficului și
redistribuirea datelor pe 15/16 octombrie rămân pregătire sintetică prin SDK;
corecția este introdusă prin dialogul Centralizatorului, apoi callbackul de
test folosește writerul nativ, recitește serverul și verifică PDF-ul. Callbackul
privat al HomePage nu este exercitat de acest montaj de componente; nu se
pretinde E2E complet al aplicației de producție. Markerul correctionThroughUi
este obligatoriu pentru artefactele acestui scenariu.
Nu se declară E2E UI complet. Aplicația operațională cu entrypoint main se
instalează ulterior cu backend demo, pentru persistența Auth/cold restart.

## Siguranța Android

APK-ul operațional implicit este construit și inspectat, fără lansare cu Firebase
live. Varianta runtime păstrează package-ul real și folosește backend demo numai
în debug, cu host loopback și pluginul GoogleServices scos în runnerul temporar.
Harnessul vechi centralizersmoke nu este folosit ca dovadă pentru acest flux.
Release de test folosește încă debug signing: nu demonstrează semnătura permanentă
sau compatibilitatea cu instalările existente. Fără telefon fizic, GPS/background
real, distribuire APK, deploy sau modificări Firebase live.

## Întărirea probelor native

Testul de concurență acceptă drept pierzător numai conflictul StateError al
baseline-ului, verifică payloadul câștigător pe server și numărul documentelor.
Erorile de autorizare trebuie să aibă codul permission-denied, nu orice eroare SDK.
Proba restore folosește inventarul records citibil de membru și un batch mixt:
un update permis plus ștergeri/metadata interzise. Snapshotul integral trebuie
să rămână neschimbat după refuz; un refuz la inventarierea finance nu ar demonstra
rollbackul. Navigarea main verifică headinguri exacte și pachetul în foreground;
eticheta tabului singură nu dovedește încărcarea datelor.

Rularea native39093051088 a arătat că finalizarea Future-ului tranzacției cu
rețeaua SDK oprită nu a produs eroarea așteptată. Writerul cere acum citire
Source.server înainte de pregătirea tranzacției și confirmarea payloadului pe
server după aceasta. Sunt două citiri suplimentare explicite; o confirmare
incertă este eroare, fără regenerarea ID-ului. Concurența rămâne în tranzacție.
Collectorul validează headerul/trailerul PDF și obiectul JSON, astfel încât
textul stdout «run-as: unknown package» nu este publicat ca PDF/observații.

Source.server poate include latency compensation pentru scrieri locale: se
resping și snapshoturile isFromCache/hasPendingWrites. Confirmarea ulterioară
poate raporta incertitudine dacă un alt writer legitim modifică imediat după
commit; mesajul nu dovedește că propriul commit a eșuat. Nu se așteaptă global
waitForPendingWrites, care ar lega această operațiune de alte scrieri.

Flutter 3.47.5 a fost verificat în workflow pentru opțiunea `--no-uninstall`.
Testul instrumentat oprește procesul după rulare, dar păstrează instalarea și
Auth-ul emulatorului; aplicația operațională poate fi apoi reinstalată peste
aceeași package ID pentru cold restart/nav. Dacă opțiunea lipsește, CI eșuează
înaintea testului nativ, fără fallback care ar elimina aplicația.

## Follow-up: writerul corecțiilor din HomePage

Draft #128 extrage tranzacția existentă a corecțiilor în
`centralizer/correction_writer.dart`. HomePage păstrează verificările de
permisiuni și identitate, iar adaptorul UI nativ folosește acum aceeași operație
de persistență. Probele noi cer refuzul unui baseline vechi, al unei intervenții
create apoi șterse, al echipei neautorizate și al corecției offline, urmată de
recitire server fără modificarea fațadei. Aceste rezultate nu sunt declarate
reușite înainte de CI; extragerea nu introduce implicit confirmare server.
Coordonatorul privat HomePage și pregătirea calendaristică sintetică rămân limite
explicite. Ramura include #125 ebd96c27; conținutul comun nu se integrează dublu.

Rularea native 39192340982, job 117867660812, pe HEAD 55cf201c437ba8f039240e4d23246a3e0c0b6adc
reproduce la linia270 Future<void> finalizat cu null în locul refuzului corecției
offline. Probele online UI, baseline vechi, document șters și echipă neautorizată
au precedat acest eșec. Nu există dovadă că operația offline a persistat pe server;
eșecul demonstrat este raportarea unui succes neconfirmat. Fixul adaugă citire
Source.server înainte de tranzacție și confirmarea câmpurilor după ea, respingând
metadata cache/pending. Un rezultat incert nu dovedește lipsa commitului; UI cere
reîncărcare. Regresiile Dart simulează finalizarea bridge-ului fără mutație server,
nu înlocuiesc rerularea nativă. Validatorul cere noul marker de writer de producție.

## Probă suplimentară: coordonatorul HomePage

Ramura separată `codex/xix-home-correction-ui` montează AndiCarpetaApp real,
încarcă funcția editorului din emulator, deschide Centralizatorul din navigare și
corectează FINAL 00:20→00:21→00:20 prin callbackul privat al HomePage. Fiecare
salvare cere mesajul de succes și citire server cu metadata autoritativă. Proba
elimină apoi dreptul editCentralizer din funcția sintetică și cere dispariția
acțiunilor de corecție, fără schimbarea serverului. Funcția temporară și atribuirea
se restaurează înaintea restarturilor. Nu se declară reușită înainte de CI.
Markerul homeCorrectionThroughUi respinge artefactele limitate la componente.
Crearea/activarea Graph și datele istorice rămân limite distincte; proba nouă nu
transformă întreaga suită în validare de producție.

## Misiunea XIX — loturi suplimentare de modularizare Map (19 octombrie 2026 UTC)

Au fost create cinci Draft PR-uri noi, distincte de #134–#140 și fără suprapunere de patch: [#141 selectare rute](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/141), [#142 parser reverse-geocode](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/142), [#143 transport reverse-geocode](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/143), [#144 stare badge Map](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/144) și [#145 filtrul programelor Map](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/145). #141/#142/#144/#145 sunt ramuri independente pe baza #137; #143 este descendent al #142. HEAD-urile: #141 `39f3506df19d9a53cd2060f646f57a0df567f7e6`, #142 `43690da9808830c3ac2f71d06ca778a09fd910eb`, #143 `97b9f9198a8e739957fe1b4ab9d1b9ffa20e11b3`, #144 `fd551da6163e014aad901c40e9b7975e1a29f0e9`, #145 `817489db98f1a47140ba5c07fd7bc175d1081e79`. Loturile izolează selecția rutelor, parserul și transportul HTTP reverse-geocode, decizia badge-ului și filtrul programelor operaționale fără schimbare de comportament intenționată.

Validate și Android debug sunt SUCCESS pentru #141 (#141 `39341558517` / `39341558484`) și #143 (`39341822453` / `39341822515` / `39341822442`). Toate cele trei workflow-uri pentru #142 sunt SUCCESS pe SHA exact `43690da9808830c3ac2f71d06ca778a09fd910eb`: Validate `39341819031`, Android `39341819032`, Native `39341819051`. Validate este SUCCESS pentru #144 (`39342521773`) și #145 (`39342732825`); Android #144 (`39342521800`) este de asemenea SUCCESS. Native #141 (`39341558511`) este la attempt 3 pe exact același SHA; attempt 1 a eșuat la NDK (`ZipFile unknown archive`), attempt 2 a produs PDF-ul dar Auth Emulator a întrerupt stream-ul la loginul celui de-al doilea client (`unexpected end of stream`) înainte de aserțiunea finală. Native #143 (`39341822442`) este SUCCESS cu PDF/checksum/artifact verificate; Native #144/#145 (`39342521775`, `39342732906`) și Android #145 (`39342732850`) este SUCCESS. Nu există eșec de aserțiune Map raportat. Teste structurale locale per lot: 173 Python, 3 Node și `git diff --check` PASS; Flutter/Dart nu sunt instalate local.

Niciun PR nu este declarat merged. #134–#145 rămân Draft/Open; nu s-a făcut merge, deploy, acces/modificare Firebase de producție, semnare sau distribuire APK. Modularizarea aplicației este încă incompletă; `production_ready=false`.


## Continuare #141–#146 și CI terminal (20 octombrie 2026 UTC)

La SHA exact, toate trei workflow-urile sunt SUCCESS pentru codul #141 (39f3506df19d9a53cd2060f646f57a0df567f7e6: Validate 39341558517, Android 39341558484, Native attempt 3 39341558511), #142 (43690da9808830c3ac2f71d06ca778a09fd910eb: 39341819031/39341819032/39341819051), #143 (97b9f9198a8e739957fe1b4ab9d1b9ffa20e11b3: 39341822453/39341822515/39341822442), #144 (fd551da6163e014aad901c40e9b7975e1a29f0e9: 39342521773/39342521800/39342521775), #145 (817489db98f1a47140ba5c07fd7bc175d1081e79: 39342732825/39342732850/Native rerun 39342732906) și #146 (913d9a2ed34aeff46514acead45c054f105a67e8: 39344765440/39344765436/39344765414). Pentru #145, Native a fost relansat după anularea jobului inițial provocată de avansarea cu documente; rerularea pe SHA-ul aceluiași cod este SUCCESS.

PR Draft #146 [Extract Map location filter policy](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/146) scoate filtrarea generică categorie/status/poziționare GPS într-un helper fără dependență de modele/UI și reutilizează filtrul în marker list, locații fără GPS și panourile categorice. Testele dedicate verifică seturi selectate, coordonate parțiale și categoria exactă pentru panou. Filtrele de branch CI și testul-contract sunt extinse numai pentru a permite executarea workflow-urilor standard pe copilul #145; pașii și politicile lor rămân neschimbate.

#141–#146 rămân Draft/Open, fără merge. Validările locale: 173 Python, 3 Node și git diff --check PASS; Flutter/Dart lipsesc local. Obligatii încă deschise: modularizarea paginilor și familiilor rămase din matricea PR #137; verificarea prudentă a cache-urilor Home write-only și a parserelor receivedEntries; decuplarea GPS/UI/models/orchestration din Map; review uman și Android fizic. Fără merge, deploy, Firebase de producție, semnare sau distribuire APK; production_ready=false.