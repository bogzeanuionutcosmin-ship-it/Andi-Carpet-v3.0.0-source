# AndiCarpet — Condiții obligatorii de lucru și reguli de dezvoltare

## Condiții obligatorii de lucru

Aceste reguli au prioritate în analiza, proiectarea, modificarea și testarea codului. Se aplică fiecărei implementări, corecții, refactorizări și optimizări.

1. **Analiză înainte de implementare.** ChatGPT inspectează întotdeauna codul și documentația relevante înainte de a modifica ceva: verifică dacă funcționalitatea există deja, dacă există duplicate, dependențe, efecte secundare și detalii care ar putea fi omise.
2. **Lucru curat și proiectare riguroasă.** Analizăm și proiectăm în detaliu, luând în calcul ipotezele rezonabile, cazurile-limită, excepțiile, concurența și impactul asupra întregii aplicații.
3. **Integritatea codului existent.** Orice implementare trebuie să respecte celelalte funcții, să nu degradeze comportamente existente, să nu dubleze logica, să nu lase cod mort, fragmente nefolosite sau caractere rătăcite. Se verifică importurile, referințele, compatibilitatea, testele și build-ul.
4. **Defectele descoperite sunt semnalate și prioritizate.** Când ChatGPT găsește probleme de funcționare, explică impactul, propune rezolvări și, dacă este necesar, schimbări de comportament. Corecțiile urgente de siguranță și integritate au prioritate; schimbările funcționale se discută înainte de aplicare.
5. **Inițiativă tehnică.** Dacă ChatGPT identifică o soluție mai bună, mai simplă, mai sigură sau mai eficientă, o propune imediat, cu argumente și compromisuri, fără să o impună tacit.
6. **Eficiența bazei de date.** Evităm creșterea inutilă a stocării, documentele duplicate, scrierile și citirile excesive, listener-ele redundante și costurile Firestore. Monitorizăm utilizarea și proiectăm pentru a rămâne în limitele planului; nu pretindem că o modificare garantează consum zero.
7. **Internet, GPS și timp real.** Aplicația este proiectată pentru conectivitate și localizare: actualizări cât mai prompte, sincronizare coerentă, tratarea pierderii conexiunii, permisiuni GPS, consum rezonabil de baterie și date, protecția confidențialității și recuperare după erori. „Timp real” înseamnă latență minimă fezabilă, nu promisiunea imposibilă de funcționare online fără rețea.
8. **Logica funcționării are prioritate maximă.** Cerințele utilizatorului sunt analizate critic. Dacă o idee este contradictorie, riscantă, ineficientă sau tehnic nepotrivită, ChatGPT explică de ce și propune alternativa logică și corectă; nu implementează automat o cerință greșită doar pentru a o confirma.
9. **Verificare înainte de finalizare.** Pentru orice schimbare: inventar de impact, teste relevante, CI/build unde sunt disponibile, documentarea deciziilor și raportarea sinceră a rezultatului. Nu confundăm testele structurale cu validarea funcțională. Nu facem deploy sau modificări de producție fără aprobare explicită.

---


> Document separat de nota operațională `ChatGpt`. Este un registru al DECIZIILOR și al planului aprobat de proprietarul proiectului. Nu confundați propunerile viitoare cu funcționalități deja implementate. Actualizați-l continuu când se stabilesc reguli noi.

## 1. Ordinea obligatorie a etapelor — decizie 2026-10-12

1. **Terminăm curățarea și modularizarea integrală a aplicației existente**, fără schimbări neautorizate de comportament, cu teste de regresie și CI verde pentru fiecare lot.
2. **După curățare, definim împreună regulile și condițiile fiecărei categorii/funcții**: scop, ecrane, date, roluri, permisiuni, validări, fluxuri, limite, excepții, notificări, sincronizare, mod offline, securitate și teste. Discutăm și aprobăm fiecare categorie înainte de implementarea schimbărilor funcționale.
3. **Prima implementare după aprobarea regulilor**: infrastructura AndiCarpet Diagnostics & Self-Healing, inclusiv colectarea erorilor de pe toate platformele, cache local sigur, mecanisme de recuperare, Developer Console privată și integrarea AI etapizată.
4. **Abia după aceea** abordăm celelalte funcții și îmbunătățiri ale aplicației, conform priorităților și regulilor aprobate.

**Nu inversați această ordine** doar pentru că o funcție nouă pare utilă. Excepțiile se decid explicit cu proprietarul.

## 2. Integrarea ChatGPT — decizie de principiu

- Obiectiv: aplicația să poată fi inspectată tehnic direct, să furnizeze diagnostic, să genereze sugestii de îmbunătățire, să pregătească schimbări în GitHub și să le valideze prin teste.
- **Acces amplu la diagnostic și analiză; acces controlat la modificări.** Nu se oferă agentului sau clientului acces nelimitat la producție.
- **Developer Console** destinată exclusiv proprietarului/directorului autorizat, cu autentificare, autorizare pe server, audit și separarea operațiilor read-only de cele care modifică starea. Ascunderea butonului în UI nu reprezintă securitate.
- Integrarea presupune backend securizat și API AI / mecanism de conectare dedicat. O conversație ChatGPT obișnuită **nu primește automat acces persistent, transmisii live sau execuție autonomă**.
- Propunerile de cod: ramură/PR, analiză de impact, teste, CI, aprobare. Modificarea datelor reale, regulilor Firestore, permisiunilor, secretelor, publicarea APK/iOS/Windows/web și deploy-ul necesită aprobare explicită.
- Mediu **staging separat de producție**, inclusiv Firebase de test, înainte de activarea fluxurilor automate.

## 3. Error logging multiplatformă — decizie de principiu

