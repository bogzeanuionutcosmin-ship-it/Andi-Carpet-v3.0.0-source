# AndiCarpet — fuziunea Ultron + Jarvis → Vision (țintă de cost incremental 0 lei)

**Data deciziei:** 2026-10-13  
**Stare:** arhitectură și prioritate aprobate în principiu de proprietar, **neimplementate**. Nu se autorizează modificări de producție, integrarea unui API plătit sau deploy.  
**Surse obligatorii:** `ChatGpt`, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, toate regulile funcționale confirmate. 

## 1. Scop și sensul numelor

- **JARVIS** = aplicația AndiCarpet existentă: interfața Flutter, identitatea/rolurile, datele, fluxurile de lucru, Learning-ul operațional și serviciile curente.
- **ULTRON** = rolul asistentului ChatGPT de a analiza proiectul și diagnosticul, a explica și a propune schimbări sigure în GitHub; **această conversație nu rulează autonom și permanent în telefon ori pe server**.
- **VISION** = sistemul unificat din aplicație, care coordonează semnalele, regulile, explicațiile, diagnosticarea, sugestiile, activitățile autorizate și, doar unde s-a aprobat, automatizarea. Vision nu trebuie confundat cu un model lingvistic plătit.

**Observație la 2026-10-13:** căutarea numelor Ultron/Jarvis/Vision în indexul de cod GitHub nu a returnat module tehnice distincte. „Fuziunea” este o integrare arhitecturală și funcțională, nu îmbinarea presupusă a trei programe deja separate. Înainte de implementare verificați codul efectiv pe ramura curentă, importurile și dependențele.

## 2. Prioritate față de Learning și ordinea lucrărilor

1. Continuăm finalizarea **modularizării și CI** din PR #17 și validarea regulilor deja aprobate; nu facem merge automat.
2. **Înainte de implementarea noilor funcții Learning GPS**: definitivăm contractele pentru Vision/Jarvis/Ultron, responsabilitățile modulelor, accesul, evenimentele, observabilitatea, schema de cost și acceptanța testelor. Acest document reprezintă punctul de pornire; completăm auditul de cod, date și dependențe.
3. **Prima implementare nouă** după modularizare + reguli este infrastructura comună **Vision/Diagnostics & Self-Healing**: colectare diagnostic sigură, bus local de evenimente sau mecanisme existente fără dubluri, stare verificabilă, motor local de reguli, Learning adaptiv, Developer Console limitată, notificări și acțiuni explicabile.
4. Numai apoi conectăm fluxurile Learning (GPS, START, propunere STOP), OCR, hartă, diurnă, notificări etc. pe aceeași infrastructură, **cu teste pentru fiecare etapă**, înainte de staging și producție. Cerința «fuziune înainte de implementare și teste» se interpretează ca *înainte de implementarea/testarea noilor funcții*, NU drept interzicerea testelor necesare pentru Vision.
5. Testare contracte/unitate/integritate/regresie/CI pe ramură izolată, etapă de staging, audit costuri și rollout controlat numai cu aprobare explicită. Nu se face deploy automat.

## 3. Componentele Vision în regim 0 lei suplimentari

**A. Vision Core local/offline-first:** mașini de stare deterministe pentru evenimentele operaționale, învățare statistică adaptivă unde este fezabilă pe dispozitiv, reguli de prioritizare, deduplicare, explicații din date concrete, scor de încredere + «de ce?», fallback la date insuficiente. Nu prezentăm reguli/euristici drept conversație GPT.

**B. Vision Observability:** diagnostic de erori/crash/status/permisiuni GPS/sincronizare, buffer local mic și cu retenție, agregări/eșantionare; upload doar când este util, autorizat și se încadrează în cotele existente. Nu încărcăm permanent jurnalul complet în Firestore.

**C. Vision Learning GPS:** implementează ulterior deciziile confirmate 15–19. Detectare sosire/prezență/plecare cu monitorizare adaptivă inclusiv în fundal dacă sistemul permite; START automat doar la încredere suficientă, fără START dublu dacă utilizatorul a pornit manual; săli vecine și GPS incert -> confirmare; plecările temporare nu devin STOP; STOP numai cu confirmare; corectările verificate antrenează gradual fără rescrierea istoricului.

