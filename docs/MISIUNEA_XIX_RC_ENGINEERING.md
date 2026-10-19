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
corecția este apelată prin writer, nu dialogul complet.
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
