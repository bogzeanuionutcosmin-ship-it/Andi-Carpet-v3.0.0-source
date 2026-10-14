# Vision — raport local de diagnostic opt-in (14.10.2026)

**Stadiu:** ramură de probă pentru Vision V0/V0.5, derivată din PR #21 la SHA `d18b2523a31ead7eb65a04fe92a21276a4155c97`. Nu este merge, deploy, release sau aplicație complet integrată cu AuthGate #33/modularizare #28.

## De ce
Vision V0 din PR #19/#21 înregistrează deja sumarizat erori Flutter/async și incidente GPS, FCM, OCR, diurne. Până acum diagnosticul putea fi consultat doar pe telefon. Pentru a putea analiza incidentele din testele manuale fără acces la Firebase și fără cost AI, am adăugat **copiere explicită a unui raport tehnic local**.

## Codul adăugat
- `lib/vision/vision_diagnostic_report.dart`: formatează numai zona/codul/platforma/severitatea/timpul/numărul de repetări/starea, cu verificarea din nou a identificatorilor, limită de **100 intrări** și **16.000 caractere**.
- `lib/vision/vision_diagnostic_advisor.dart`: **primul mecanism determinist read-only din nucleul Vision**. Prioritizează incidentele deschise după severitate și recență, prezintă explicații fixe pentru codurile deja instrumentate OCR/GPS/FCM/finanțe/diurne și recomandă doar verificări manuale, fără mutarea datelor sau presupunerea cauzei exacte.
- `lib/vision/vision_diagnostics_page.dart`: afișează recomandarea cu cea mai mare prioritate într-un card discret, fără animații sau notificări noi; rămâne UI local.
- `lib/vision/vision_diagnostics_page.dart`: buton `Copiază raport tehnic anonimizat` cu Clipboard **numai la gestul utilizatorului** și mesaj de confirmare/eroare; fără upload, SDK extern, permisiuni, costuri sau Firestore.
- Teste noi de interpretare: incidente deschise/rezolvate, priorități, OCR salvat/eșuat, fallback pentru coduri necunoscute, limite maxime și lipsa efectelor secundare. Testul widget verifică recomandarea și absența acesteia când incidentele sunt rezolvate.
- Teste Dart/unitate și widget pentru jurnal gol, 10.000 evenimente identice, câmpuri neacceptate, limitare de raport, absența copierii automate și Clipboard la apăsare.
- Workflow-ul offline existent verifică și testele raportului, pe o ramură izolată, fără Google Services/INTERNET/GPS/cameră, cu identificator de pachet distinct. Nu este un build al aplicației autentificate.

**Nu au fost modificate** `VisionErrorLog`/serializarea/TTL, PDF-urile, modelul financiar, Android release config, `main`, codul AuthGate #33, #28, #29, rules/config/date Firebase producție, billing ori versiunea.

## Atenționări importante
- Clipboard este gestionat de sistemul de operare și poate rămâne accesibil în istoricul său. Raportul nu trebuie copiat sau trimis pe un dispozitiv nesigur; utilizatorul verifică datele înainte de distribuire.
- Codurile tehnice sunt limitate lexical, însă **un jurnal nu poate detecta automat orice bug silențios**. La OCR, salvarea unei sume greșite dar fără eroare necesită verificarea rezultatului final, nu doar `catch`.
- Raportul reflectă doar **acest dispozitiv** și intervalul de retenție al jurnalului. Nu există centralizare multi-dispozitiv, ChatGPT online 24/7, self-healing financiar sau monitorizare cât aplicația este oprită.
- APK-ul rezultat din workflow este numai pentru testul offline Vision/PDF, **nu** este APK-ul actualizat al aplicației de lucru; testarea reală a integrării va fi un pas separat după remedierea AuthGate și contractele financiare.
- PR #21, #19 și munca Lunăi (#33) rămân nemodificate.