**D. Vision Assistant în aplicație:** panou/centru de acțiuni accesibil prin interfața existentă, «Ce trebuie să fac acum?», explicații pentru decizii, sugestii, identificarea problemelor, status sincronizare/GPS/OCR. Proactiv numai la evenimente importante, respectă Nu deranja (notificările normale rămân interne), rolurile și permisiunile; notificarea tehnică obligatorie Android pentru monitorizarea GPS este tratată separat. Niciun «agent» inventat care ar pretinde că ChatGPT supraveghează continuu datele.

**E. Developer Console / Ultron Bridge:** analize read-only, diagnostice agregate, export minimizat de context pentru asistarea dezvoltării, propuneri de reparații/PR cu validare și autorizare. Conexiunea la ChatGPT prin API/chat/connector este **opțională** și se activează doar cu metode oficiale, consimțământ și buget aprobat. Acces GitHub nu înseamnă acces Firebase live.

## 4. Regula strictă de cost și adevărul despre AI

- **Țintă: 0 lei cost suplimentar față de infrastructura deja existentă**, fără a garanta că toate serviciile externe sunt gratuit nelimitate. Măsurăm consumul real Firebase/Mapbox pe cont și evităm depășirea cotelor; oprirea funcțiilor opționale necritice este preferabilă taxării involuntare. Nu schimbăm planul ori modul de facturare fără acord expres.
- **ChatGPT Plus nu include apeluri generale gratuite către API-ul OpenAI**, care are facturare separată. Prin urmare, un **GPT cloud integrat, activ 24/7, pentru toți utilizatorii, cu cost 0 garantat** nu este o promisiune realistă. Nu punem tokenuri ChatGPT, cookie-uri sau chei API în APK/web, nu automatizăm interfața ChatGPT pentru a eluda abonamente sau termeni.
- În modul gratuit, Vision poate fi **activ funcțional** prin reguli on-device, observații locale, diagnostice și sincronizări în cote, dar nu este un GPT-6 autonom în aplicație. Consultarea ChatGPT poate rămâne manuală sau prin mecanism oficial disponibil, fără costuri noi garantate.
- Favorizăm prelucrarea pe telefon, cache-ul local sigur, agregarea, evenimentele în locul pollingului scump, reutilizarea listenerelor existente și retenția limitată. Nu activăm periodic Cloud Functions sau un server permanent fără evaluarea planului curent; Cloud Functions și alte servicii pot necesita Blaze chiar când au cote gratuite.
- **Hard guardrail:** nicio funcție AI plătită, credit API, abonament nou, upgrade Spark/Blaze, schimbare Mapbox Billing ori serviciu cu taxare fără cerere și aprobarea expresă a proprietarului.

## 5. Siguranță și control

- Read-only ca implicit; separare detectare/sugestie/decizie/scriere. Doar automatizările explicit aprobate (ex. START în condițiile stricte) pot muta starea.
- Autentificare, roluri și autorizare verificate server-side la orice acces/acțiune. Rolul profesional «developer» nu înseamnă «director/admin» și nu dă acces la datele colegilor prin simpla etichetă.
- Datele sensibile (chat privat, finanțe, GPS brut, tokenuri, fotografii OCR) nu sunt trimise implicit la AI/cloud, nici salvate în loguri; consimțământ, minimizare, mascarea datelor și retenție.
- Jurnalizare minimală de acțiuni importante, confirmări umane la operațiuni financiare/administrative/STOP și la START incert; propunerile de cod se trimit prin PR+CI cu aprobare, niciodată deploy autonom.
- Actualizare estimări Learning doar cu observații confirmate, control anti-duplicat, gestionare multi-dispozitiv/offline și rollback dacă precizia scade.

## 6. Ce trebuie auditat înainte de prima linie nouă de cod

- Inventarul codului actual după PR #17: unde există diagramele/modulele reale de Learning, diagnostic, GPS, OCR, notificări și stări; ce logică este deja duplicată și ce se poate reutiliza.
- Starea exactă a planului Firebase, costuri/cote/erori și politica Mapbox, fără a presupune acces la facturare.
- Nivelul real al permisiunilor Android (inclusiv localizare background/foreground service), compatibilitatea cu «Nu deranja», web/iOS unde e relevant.
- Schema minimă a evenimentelor Vision, identitățile stabile ale intervențiilor, limitele de retenție și contractele read-only/write.
- Probe măsurabile: false START/STOP, săli vecine, pornire manuală concurentă, ecran blocat, date lipsă, multi-dispozitiv, offline/reconectare, cost per eveniment și regresii din modularizare.

