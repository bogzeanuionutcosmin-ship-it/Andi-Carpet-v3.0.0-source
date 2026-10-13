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