## Acceptanță
1. CI standard toate cele 5 joburi verde pe SHA al PR de probă.
2. Workflow-ul `Offline smoke APK - separate install, no Firebase` verde, identificator unic și permisiuni interzise absente.
3. La test pe telefon: `Vision → Test local → Copiază raport`; raportul trebuie să conțină `vision_test/persistence_probe`, număr apariții și timestamps, fără date personale. După repornire, evenimentul test rămâne în jurnal.
4. Butonul de copiere nu declanșează transmitere către server. Niciun APK nu este distribuit ca release.
5. După rezultatele CI se actualizează concluzia, fără a declara fals misiunea completă.

## Etapa ulterioară
După PR #33 RED→GREEN și evaluarea #28/#29, creare ramură **distinctă de integrare** a Vision V0.5 cu codul modularizat, OCR, documente și securitatea UID, teste Android/web reale, fără merge/deploy înainte de aprobare. Vision avansat — motor de reguli, Learning GPS, START idempotent, DND, diagnostic centralizat opt-in — rămâne separat.

## Lot suplimentar — explicații Vision înainte de avatar

Proprietarul a confirmat că avatarul (salut, dans, gesturi amuzante) se decide și implementează **după nucleul funcțional**. Decizia completă este salvată în Issue #30. Acest lot dezvoltă exclusiv logica read-only, fără elemente grafice noi în afară de cardul de explicație; niciun LLM/cloud/cost API.

**Limită esențială:** un incident din jurnal poate declanșa o recomandare de verificare, dar nu confirmă că respectiva operațiune a eșuat definitiv sau că lipsesc alte buguri. Nu se efectuează reîncercări automate financiare, START/STOP, modificări de permisiuni sau sincronizare suplimentară. Observațiile silențioase fără excepții necesită integrare explicită ulterioară cu fluxurile reale.

**CI pentru lotul nou:** rezultatele se vor trece în PR după validare. Nu confundați validarea precedentă pentru SHA `2995637e` (5/5 standard + Android offline SUCCESS) cu verificarea commiturilor suplimentare.

## Lot nou — clasificarea repetițiilor fără estimări false

Vision tratează o singură înregistrare ca **observație izolată** și două sau mai multe observații cu același cod/platformă ca **repetate**. În panoul de diagnostic afișează numărul exact din sumarul local; la severitate egală, incidentele repetate sunt prioritizate înaintea celor izolate, iar un incident critic singular are totuși prioritate față de o avertizare repetată. Incidentele marcate rezolvate nu produc recomandări active.

**Limitare tehnică importantă:** contorul este agregat pe durata rezumatului păstrat local, nu o rată pe minut/oră și nu dovedește că defectul s-a repetat într-un interval calendaristic fix. Nu sunt generate notificări, alerte server, cereri de rețea, retry-uri sau scrieri operaționale. Teste unitare/widget pentru prag 1→2, sortare, severitate, resolved și lipsa efectelor secundare; rezultatele ultimului SHA se validează separat în CI.

## Lot suplimentar — limitele acoperirii afișate în aplicație

Un panou local „**Ce monitorizează Vision**” afișează un **inventar static și sincer** pentru cele cinci zone parțial instrumentate (Flutter/Dart, GPS, FCM, OCR, diurne/finanțe) și două domenii încă neconectate (Firebase Functions/cloud și verificarea izolării identității). Fiecare intrare descrie atât semnalele deja colectabile în ramura de probă, cât și ce NU poate verifica Vision încă. Acesta NU este un test de sănătate sau o garanție că instrumentarea funcționează în toate scenariile/OS; necesită execuția reală a fluxurilor.

Implementarea folosește exclusiv șiruri fixe locale, nu colectează date, nu pornește ascultători noi, nu creează trafic și nu schimbă permisiuni. UI este deschis doar la cerere din butonul cu informații. Testele acoperă inventarul fără dubluri, etichetele explicite, zonele lipsite de diagnostic și vizibilitatea panoului. La integrarea codului peste #28/#33, inventarul trebuie revizuit și sincronizat cu instrumentarea reală; nu se extrapolează acoperirea de pe ramura experimentală.