## 7. Criterii de acceptare

- Panoul Vision explică ce observă și ce nu știe, cu evenimente utile, fără notificări inutile.
- GPS/Learning exact, sigur și testat pe telefon, inclusiv pentru două săli apropiate și apăsare manuală START înaintea sistemului.
- Zero START/STOP dublu; niciun STOP automat nesolicitat; fără schimbări retroactive de istoric.
- Funcțiile esențiale merg și fără conectare la un AI plătit; eșecul AI nu blochează intervențiile.
- Nicio plată/upgrade/cheie secretă nouă fără autorizare; consum măsurat și sub limitele relevante.
- CI și teste validate, raport de impact, aprobare pentru staging/merge/deploy. **Nu declarați Vision «integrat» până când acestea nu au fost implementate și verificate.**

## 8. Surse și verificări de actualizat la implementare

- ChatGPT Plus vs API: https://help.openai.com/en/articles/6950777-what-is-chatgpt-plus
- Firebase pricing și limite: https://firebase.google.com/pricing ; https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- Reguli și handoff din același repository, actualizate continuu după deciziile proprietarului.

## 9. Audit preliminar read-only al codului existent (2026-10-13)

Au fost verificate prin citire directă pe ramura de modularizare PR #17 (`refactor/home-codecs-sync-20261012`), **fără modificare de cod**:

- `lib/learning/duration_estimates.dart`: **există**, ~63 linii, deja calculează `LearnedDurationEstimate` (durată, explicație, încredere, eșantioane) cu Learning configurabil; este legat momentan prin `part of '../main.dart'`. **Este punct de reutilizare**, dar învățarea duratei nu dovedește implementarea detecției GPS/sosire/plecare.
- `lib/notifications/push_diagnostics_page.dart`: **există**, ~386 linii, diagnostic FCM/permisiuni/token; poate alimenta Vision Observability, fără a presupune că acoperă toate platformele.
- `lib/bootstrap/firebase_initialization.dart`: **există**, inițializare Firebase și `_firebaseMessagingBackgroundHandler`, încă legat cu `part`.
- `lib/learning/learning_service.dart` și `lib/ai/vision.dart`: **nu există la aceste căi pe această ramură**, fără a exclude alte implementări sub alt nume.
- `pubspec.yaml` există; pachetele și compatibilitatea modelului local necesită audit separat, nu le considerăm deja alese.

**Concluzie audit preliminar:** există piese reale de Learning pentru durate, diagnostic push și bootstrap, dar nu există dovezi suficiente pentru a declara Ultron/Jarvis/Vision deja «fuzionate» sau GPS Learning complet. Urmează inventarul exact al fișierelor/referințelor și contractelor înainte de crearea serviciilor Vision.

## 10. Decizia arhitecturală confirmată explicit: Vision autonom, AI online opțional (2026-10-13)

După explicația directă «AI local vs AI online», proprietarul a răspuns **«Ok, de acord»** la recomandarea de a construi Vision autonom, necondiționat de un model cloud plătit, dar extensibil pe viitor.

**Consecințe obligatorii pentru design:** contract abstract pentru un provider opțional AI; implementare implicită fără model extern, cu reguli, diagnostic și explicații locale; timeout, circuit breaker și fallback pentru providerul online dacă va fi vreodată aprobat; zero apeluri la API extern în configurația implicită; niciun token/secret în APK ori client web; niciun cost nou sau modificare de billing fără aprobarea expresă a proprietarului; cererile financiare, START/STOP și datele de producție rămân supuse autorizării și auditului.

**Criteriu de acceptare distinct:** o instalare fără nicio cheie AI și fără conectare la un model lingvistic trebuie să poată folosi funcțiile de bază AndiCarpet și componentele locale Vision prevăzute; simularea indisponibilității AI cloud nu poate bloca operațiunile. Se vor testa funcțiile efectiv implementate înainte de a pretinde disponibilitatea lor.

**Status:** decizie documentată; fără implementare, integrare API, contract de plată ori deploy.

## 11. Audit aprofundat read-only pe PR #17 — componente reale, riscuri și traseu Vision (2026-10-13)

