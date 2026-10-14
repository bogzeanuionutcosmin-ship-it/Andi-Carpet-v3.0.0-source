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

## Lot nou — verificator pur pentru salvări OCR care par reușite

**Motivație:** actualul `_saveNewExpense` din `lib/expenses/expense_page.dart` raportează `ocr/document_save_failed` când `await widget.saveExpense(e)` aruncă o eroare; acest lucru **nu** demonstrează că suma dintr-un document salvat fără excepție este identică celei aprobate în formular. Codul real rămâne nealterat în acest lot.

**Modul nou:** `lib/vision/vision_expense_save_verifier.dart`, fără Flutter/Firebase/rețea. Primește `expectedBani` și `savedBani` ca întregi în **bani**, împreună cu dovada explicită că **există un răspuns de server autoritativ pentru ID-ul exact de document**. Emite verdictul `verified`, `awaitingServerEvidence`, `documentMissing`, `amountMismatch`, `invalidExpectedAmount` sau `inconsistentServerEvidence`.

- Dacă există numai cache local, scriere în așteptare, offline sau dovezi incomplete/contradictorii, **NU** declară document lipsă sau sumă greșită și nu emite cod de telemetrie.
- Doar absența confirmată a documentului ori diferența exactă în bani după verificarea serverului returnează **coduri fixe** `saved_document_missing` / `saved_amount_mismatch`. Valorile financiare NU sunt serializate, logate sau prezentate în diagnostic.
- `VisionDiagnosticAdvisor` conține explicații statice pentru aceste două coduri; recomandă verificare manuală, fără reîncercări automate sau risc de bon duplicat.
- **NU este conectat încă la Firestore real/ExpensePage**. Acoperă doar logica de interpretare și testele sintetice: sumă egală, diferență de 1 ban, document lipsă, offline, cache, date contradictorii, lipsă câmp, sumă invalidă, lipsa datelor în textul telemetriei.
- **Condiții pentru integrarea viitoare:** validarea rolurilor financiare din Issue #32, izolare UID și generație AuthGate din PR #33, selecția exactă a documentului/team/settlement, citire server reală (nu cache sau pending writes), tratarea offline/timing/idempotentă, protecție împotriva dublurilor și teste emulator + Android/web. Nu crea citiri/scrieri Firestore în acest lot.

**Statut:** verificator și teste separate, nu remediere încă a salvării OCR și nu detector activ în aplicația instalată. Buildul Android de probă nu are Firebase prin proiectare. Rezultatele CI trebuie confirmate pe ultimul commit înainte de a marca lotul validat.


## Lot nou — dovadă locală de persistență și fallback fără alarme false

În auditul manual al codului, `VisionErrorTelemetry` absorbea în mod intenționat erorile `flutter_secure_storage` (pentru a nu bloca aplicația), dar ecranul nu comunica dacă datele erau doar în RAM. `lib/vision/vision_persistence_status.dart` introduce un tracker **pur Dart, fără date personale**, care distinge: neverificat, doar citire confirmată, scriere în așteptare, stocare indisponibilă (doar RAM) și ultima scriere confirmată.

- `VisionErrorTelemetry` marchează schimbările după `log.record`, captează revizia fiecărui snapshot înaintea scrierii și marchează succes **numai după `await _storage.write`**, respectiv eșec după catch. Scrierile rămân serializate și debounce-ul deja implementat rămâne la 3 secunde. Nicio citire/scriere suplimentară, niciun listener/network nou.
- Confirmarea unei scrieri vechi în timp ce există evenimente noi **NU** certifică revizia curentă. Eșecul stocării este semnalat în interfață ca *posibil jurnal doar în memorie*, fără salvare automată pe server; revenirea unei scrieri reușite reabilitează statusul. Citirea de cache la startup nu certifică o nouă scriere.
- În `VisionDiagnosticsPage`, statusul este afișat informativ; pentru jurnale injectate din test se spune explicit că persistența nu a fost verificată, fără a folosi statusul global al dispozitivului.
- Teste pure pentru scriere întârziată, eșec citire/scriere, recuperare, callback-uri invalide și capturi vechi, plus test widget pentru jurnal injectat. Workflow-ul Android offline rulează testul nou; orice verdict final se comunică numai după CI pe HEAD.
- **Limitare:** indicatorul este o observație de runtime despre succesul apelurilor de stocare, **nu o garanție fizică de integritate a discului**, nici verificarea după restart. Testul manual Build #22 pentru un singur eveniment `×1` rămâne valid independent; nu trebuie instalat alt APK pentru acest lot.