- Colectare erori de pe **Android APK, iOS, Windows și web**, cu o schemă comună: versiune aplicație/build, platformă, modul/funcție, cod de eroare, timestamp, tipul evenimentului, severitate, stack trace sanitizat, stare rețea/sincronizare relevantă, identificator tehnic pseudonimizat.
- Folosirea Firebase Crashlytics unde platforma este suportată; **colectori alternativi pentru Windows/web**, după validarea suportului real și a costurilor.
- Trimitere cât mai rapidă când există internet; buffer local limitat și sincronizare ulterioară când dispozitivul revine online. **Nu se promite latență zero sau transmisie continuă garantată**.
- Deduplicare, grupare, rate limiting, retenție limitată, gestionarea volumului/costurilor și alerte pentru erori critice. Logurile trebuie să fie utile, dar să nu degradeze aplicația.
- Raportarea către analiza AI se face **prin backend controlat**, cu redacție/sanitizare și filtre de acces, nu prin trimiterea nefiltrată a tuturor logurilor într-o conversație.
- Nu se includ în loguri parole, tokenuri, chei API, conținutul conversațiilor private, date personale nenecesare sau alte secrete. Respectăm consimțământul/informarea și cerințele legale aplicabile.

## 4. Cache și instalare / offline — decizie de principiu

- La prima pornire, aplicația creează **automat structura locală necesară**; la actualizare, verifică versiunea schemei, migrează sau reconstruiește în siguranță datele regenerabile.
- Cache țintit pentru configurări, resurse, date permise pentru offline și o **coadă locală separată pentru erori** când lipsește internetul.
- Datele sensibile se minimizează și se protejează; expirare, limite de spațiu, invalidare și criptare unde este necesar.
- **Cache-ul regenerabil este distinct de operațiile utilizatorului nesincronizate.** Curățarea cache-ului nu poate șterge munca offline în așteptarea sincronizării.
- Operațiile retrimise după întreruperi trebuie să fie idempotente sau protejate contra duplicatelor; se definesc politici pentru conflicte și erori permanente.

## 5. Self-Healing — limite aprobate de principiu

- Recuperare automată doar pentru probleme locale și reversibile: reconectare, retry cu backoff pentru erori temporare, reconstrucție cache regenerabil, avertizare de versiune incompatibilă.
- Problemele de permisiuni Firebase, securitate, date, logică de business sau deploy sunt **diagnosticate și propuse spre remediere**, nu corectate autonom în producție.
- Orice remediere automată necesită limite, jurnal de audit, teste și mecanism de rollback.

## 6. Șablonul regulilor pentru fiecare categorie — de completat DUPĂ curățare

Pentru fiecare categorie documentăm și aprobăm explicit:
1. Denumire, scop, utilizatori și scenarii de utilizare.
2. Ecrane și comportament UI, inclusiv diferențe mobile/web/desktop.
3. Modele de date, colecții Firestore, proprietar al datelor și ciclul de viață.
4. Roluri și matrice de permisiuni (citire, creare, modificare, ștergere, export).
5. Validări, calcule, reguli financiare și cazuri-limită.
6. Fluxuri complete, aprobări, notificări, jurnalizare și audit.
7. Sincronizare, offline/cache, conflicte, retry și recuperare.
8. Securitate, confidențialitate, retenție, observabilitate.
9. Teste unitare, widget, integrare, emulator, end-to-end și criterii de acceptare.
10. Compatibilitate, migrare, versiune, rollback și condiții de publicare.

Categorii inițiale de inventariat după curățare: autentificare/roluri, membri și echipe, grafic/program, locații și hartă, centralizator, cheltuieli, diurnă/avans, mesagerie și stickere, notificări, documente, profil, setări, feedback, panou administrare, interfață web/desktop, integrare Firebase și diagnosticare. Lista se completează după inventarul real al codului.

## 7. Reguli existente care NU trebuie pierdute

- Avansul la diurnă **poate depăși** suma acumulată; aceasta este o regulă funcțională intenționată.
- Fluxul vechi `perDiems` și `per_diem_settlements_v2` sunt distincte; nu le unificați fără analiză și aprobare.
- Păstrați toate cele 32 de stickere și compatibilitatea platformelor.
- Orice modificare de cod trebuie însoțită de testul potrivit; verificați rezultatul CI pentru commitul final, nu presupuneți că este verde.
- Păstrați nota operațională `ChatGpt` actualizată; acest document este registrul separat de decizii și reguli.
- **Nu implementați încă** sistemul AI/logging/cache ca schimbare funcțională: mai întâi curățarea completă, apoi aprobarea regulilor pe categorii.

## 8. Starea documentului

- **Aprobat ca direcție și ordine de lucru** în conversația din 2026-10-12.
- Detaliile de implementare, schema logurilor, retenția, drepturile exacte, politica offline și tehnologiile finale sunt **de stabilit ulterior împreună**, nu sunt încă specificații finale.
- La fiecare decizie ulterioară: notați data, categoria, regula exactă, justificarea, impactul, testele și aprobarea.


## 9. Evidență aplicare reguli — 2026-10-12

- Lotul `refactor/home-codecs-sync-20261012` continuă exclusiv etapa 1: modularizare HomePage fără schimbare intenționată de comportament. Raport: `AUDIT_MODULARIZARE_2026-10-12.md`; continuitate: `ChatGpt`, secțiunea 100.
- Nicio regulă funcțională nouă nu a fost aprobată sau implementată. Datele Firebase, regulile de securitate și configurația de producție nu sunt modificate; deploy-ul este interzis în această sesiune conform cererii proprietarului.
- Cache-urile fără cititori și parserul repetat sunt candidate de curățare, nu autorizare implicită de schimbare a erorilor, identității încasărilor sau migrare a datelor. Rămâne obligatorie validarea CI pe SHA final înainte de merge și următorul lot.