**Sursă inspectată:** `refactor/home-codecs-sync-20261012`, commit `29f394478ea5fd86822efd3a138766067c3f9694`; PR #17 **OPEN**, fără merge/deploy. Arbore GitHub: **476 intrări** (fișiere + directoare; nu 476 module). `lib/main.dart` are ~13.958 octeți și ~198 linii, iar `lib/home/home_page.dart` are ~95,6 KB, `lib/map/map_page.dart` ~55,5 KB, `lib/schedule/program_page.dart` ~66,9 KB. Modularizarea a avansat semnificativ, dar ecranele mari păstrează încă logică și stări puternic cuplate prin `part of '../main.dart'`.

**CI verificat pentru commitul exact:** run [38220879828](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38220879828), `completed/success`, **5/5 joburi**: Node projection, Firestore emulator authorization, Functions syntax/dependencies, Flutter web build, Python source/security contracts. Acesta NU este un test pe telefon sau o garanție a fluxurilor GPS reale.

### Inventarul de integrare confirmat prin citirea sursei

| Domeniu Vision | Cod real găsit | Ce se poate reutiliza și ce NU este confirmat |
|---|---|---|
| GPS în fundal + mod adaptiv | `lib/home/home_page.dart`: `_startAdaptiveLiveLocation`, `_startNativeBackgroundLocationStream`, `_updateNativeLocationProximityBoost` | Geolocator streams, mod `economic/live/offline`, precizie adaptivă, indicator Android foreground; nu s-au validat încă pe dispozitiv restricțiile OS/fiabilitatea în background |
| Sosire / plecare / activitate | `_applyWorkAutomationFromPosition`, `_handleArrivalDetected`, `_saveArrivalStart`, `_maybeAutoCloseResolvedSchedules` | Filtre precizie <=80m, poziție proaspătă <=2 min, viteză <=8m/s, proximitate și dwell; **START la sosire cere ÎNTOTDEAUNA confirmare**, nu e încă START automat bazat pe Learning; STOP de intervenție e propus, nu executat |
| Learning durată / trasee | `lib/learning/duration_estimates.dart`, `lib/schedule/program_page.dart`, `lib/admin/admin_learning_actions.dart` | Durata din >=3 execuții valide, scor explicabil și preferințe Learning; analiza rutelor și confirmări, dar NU un model GPS antrenat din corectările de sosire/plecare |
| Push, diagnostic | `lib/notifications/push_diagnostics_page.dart`, `lib/home/home_page.dart`, `functions/index.js` | FCM token, permisiuni, salvare, notificări de chat/sistem; regulile noi DND strict/acțiuni în așteptare și sincronizarea lor NU sunt încă implementate |
| Hartă + rutare + consum Mapbox | `lib/map/map_page.dart`, `lib/mapbox_services.dart` | `MapboxServices` are contor local pentru Directions/Optimization/Map Matching și cache de **10 minute numai pentru distanțele identice**; contorul nu este oficial sau persistent și NU include requesturile Static Tiles încărcate în altă parte |
| OCR | `lib/ocr_parser.dart`, `lib/ocr_service_mobile.dart` + web/stub | ML Kit local pe mobil + parser pentru sume și date; problema istorică la salvarea sumelor necesită un test cap-coadă separat; nu presupunem că parserul garantează salvarea |
| Date/stare/drepturi | `lib/models/app_data_models.dart`, `lib/home/home_page.dart`, `functions/index.js` | `AppSettings.learning`, `AppNotification`, `CentralizerRecord`; înainte de Vision sunt necesare un API intern de evenimente și tranziții atomice fără duplicare |

### Riscuri constatate sau plauzibile — prioritate înainte de automatizare nouă