## Jurnal sub presiunea spațiului — prioritatea severității

În `VisionErrorLog._trim()`, eliminarea respectă acum următoarea prioritate: **incidente rezolvate primele**, apoi între incidentele cu aceeași stare **warning înainte de error înainte de critical**, apoi cele mai vechi din fiecare nivel. Scopul este să păstreze o eroare critică activă chiar dacă există avertizări mai recente. Limitele stricte `maxEntries`, `maxBytes` și TTL rămân în vigoare, inclusiv pentru erori critice; nu promitem persistență nelimitată.

Teste noi acoperă: păstrarea criticelor deschise sub presiunea limitei, eliminarea unei critice rezolvate înaintea unui warning deschis și faptul că două critice respectă plafonul/TTL. Schimbarea afectează doar ordinea de retenție a rezumatelor locale; nu atinge Firebase, sume, conturi, transport, UI ori buildul instalat. CI se raportează separat pentru SHA exact.


## Raportul exportat prioritizează incidentele importante

`VisionDiagnosticReport.build` exportă cel mult 100 de evenimente și 16.000 de caractere. Până la acest lot, selecția se baza pe ultimele apariții, ceea ce permitea ca o eroare critică mai veche să fie omisă dacă apăreau multe warnings recente.

Noua ordine a copiei de raport: **incidente deschise înaintea celor rezolvate; critical > error > warning; apoi ultima apariție descrescător; în caz de egalitate, fingerprint stabil**. Aceasta este doar o selecție pentru raportul de diagnostic la copiere manuală, nu modifică ordinea/sintezele jurnalului local, datele păstrate sau prioritizarea la stocare. Nu adaugă rețea, upload ori acces la date personale.

Teste: critică deschisă veche plus 140 warning-uri recente, critică rezolvată după warnings active, limitele de volum/caractere, conservarea snapshot-ului local și absența mutațiilor. Raportați verdictul final CI doar pe SHA efectiv validat.


## Jurnal rezistent la corecții mici ale ceasului și cache cu metadate deteriorate

**Lot de hardening local, fără rețea/Firebase și fără schimbări de business.**

- La repetarea aceleiași erori, `lastSeen` nu mai scade când ceasul sistemului este ajustat puțin înapoi (de ex. sincronizare NTP de 20–30 secunde). `firstSeen` rămâne neschimbat, contorul crește și intervalul serializat `firstSeen <= lastSeen` rămâne valid la restaurare. Validarea existentă elimină în continuare evenimentele care sunt prea mult în viitor (>1 minut), deci **nu garantăm continuitatea la schimbări mari ale ceasului**.
- În `restore()`, un câmp `resolved` prezent, dar de tip greșit (String, număr etc.), duce la ignorarea acelei intrări corupte; nu mai este interpretat implicit ca `false`, ceea ce ar crea un incident activ fals. Lipsa câmpului continuă să fie acceptată ca format v1 vechi, pentru compatibilitate, iar `true`/`false` reale sunt păstrate.

Teste sintetice: eveniment repetat după ora mutată înapoi 30 s și apoi redeschiderea jurnalului, ora care avansează ulterior, metadate `resolved` corupte împreună cu intrări valide, compatibilitate cache v1 fără indicator. Nu sunt mutate, trimise, logate sau accesate date de utilizator. Nicio schimbare APK necesară pentru verificările pe telefon în această etapă.

**Verificarea finală a lotului este CI pe SHA exact; această descriere nu este un rezultat de test în sine.**


## Limita de cod diagnostic înainte de normalizare

`VisionErrorLog.safeCode` verifică acum mai întâi limita strictă de **48 caractere** și respinge instant șirurile goale ori mai lungi, înainte de `toLowerCase()`. Evităm crearea inutilă a unei copii de sute de KB dacă un apelant trimite accidental un mesaj brut sau un fragment OCR în loc de un cod constant. Intrarea devine doar `unknown`, nu este introdusă în log ca text sensibil; nu apare un nou transport sau API.

Teste: cod valid exact 48, cod invalid 49, normalizarea constantelor majuscule, respingerea e-mailurilor/șirurilor goale și a unui payload sintetic de 200.000 caractere fără exportarea lui. Aceasta este o măsură defensivă locală, nu un înlocuitor pentru auditul fiecărui adaptor altele decât coduri fixe.


## Proba de persistență nu este incident în raportul copiat