## Ajustare după proba reală Android — 14.10.2026

Utilizatorul a instalat APK-ul de test offline și a furnizat capturi care confirmă vizual înregistrarea `vision_test / persistence_probe` de două ori, feedbackul «Copiat» la raport și deschiderea panoului de acoperire. Aceste capturi **nu demonstrează singure** persistența după repornire (nu se vede înainte/după), ci confirmă afișarea și reacțiile locale.

Au fost identificate două îmbunătățiri neintruzive: titlul lung `Vision · Error Log` era trunchiat pe telefon, iar evenimentul sintetic era prezentat de advisor ca incident real, cu starea «Deschisă». Corecția din acest lot folosește titlul scurt `Vision`, afișează evenimentul `vision_test/persistence_probe` ca `Test de persistență · fără eroare` / `Probă locală` și **îl exclude numai din recomandările de erori**, păstrându-l în jurnal și în raportul copiat. Alte coduri reale, inclusiv OCR, GPS și FCM, rămân în recomandări. Zero impact asupra autentificării, datelor, permisiunilor sau accesului la rețea.

Testele adăugate acoperă dimensiunea redusă a ecranului, lipsa avertizării false, păstrarea contorului și vizibilitatea incidentelor reale. Rezultatul CI și compilarea APK-ului se verifică exclusiv pe ultimul commit al acestei ramuri.

## Investigație instalare Android — proba de la 09:37 (14.10.2026)

Captura trimisă după ultimul build arată încă titlul `Vision...`, `Vision observă: Incident local observat` pentru `vision_test/persistence_probe` și contor `×4`. În commitul validat `c0a36343510e45b18c476ee92a057d78360d7638`, sursa arată deja `Vision` și filtrarea `persistence_probe` în advisor. **Deci captura nu reflectă corecțiile din HEAD-ul PR #34**; cauză probabilă: utilizatorul a deschis o instalație APK mai veche / noul APK nu a înlocuit-o. Nu afirmăm că știm precis motivul fără instalare ADB/sistem.

### Remediere de distribuire exclusiv pentru APK-ul de laborator

GitHub Actions folosește Android debug signing, care poate varia de la un runner la altul; astfel, instalarea unui alt debug APK peste pachetul cu același ID poate eșua din cauza semnăturii. Mai mult, diferite artefacte anterioare au purtat aceeași etichetă și același versionCode, ceea ce a favorizat confuzia.

Din acest lot, workflowul de smoke creează, **numai în checkoutul temporar CI**, un ID Android unic la fiecare rulare, `com.example.andi_carpeta.smokeoffline.r<RUN_NUMBER>`; eticheta launcher devine `Vision TEST #<RUN_NUMBER>`, iar ecranele de test afișează `VISION TEST OFFLINE · BUILD #<RUN_NUMBER>`. `flutter build apk` primește versiunea de **test** `0.8.0+100000+RUN_NUMBER`, iar ZIP-ul/artifactul include explicit RUN_NUMBER și APK-ul cu nume unic. Workflowul verifică prin `aapt` package/versionCode/versiune, lipsa permisiunilor periculoase, SHA-256 PDF Million și testele Dart. **Nu se schimbă `pubspec.yaml`, versiunea de release, `android/app/build.gradle.kts` din GitHub, sau Firebase live.**

IMPORTANT: noul APK de test **se instalează separat de cele vechi**; contorul local din vechile APK-uri nu este migrat, iar un jurnal gol la prima pornire este corect. Se poate elimina manual vechiul Vision TEST (NU AndiCarpet de lucru) după verificarea noii versiuni. Pentru persistență: pornește noua aplicație etichetată `Vision TEST #N`, intră în jurnal, verifică același `BUILD #N`, apasă proba o dată, închide complet aceeași aplicație și redeschide-o: contorul trebuie să persiste fără reexecutarea probei. Fără orice modificare în PR #33 al Lunăi.