1. **P0 — cursă START manual/automat și două dispozitive:** `_saveArrivalStart` verifică `_homeLatestRecord` din lista locală, apoi `_saveRecordDirect` face `records.doc(record.id).set(...merge:true)`; nu s-a identificat în acest traseu o tranzacție server-side care să garanteze un singur START la două cereri concurente. Posibilă duplicare când ambele dispozitive creează ID-uri diferite din cache-uri depășite. În Vision cerem **identitate stabilă a intervenției + verificare/commit atomic + test de concurență**. Nu afirmăm fără test că în producție s-au produs duplicate.
2. **P0 — săli vecine:** lista de candidate este sortată după distanță și alege prima sală; nu se observă un filtru separat pentru egalitate/ambiguitate între două săli valide simultan. Regulile aprobate cer confirmare fără alegere automată atunci când mai multe săli sunt apropiate.
3. **P0 — DND nu este aplicat server-side:** `functions/index.js` -> `sendToUser` expediază mesaje FCM cu `notification` afișabilă și sunet implicit; `userNotificationAllowed` tratează `mandatory` cu bypass și permisive `return true` la erori. Acest cod NU poate asigura «zero push afișabile» în Nu deranja; este o cerință nouă de implementat ulterior, **fără a ascunde notificarea tehnică foreground GPS cerută de Android**.
4. **P1 — detecția depinde de o scriere Firestore reușită:** `_shareLiveLocationIfAllowed` salvează mai întâi `liveLocations` prin `await ...set` și **abia apoi** cheamă `_applyWorkAutomationFromPosition`; dacă scrierea eșuează sau conexiunea e offline, traseul local de detecție nu este executat. Vision trebuie să separe **detecția locală** de **sincronizarea către cloud**, să tamponeze evenimentele minim și să verifice autorizarea/starea la orice commit operațional.
5. **P1 — cost + minimizarea datelor:** la fiecare heartbeat GPS, `liveLocations/{uid}` primește inclusiv `photoBase64`, nume și echipă, plus coordonate și timestamp; posibilă mărire nejustificată a payloadului, scrierilor și traficului de la ascultători. Evaluăm păstrarea profilului separat (ID de referință), limitarea heartbeatului, agregări, fără a compromite precizia. Nu ștergem date existente fără audit de acces.
6. **P1 — stări GPS efemere:** `_autoInsideSince`, `_autoOutsideSince`, `_arrivalPromptCounts` și `_automationNotified` stau doar în memoria widgetului și se resetează la restart/relogin; pot exista re-prompturi, cursă între două dispozitive și lipsa probelor după offline. Vision definește tranziții și chei stabile, cu retenție economică.
7. **P1 — indicator de fundal / permisiuni:** `AndroidSettings.foregroundNotificationConfig` există deja. Se testează pe versiuni Android și dispozitive reale, fără promisiuni că notificarea tehnică permanentă poate fi ascunsă dacă OS o impune. Nu dezactivăm Nu deranja manual pentru mesajele normale.
8. **P2 — testare insuficient specifică Vision:** `test/grafic_learning_notifications_contract_test.py` și multe teste de igienă verifică existența unor fragmente/simboluri, nu scenariile GPS reale ori concurența. Extindem ulterior teste unitare de tranziție, Firestore emulator/permisiuni, FCM DND și scenarii fizice de sală vecină/ecran blocat.

### Ordinea recomandată a integrării, după modularizare

**V0:** extragerea unei interfețe pure `VisionEvent` + `VisionObservation` + `VisionDecision` fără mutații de business; adapter peste `HomePage` pentru GPS/FCM/Learning existent; teste deterministe.  
**V1:** motor local de detecție și explicații, permisiuni/minimizare, jurnal în cache limitat, fără AI plătit sau servicii noi.  
**V2:** contract server-side pentru tranzacțiile START/STOP și idempotentă multi-dispozitiv; fără activare START automat până la aprobarea și testarea acestui strat.  
**V3:** notificări compatibile DND, Learning GPS pe corectări, întărirea OCR/Mapbox și dashboard Vision, fiecare cu teste și analiză de cost.  
**V4:** staging + teste reale Android/background/offline/concurență și măsurarea consumului înainte de orice rollout.

**Acest audit a fost numai citire de fișiere GitHub și verificare CI; niciun test nou executat, niciun cod de producție schimbat, fără merge sau deploy.**

## 12. Vision Error Log — primă componentă de implementat, cost minim (2026-10-13)

**Cerință explicită nouă:** proprietarul vrea să putem cunoaște erorile relevante și să se șteargă periodic datele temporare, fără consum excesiv de memorie sau costuri. Acesta este un criteriu de acceptare **obligatoriu pentru prima versiune Vision**, nu o opțiune de amânat după Learning GPS.

**Audit suplimentar read-only în PR #17:** `lib/main.dart` nu conține mecanisme de colectare globală `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded` în versiunea inspectată; `pubspec.yaml` nu declară `firebase_crashlytics`; `home_page.dart` raportează local prin `debugPrint` (13 apariții în fișier), iar `functions/index.js` are `console.log/warn/error` (18 apeluri). Există diagnostic FCM, dar nu un sistem centralizat de raportare pentru toate categoriile. Nu afirmați că este deja implementat sau că toate erorile sunt vizibile.

