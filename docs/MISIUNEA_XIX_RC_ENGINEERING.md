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
Centralizator cu writerul real și PDF real. Crearea graficului folosește SDK,
nu formularul Grafic; corecția este apelată prin writer, nu dialogul complet.
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