`VisionDiagnosticReport.build` separă acum exclusiv evenimentul sintetic cu perechea fixă `vision_test/persistence_probe` de incidentele efective, identic cu interpretarea din ecran și advisor. Linia `Incidente locale` exclude aceste probe, iar `Probe locale (nu sunt erori)` le inventariază separat; fiecare probă inclusă în export este etichetată `test` / `proba_locala`, nu `warning`/`deschis`.

Raportul rămâne limitat la 100 de evenimente și 16.000 de caractere; incidentele reale au întâietate față de probe, astfel încât ultimele să nu ascundă o eroare serioasă. Dacă limita exclude linia unei probe, sumarul distinct rămâne vizibil, cu nota de trunchiere. Numai această combinație exactă este considerată sintetică; alte evenimente reale din aceeași zonă nu sunt ascunse.

Teste unitare: numai probe repetate (0 incidente, 1 fingerprint test și contor 2), eroare reală + probă cu severitate critică, raport cu 110 erori plus probă și limita 100; verificare că exportul nu modifică datele jurnalului. Nu adaugă upload, Firebase ori instrumentare operațională. CI pe SHA exact este obligatoriu înainte de a marca lotul validat.


## Contor clar pentru probele manuale Vision

În raportul copiat, `Probe locale (nu sunt erori): N tipuri` exprimă numărul de fingerprinturi de probă, iar `Aparitii ale probelor locale: M` însumează apăsările testului înregistrate. Exemplu: dacă proba de persistență Android apare ca `×4`, raportul explică **1 tip, 4 apariții, 0 incidente reale**. Acest sumar există chiar dacă liniile de probă sunt excluse de limita de export de 100 evenimente sau 16.000 caractere; incidentele reale au prioritate.

Teste noi: o probă Android repetată de patru ori; două platforme simulate (4+2 apariții, 2 fingerprinturi); raport trunchiat cu 110 incidente reale și două apariții ale probei; jurnalul și exportul rămân nemutate și fără upload. Nu se adaugă scrieri Firebase și nu se schimbă semnificația categoriei de incident. Validarea de închidere se face numai pe CI aferent HEAD final.


## Indicatorul de persistență la callback-uri întârziate (lot izolat)

Trackerul pur `VisionPersistenceTracker` ține acum cont de **ultima revizie pentru care a eșuat salvarea**. Un succes întârziat pentru o revizie mai veche nu mai poate șterge starea `memoryOnly` a unei scrieri ulterioare nereușite. Ordinea reală a scrierilor rămâne serializată în `VisionErrorTelemetry`, dar această măsură apără contractul de status și dacă un adaptor schimbă ordinea notificărilor.

Un eșec ulterior de read sau de rescriere a aceleiași revizii are întâietate față de indicatorul `saved`: interfața nu mai afirmă că stocarea este accesibilă doar fiindcă o scriere anterioară a reușit. Revenirea la `saved` necesită apoi succesul unei scrieri care acoperă ultima revizie eșuată. **Nici un payload, UID, coordonată, eroare brută sau document financiar nu este introdus în tracker.**

Patru teste noi: failure revizia 2 urmat de success tardiv revizia 1; eșec vechi după revizie nouă confirmată; rescriere aceeași revizie eșuată; eșec de citire după scriere confirmată. Invariantele pentru callbackuri negative/viitoare și succesuri care nu acoperă revizia curentă rămân testate. Este logică exclusiv locală, fără Firebase, UI nou ori interacțiune cu PR #28. Validarea de închidere se face pe SHA exact în CI.


## Totaluri distincte pentru incidente reale versus probe (lot independent)

Raportul diagnostic copiat afișează acum **`Incidente locale: N`** (fingerprinturi reale distincte) și **`Aparitii ale incidentelor: M`** (suma repetărilor agregate), separat de `Probe locale`/`Aparitii ale probelor locale`. Exemplu sintetic: OCR save failure ×3 + probă de persistență ×4 produce 1 incident real, 3 apariții ale incidentelor, 1 tip de probă și 4 apariții ale probelor. Totalurile sunt extrase din jurnalul local deja limitat și rămân afișate chiar dacă exportul trunchiază liniile la 100 de evenimente. Nu sunt trimise sume, texte OCR, UID-uri, tokenuri ori poziții; zero acces suplimentar Firebase, zero schimări în PR #28. Teste unitare verify summary + unchanged snapshot. Așteptați CI pe SHA-ul final pentru acceptanță.