**Design recomandat:**

1. `VisionErrorEvent` = timestamp, fingerprint determinist, categoria, severitate, modul, aplicație/versiune/platformă, stack sanitizat minim, primă/ultimă apariție, număr de repetări, status, referință de diagnostic fără date personale.
2. `VisionErrorCollector` = interceptori de erori Flutter/framework/async, adaptori pentru excepții operaționale deja gestionate, colector Functions prin infrastructura existentă, buffer local limitat; verificare de suport pe fiecare platformă și evitare logări în buclă.
3. `VisionErrorStore` = ring buffer local configurabil, pornind de la **max. 500 evenimente sau ~1 MB și max. 7 zile**, prioritate pentru evenimente nepredate; purjare la deschidere și întreținere incrementală fără job periodic costisitor.
4. `VisionErrorAggregator` = deduplicare pe fingerprint, rate limiting, păstrare statistici compacte de tip prima/ultima apariție + count. După sincronizare sigură și consent/drepturi, upload **numai dacă se încadrează în cote**, cu fallback local și stări de trimitere oneste.
5. `VisionErrorPanel` = lista administrativă autorizată pentru incident deschis/rezolvat, căutare după modul/severitate, ultima apariție și link la funcția afectată; notificările critice respectă Nu deranja pentru push-uri.
6. `VisionErrorRetention` = recomandare de retenție agregate rezolvate **30 zile** după rezolvare; incidente deschise persistă ca sinteză compactă până la rezolvare; detaliile brute se șterg după termen/limita de volum. Nu șterge niciodată istoricul operational/financiar sau auditul obligatoriu. Calibrează pragurile după testele de volum și verificarea costului, nu presupune TTL gratuit.
7. **Teste**: erori UI/framework/async, startup când Firebase e indisponibil, GPS permisiune refuzată, OCR sumă recunoscută dar nesalvată, funcții backend, offline/reconectare, dubluri 10.000, protecție date, plafon local, curățare calendaristică, autorizare, retry sigur și cost măsurat.

**Plan:** include colectorul, panoul și curățarea în prima etapă Vision după modularizarea/contractele de bază, înainte de noile automatizări. Nu promite supraveghere continuă de către ChatGPT/GPT prin API la 0 lei: în lipsa conexiunii sau cu aplicația oprită, doar datele colectabile local/cloud pot fi consultate ulterior. Nu modifica acum codul, Firebase, facturarea ori deploy-ul.

## 13. Incidente documente PV Magic/Million — salvare nativă și zero cost (2026-10-13)

Auditul bibliotecii Documente identifică separarea între **PDF asset Magic** și **fișă Firestore fără PDF** pentru Million; Android PDF era rutat la share, web la download. Lotul propus pe ramura separată `fix/documents-pv-download-20261013` schimbă rutarea de export nativă la dialogul sistemului `FilePicker.saveFile` existent, păstrează share separat, grupează fișele PV fără migrare, protejează ștergerea metadatelor prin admin/confirmare și permite ascunderea reversibilă a cardului Magic (config în colecția documents cu autorizația existentă). Fără costuri noi sau Firebase Storage/Rules. Problema fișierului Million nu este rezolvată prin UI: cerem PDF original sau aprobare pentru mecanism de stocare sincronizată securizată. Detalii `docs/REPARATII_PV_MAGIC_MILLION_ANDROID_2026-10-13.md`. Validarea Android real încă necesară, fără deploy.

## 14. PV Million: includere locală în APK fără cost cloud (2026-10-13)

Utilizatorul a furnizat originalul PDF Million (A4, o pagină, hash SHA256 `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`). Strategia confirmată: fișier `assets/pv_million.pdf` în APK, alături de Magic; fără Firebase Storage, duplicare Firestore ori servicii cu cost. Codul nou din PR #20 afișează Million și descarcă/partajează exclusiv după verificarea prezenței assetului, dar transferul binar în repository este în așteptare; Work sau GitHub Upload files trebuie să-l adauge pe ramura PR și să ruleze testele pe HEAD final. Nu se fac automat modificări în datele reale, merge sau deploy.
