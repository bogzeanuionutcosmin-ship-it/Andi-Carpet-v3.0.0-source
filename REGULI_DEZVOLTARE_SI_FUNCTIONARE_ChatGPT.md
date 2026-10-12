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

## 9. Categoria 1 — Conturi și autentificare (decizii aprobate 2026-10-12)

**Stadiu:** reguli aprobate ca principiu, fără implementare sau schimbări de producție.

1. Înregistrare liberă; acces operațional numai după aprobarea contului de administrator.
2. Funcțiile profesionale (șofer, developer etc.) sunt separate de autoritatea administrativă; cumularea funcțiilor nu oferă automat privilegii administrative.
3. **Dezactivare temporară** pentru incidente, suspendare preventivă și blocare rapidă. Blocarea trebuie aplicată și în backend, nu doar în UI; reactivarea se face controlat.
4. Modificările permisiunilor se reflectă prompt în aplicație și sunt verificate pe server la operațiunile protejate; cache-ul local nu conferă drepturi.
5. **Ștergere definitivă** pentru foști angajați și conturi de test, nu dezactivare permanentă ca substitut. Se elimină identitatea din Authentication, profilul și datele asociate nenecesare. Se păstrează doar înregistrările cerute legal sau indispensabile integrității operaționale, cu minimizarea datelor personale, acces și retenție limitate. Nu se șterg automat operațiunile altor persoane ori documentele obligatorii. Înaintea implementării: inventar de dependențe, previzualizarea ștergerii, confirmare explicită, operațiune securizată pe server, protecția ultimului administrator și tratarea eșecurilor parțiale. Conturile de test fără dependențe relevante pot fi eliminate integral.
6. Utilizatorul poate modifica datele proprii de profil permise, dar nu își poate acorda funcții, drepturi sau statut de aprobare.
7. Întreruperea conexiunii nu provoacă inutil delogarea; operațiunile sensibile impun verificarea identității și drepturilor.

**Clarificare:** vechea propunere «dezactivare în loc de ștergere» este înlocuită expres cu «dezactivare temporară pentru incidente + ștergere definitivă la eliminarea unui cont», sub condițiile de mai sus.

**Riscuri de verificat la implementare:** controlul accesului în regulile Firestore și Cloud Functions pentru conturile inactive; revocarea drepturilor fără întârziere periculoasă; migrarea badge_v2 care poate goli functionIds; ștergerea Authentication și Firestore nu este atomică. Nu sunt declarate rezolvate.

**Urmează:** definirea regulilor pentru funcții și permisiuni. Nu se modifică încă aplicația.

## 10. Categoria 2 — Funcții și permisiuni (aprobată 2026-10-12)

**Stadiu:** decizii funcționale aprobate, FĂRĂ implementare. Toate cele 10 puncte au fost confirmate; pentru punctul 10 s-a ales expres **A — audit minimal**.

1. **Mai multe funcții profesionale per membru, fără limită arbitrară a numărului de funcții.** Limita interfeței existente de 1–3 ecusoane pentru o definiție de funcție nu limitează numărul de funcții atribuite unui membru.
2. **Drepturi cumulative:** permisiunile acordate de funcțiile active atribuite aceluiași membru formează o reuniune; o permisiune nu depășește limitele de context, proprietate a datelor și securitate.
3. **Rolul de administrator este distinct** de funcțiile profesionale și de ecusoane. Nu există escaladare la administrator prin simpla atribuire a unei funcții sau a etichetei „Admin”. Modelul actual role/admin versus definiția de funcție admin necesită aliniere cu o singură sursă de autoritate, protejată pe server.
4. **Permisiuni granulare:** vizualizare, creare, editare, ștergere, aprobare, export etc. sunt separate acolo unde operațiunile o cer; editarea nu acordă automat ștergerea.
5. **Permisiuni limitate de context:** date proprii, de echipă, desemnate sau globale conform regulilor fiecărei categorii. Simplul drept de a vizualiza/gestiona o categorie nu oferă acces automat la datele tuturor membrilor/echipelor.
6. **Actualizare promptă și validare pe server:** schimbările apar în timp real unde conexiunea permite, dar operațiunile protejate verifică accesul server-side; cache-ul sau interfața veche nu prelungesc autorizația.
7. **Funcție inactivă = drepturi retrase**, fără ștergerea automată a atribuirii istorice; la reactivare se recalculează drepturile conform configurației curente.
8. **Ștergerea unei funcții analizează dependențele**, arată utilizatorii afectați, actualizează atribuirile și recalculează sigur drepturile; rolul administrativ indispensabil este protejat.
9. **Fără resetări automate ale atribuirilor:** migrarea codului sau a schemei păstrează funcțiile valide și nu golește în masă functionIds. Migrarea existentă badge_v2 este un risc documentat pentru etapa de remediere.
10. **Audit minimal ales explicit:** înregistrăm numai schimbările importante de securitate și acces — creare/modificare/ștergere de funcție, atribuire/retragere de funcție sau drept, schimbări administrative. Identificăm autorul, momentul, ținta și modificarea relevantă; evităm jurnalizarea fiecărui click, duplicatele, informațiile sensibile, creșterea inutilă a Firestore; stabilim o retenție rezonabilă înainte de implementare.

**Clarificări de logică:** drepturile sunt reunite între funcții active, dar sunt filtrate și după domeniul de acces; autoritatea admin trebuie verificată separat de funcțiile profesionale; niciun drept efectiv nu poate fi stabilit doar din interfață. Nu există contradicții nerezolvate între cele 10 principii, dar matricea exactă de permisiuni/aria fiecărei acțiuni va fi aprobată la definirea modulelor respective.

**De verificat înainte de implementare:** sursa canonică a rolului admin; consistența functionIds/effectivePermissions; operațiile administrative care modifică permisiuni; limitele/retenția auditului; migrarea badge_v2, inclusiv protecția împotriva pierderii de atribuiri. Fără modificări de cod, date sau producție din această aprobare.

**Categoria următoare:** Membri și echipe.

## 11. Categoria 3 — Membri și echipe: apartenență și blocare pe grafic (aprobată ca principiu 2026-10-12)

**Decizie finală pentru apartenență, care înlocuiește propunerea intermediară cu mai multe echipe simultane:** fiecare membru poate aparține unei singure echipe operaționale active la un moment dat. Nu există apartenență simultană la două echipe și nu se creează două deconturi active pentru aceeași persoană prin simpla apartenență.

**Blocarea transferului:** cât timp echipa curentă are cel puțin un grafic de lucru neînchis integral, membrul rămâne în acea echipă. „Grafic închis integral” înseamnă că **toate zilele/înregistrările ce alcătuiesc acel grafic sunt închise oficial**; data calendaristică trecută, amânarea, pauza, lipsa activității ori închiderea unei singure zile nu sunt suficiente. Dacă echipa are mai multe grafice încă deschise, blocarea persistă până la închiderea tuturor. Nu se inițiază transferuri automate la expirarea unei date.

**Transfer obișnuit:** când nu mai există grafice deschise în echipa sursă, administratorul poate atribui membrul altei echipe. Aplicația verifică din nou apartenența și starea graficelor pe server chiar înainte de salvare, afișează efectul și cere confirmare. O simplă bifare în interfața altei echipe nu îl scoate automat pe membru din echipa existentă.

**Excepție aprobată:** administratorul poate înlocui anticipat un membru în timpul unui grafic deschis, alegând în mod explicit membrul ieșit și înlocuitorul. Trebuie verificate accesul, apartenența și eventualele grafice deschise ale înlocuitorului, fără mutări implicite sau ocolirea regulii de echipă unică. Înlocuirea se aplică pentru operațiunile viitoare și nu rescrie execuțiile, diurnele, deconturile sau responsabilitățile deja înregistrate.

**Situații-limită stabilite:**
- O echipă fără grafice deschise permite transferul; un membru aprobat poate rămâne temporar fără echipă.
- Inactivarea ori încercarea de ștergere a unei echipe nu trebuie să ocolească blocarea membrilor cu grafice neînchise; se verifică dependențele și se cere soluționare administrativă.
- Redeschiderea unui grafic vechi după transfer **nu mută retroactiv** membrul înapoi și nu îi schimbă istoricul. Se păstrează asocierea istorică a participanților.
- Transferurile și înlocuirile trebuie să fie consistente și autorizate pe server; tranzacții ori mecanisme echivalente împiedică transferul concurent sau pierderea legăturii dintre echipă și utilizator.
- Gestionarul financiar este desemnat explicit, cu cel mult unul principal per echipă; la înlocuirea lui se face predare/clarificare a operațiunilor financiare restante înainte de activarea noului gestionar.
- Mașina aparține temporar echipei, nu membrului; membrii pot avea profesii diferite, iar modificările aprobate trebuie reflectate prompt.
- Echipele de test nu trebuie să perturbe echipele reale și nu pot fi folosite pentru a eluda blocarea transferurilor.

**Constatare tehnică:** implementarea actuală stochează un singur teamId per utilizator (compatibil cu regula), dar editorul echipei elimină automat membri din alte echipe când sunt bifați, fără verificarea blocării graficelor. De asemenea, modelul WorkSchedule păstrează closed la nivel de zi și graphId pentru gruparea zilelor. Acestea necesită schimbări ulterioare și teste de regresie; prezentul document NU modifică aplicația sau datele.

**Detalii tehnice încă de proiectat înainte de implementare:** reprezentarea minimă a componenței istorice în momentul înlocuirii, definirea operațiunii de predare financiară, tranzacționalitatea transferului și comportamentul în situația unei solicitări de ștergere a unui grafic deschis. Nu se aprobă încă o soluție de stocare suplimentară fără analizarea costurilor.

**Stadiu:** decizie de comportament aprobată și documentată; fără implementare, fără modificări Firestore/reguli și fără deploy. Continuăm restul specificației pe categorii separat.

## 12. Categoria 3 — Predarea gestiunii la schimbarea gestionarului (aprobată 2026-10-12)

**Decizie explicită:** proprietarul a aprobat patru reguli de predare și varianta **A — înlocuire imediată prin administrator chiar dacă vechiul gestionar este indisponibil, cu evidențiere separată a banilor nepredați**. Acest paragraf clarifică și înlocuiește formularea din secțiunea 11 care ar fi putut condiționa activarea noului gestionar de predarea financiară completă.

1. **Schimbare autorizată:** numai administratorul autorizat poate executa înlocuirea anticipată a gestionarului în timpul unui grafic deschis. Începând cu momentul confirmat al schimbării, gestionarul anterior nu mai poate distribui sume noi pentru echipa/decontul transferat, iar noul gestionar primește doar drepturile viitoare corespunzătoare. Verificarea se aplică pe server, nu numai în UI.
2. **Istoric nemodificat:** plățile, diurnele, beneficiarii, sumele, confirmările/refuzurile și identitatea distribuitorului inițial rămân nemodificate. Înlocuirea nu este motiv de rescriere a istoricului financiar sau de reemitere a diurnelor.
3. **Predarea banilor este distinctă de schimbarea drepturilor:** se prezintă soldul calculat, se consemnează suma efectiv predată și eventualele diferențe, cu identitatea părților și confirmări când sunt disponibile. Nu se generează venituri, distribuiri, transferuri sau încasări fictive prin schimbarea gestionarului. Avansul la diurnă poate depăși suma acumulată, conform regulii existente.
4. **Diurne neconfirmate și litigii:** beneficiarii pot confirma/refuza în continuare distribuiri inițiate înainte de schimbare, conform fluxului legitim. Responsabilitatea pentru distribuirea inițială rămâne legată de fostul gestionar; administratorul poate soluționa excepții prin procedură auditată, fără să șteargă dovada originală.
5. **Situația de urgență A:** dacă vechiul gestionar lipsește/refuză/nu poate preda banii, administratorul poate schimba **imediat** gestionarul pentru continuitatea operațiunilor. Sumele efectiv nepredate rămân evidențiate distinct ca situație de clarificat, asociate responsabilității istorice, nu sunt trecute automat ca bani primiți de succesor. Noul gestionar poate lucra pe operații viitoare fără a prelua contabil o sumă neconfirmată.
6. **Protecții de implementare:** verificarea appartenenței la echipă și a accesului, prevenirea a doi gestionari principali simultan, protecție contra salvărilor concurente, audit minimal pentru schimbare/predare, tratarea întreruperii conexiunii, evitarea operațiunilor parțiale și a duplicatelor. Datele financiare se atribuie explicit echipei și decontului corect.
7. **Compatibilitate cu modelele actuale:** există gestionari în Team.financialManagerId, TravelSettlement.managerId și TeamFinance.managerId; interfața de decont utilizează prioritatea gestionarului din decont, apoi finanțe, apoi echipă. Înainte de implementare se proiectează clar separarea desemnării pentru echipă și decont, precum și o autoritate efectivă unică pentru fiecare operațiune. Nu modificăm identitățile existente retroactiv și nu duplicăm solduri.

**Fără contradicții restante la nivel de principiu**: blocarea transferului unui membru în graficul deschis are această excepție explicit autorizată de administrator; continuitatea operațiunilor este separată de predarea efectivă a banilor. Schema minimă a înregistrării de predare, metodele de calcul/confirmare și scenariile detaliate de test se stabilesc înainte de implementare, cu economie Firestore.

**Stadiu:** Piatra 3 — Membri și echipe, inclusiv înlocuirea gestionarului — reguli aprobate ca principiu. Nicio modificare de cod, date Firebase, reguli de securitate sau deploy. Următoarea categorie: Grafice și program de lucru.

## 13. Categoria 4 — Grafice și program de lucru, partea 1 (aprobată 2026-10-12)

**Stadiu:** cele zece puncte au fost confirmate DA, inclusiv precizările despre starea graficului, Dashboard și varianta A pentru refuzuri/nerealizări. Reguli aprobate ca **specificație funcțională**, NU implementate. Continuarea Pietrei 4 va defini GPS, intervențiile și automatizările.

1. **Planificare și concurență:** fiecare echipă poate avea mai multe grafice planificate și închise, dar cel mult **un grafic pornit și neînchis** la un moment dat. Regula de start este verificată pe server, inclusiv la două dispozitive simultane. Un grafic pus pe pauză rămâne graficul în desfășurare și nu permite pornirea altuia.
2. **Structură pe zile:** graficul cuprinde zile datate, locații în ordine clară și lucrările planificate (inclusiv fațade). Sunt permise reveniri reale la aceeași locație în zile diferite; se avertizează la duplicate accidentale în aceeași zi.
3. **Creare sigură:** publicarea graficului se face integral ori într-o stare explicit incompletă, inaccesibilă ca grafic valid. Întreruperea internetului/reîncercarea nu creează zile duplicate; se proiectează salvare atomică/idempotentă potrivită limitelor Firestore, fără a inventa confirmarea de server din cache.
4. **START inițial:** cere confirmare și verificarea echipei, punctului real de plecare, destinației finale și datelor necesare traseului. Aceste puncte servesc estimării distanței/consumului, nu sunt locații executate și nu intră în Centralizator. Absența unor date necesare produce explicație și acțiune de remediere, nu trasee GPS inventate.
5. **Starea activă persistă între zile:** după START, graficul rămâne activ pe întreaga durată, inclusiv după terminarea programului zilnic și peste noapte. Nicio pauză automată și niciun nou START zilnic. **Doar administratorul** poate pune graficul pe pauză ori îl poate relua; membrii nu văd butoanele Pauză/Reia și nu pot executa acțiunile direct prin backend. Pauza nu închide graficul, nu pierde progresul și nu eliberează membrii.
6. **Lucrări restante și refuz temporar:** locațiile neîncepute și cele cu status **Refuzată** sunt în continuare lucrări nerezolvate; refuzul reprezintă o încercare nereușită temporară (de ex. acces imposibil din cauza aglomerației), nu încheierea intervenției. Rămân vizibile și reîncercabile în Dashboard-ul zilei, fără să devină automat «Efectuate» ori «Nerealizate». Statusul **Nerealizată** este o decizie finală pentru intervenția din acest grafic, cu explicație obligatorie (de ex. conducerea anulează lucrarea ori curățarea nu mai este necesară după înlocuirea recentă a mochetei). După finalizare sau declarare justificată ca nerealizată, sala nu mai apare printre lucrările restante, dar rămâne în istoricul planificării și în Centralizator.
7. **Amânare, transfer manual și reportare automată:** mutarea intervențiilor neîncepute între zilele aceluiași grafic se realizează din Dashboard sau editorul principal folosind **aceeași logică și validare**, fără cod divergent. Pentru o locație **Refuzată** rămasă nerezolvată, echipa poate reîncerca intervenția în aceeași zi sau o poate reprograma manual; **dacă nu a fost reprogramată manual ori rezolvată până la încheierea programului zilnic**, sistemul o reportează **automat în următoarea zi a aceluiași grafic**. Dacă următoarea zi nu există (inclusiv la ultima zi inițială), creează o zi de continuare în același grafic, fără a considera graficul încheiat. Reportarea este idempotentă și verificată server-side pentru a nu dubla locația/ziua la sincronizări, reconectări sau rulări repetate; nu modifică intervenții în curs, încercări istorice ori reprogramări manuale deja efectuate. Se păstrează data refuzului și motivul încercării anterioare în Centralizator; ziua nouă oferă o nouă ocazie de execuție. Operațiile evită salvările parțiale și scrierile Firestore inutile.
8. **Execuții deja efectuate:** la corectarea asocierii unei locații între zile, execuția rămâne legată de **data/ora reală** înregistrată în Centralizator și de echipa executantă. Nu se modifică retroactiv dovada lucrării, GPS-ul sau confirmările. Dacă o locație planificată pentru mâine este realizată efectiv astăzi, editorul poate actualiza ziua planificată și o poate reflecta în Dashboard fără a fabrica o execuție suplimentară. Se verifică la implementare identificarea fără ambiguitate a intervenției, inclusiv re-vizitele la aceeași locație.
9. **Recalcularea traseului:** optimizarea propune/rearanjează numai locațiile neîncepute și permise; nu modifică lucrări încheiate, în desfășurare ori aflate în așteptarea accesului. Nu inventează coordonate GPS. Păstrează controlul utilizatorului și limitează calculele costisitoare.
10. **STOP = închidere oficială a întregului grafic:** înainte de închidere se verifică toate zilele și toate intervențiile. **Varianta A, clarificată expres:** fiecare intervenție trebuie să aibă rezultatul final **Finalizată** sau **Nerealizată cu explicație obligatorie**; o intervenție încă **Refuzată** este restantă, rămâne reîncercabilă și **blochează închiderea**. O intervenție reprogramată este tot restantă până la soluționarea finală, fără lucrări orfane. Închiderea nu marchează fals locațiile drept efectuate și nu ascunde refuzurile. Graficul devine închis/inactiv operațional **numai după confirmarea oficială a închiderii complete**, nu prin expirarea zilei sau a datei inițiale; închiderea trebuie să fie coerentă pentru toate zilele (WorkSchedule.closed există în prezent per zi).
11. **Excepții administrative:** administratorul poate corecta/redeschide o situație justificată cu audit minimal, fără rescrierea istoricului real al execuțiilor, diurnelor, deconturilor, gestionarilor sau apartenenței anterioare. Redeschiderea unui grafic istoric nu mută automat membri între echipe; pentru operațiunile viitoare se verifică incompatibilitățile cu graficele active.
12. **Dashboard și editor:** zilele curente sunt prezentate într-un **chenar verde**, ziua următoare într-un **chenar galben cu clepsidră „În așteptare”**. În editor, zilele finalizate au **bifă verde**, cele viitoare/nefinalizate **clepsidră galbenă**; dacă ziua are refuzuri/nerealizări, acestea își păstrează explicit indicatorii distinctivi (nu apar înșelător ca lucrări efectuate). Membrii autorizați pot muta rapid o locație de azi pe mâine sau aduce una planificată mâine pe azi, direct din Dashboard; toate comenzile folosesc aceeași validare și aceleași drepturi ca editorul principal. „Zi finalizată” este diferită de „grafic închis”: afișarea bifelor nu închide implicit întregul grafic.

**Clarificare obligatorie a rezultatului unei locații — aprobată explicit după partea 1:**
- **Refuzată (provizoriu):** accesul a fost refuzat temporar (de exemplu, locația este aglomerată). Se consemnează motivul real, fără a considera lucrarea terminată; utilizatorii autorizați pot reveni și reîncerca de mai multe ori. Rămâne în Dashboard ca restantă în ziua curentă și nu primește bifă verde de finalizare.
- **La sfârșitul programului zilnic:** dacă refuzul este încă nerezolvat și nimeni nu a făcut o reprogramare manuală, intervenția trece automat în următoarea zi a **aceluiași grafic**. Nu se declanșează la fiecare deschidere a aplicației și nu se repetă. Se folosește limita oficială a zilei operaționale, nu ora neverificată a dispozitivului; la lipsa internetului se reconciliază sigur după reconectare, fără duplicate. Dacă ziua următoare conține deja aceeași intervenție, se evită dublura; la ultima zi se poate crea o zi de continuare a graficului, fără închiderea sa. Pentru graficul suspendat de administrator se va clarifica comportamentul automatizării înainte de implementare.
- **Nerealizată (final pentru grafic):** dacă intervenția nu mai este necesară sau conducerea a decis să nu o execute în acest grafic, se înregistrează explicația obligatorie și persoana care a declarat-o conform drepturilor. Nu mai apare ca lucrare restantă în lista zilei, dar nu este ștearsă din istoric și nu devine «Efectuată».
- **Finalizată:** se scoate din lista de lucrări rămase, cu data, ora și execuția reală intacte. Refuzurile anterioare ori reprogramările nu rescriu această evidență.
- **Centralizator și PDF:** atât rezultatul final **Nerealizată** cât și explicația lui trebuie să fie vizibile explicit în Centralizator și în PDF-ul exportat; se păstrează refuzurile și încercările relevante pentru trasabilitate. PDF-ul nu va afișa în mod înșelător doar data fără status ori motiv.
- **Cost și consistență:** identificarea intervenției evită confuzia între vizite repetate la aceeași locație; reportarea automată și păstrarea istoricului folosesc operații idempotente, cu protecție contra concurenței și fără scrieri la fiecare refresh. Schema exactă este de proiectat înainte de implementare.

**Regresii existente, de remediat ulterior:** ProgramPage exclude acum Refuzată din lista de lucrări rămase; Dashboard exclude Refuzată din estimări și din butonul obișnuit de intrare în sală; transferul în ziua următoare este manual și nu include refuzurile. Exportul PDF al Centralizatorului nu afișează explicit statusul și explicația pentru Nerealizată în rândul evenimentului. Aceste constatări NU reprezintă funcționalități deja corectate.

**Coerență cu Piatra 3:** închiderea oficială a tuturor zilelor este condiția transferului obișnuit de membri. Pauza, sfârșitul zilei și amânarea nu deblochează transferurile. Excepția de înlocuire explicită autorizată de administrator rămâne valabilă. **Chestiune încă de clarificat în Piatra 3:** regula aprobată „orice grafic neînchis blochează transferul” se aplică textual și graficelor viitoare neîncepute; poate bloca mult timp membrii dacă sunt planificate grafice peste săptămâni. Nu schimbăm această regulă fără confirmare expresă.

**Riscuri actuale de remediat ulterior:** codul din ProgramPage expune Pauză/Reia pe baza permisiunii comune de editare, în loc de admin exclusiv; operațiile START/STOP și creare/mutare a zilelor efectuează scrieri succesive care pot rămâne parțiale la eroare; Dashboard are unele operații independente de cele din editorul principal; starea closed există pe fiecare WorkSchedule/zi; reconcilierea intervenției după dată folosește în unele locuri echipă+locație+dată și trebuie verificată pentru vizite repetate. Acestea sunt constatări, nu declarații de remediere.

**Fără intervenții tehnice:** nu se modifică cod, date Firestore, reguli de securitate, configurație de producție, versiune sau deploy. Urmează aprobarea Pietrei 4 partea 2 (GPS, deplasări, intervenții și automatizări) și clarificarea explicită a blocării de către grafice viitoare.

## 14. Categoria 4 / Decont — sincronizarea graficului, diurnelor și ruta la START (confirmare 2026-10-12)

**Stadiu:** cerințe de comportament confirmate și deficiențe constatate în cod. NU sunt implementate. Regula exactă a celulelor calendarului de diurne (verde/roșu și stările intermediare) este direcție UI solicitată, cu nuanțele de mai jos de validat înainte de implementare.

### Convenția zilei și calculul diurnei — confirmate explicit

1. **Data operațională este data încheierii turei:** tura de luni 23:30 până marți 09:30 se înregistrează ca **Ziua 1 = marți**, atât în grafic, cât și în decont. Intervalul 23:30–00:00 face parte din programul operațional (pregătire/cafea), iar începutul fizic obișnuit al lucrărilor este la 00:00. Ora START administrativ al graficului (de exemplu, luni la 10:00) este distinctă de începutul turei și de ora reală a unei intervenții. Nu se acordă diurnă doar pentru apăsarea START.
2. **Scadența zilei:** la **09:31**, după încheierea ferestrei operaționale 23:30–09:30, devine cuvenită diurna fiecărui membru eligibil pentru acea zi operațională. Exemplu aprobat: echipă cu doi membri eligibili și tarif de 50 lei/zi => 50 lei cuveniți fiecăruia, 100 lei total pentru prima zi; nu se declară automat și că suma a fost distribuită sau primită. Cele 30 de minute de pregătire înainte de 00:00 nu generează o zi de diurnă separată.
3. **Grafic ↔ decont:** fiecare decont/deplasare operațională trebuie legată explicit, fără ambiguitate, de graficul corespunzător (echipă + graphId). Copiază/sincronizează **data începutului, data finală și numărul real al zilelor din grafic**, cu aceeași convenție a zilei operaționale; nu se introduce independent un număr contradictoriu de zile. O zi suplimentară introdusă prin prelungirea unui grafic (inclusiv pentru o locație refuzată) actualizează perioada și numărul de zile din decont; drepturile de diurnă sunt calculate o singură dată pentru zilele eligibile, nu dublate prin mutări/reconectări. Este necesară explicitarea drepturilor la zilele adăugate și schimbărilor de membri înainte de implementare, fără rescriere retroactivă.
4. **Banii cuveniți ≠ bani distribuiți ≠ bani confirmați:** totalurile cuvenite se acumulează pe membru/zi și sunt independente de sumele efectiv predate. O distribuire necesită tranzacție distinctă, iar primirea poate fi confirmată/refuzată de beneficiar. Avansurile (inclusiv peste diurna acumulată) rămân permise și vizibile distinct; nu sunt contabilizate automat drept alte zile achitate. Evitarea duplicatelor este obligatorie (cheie stabilă grafic/decont + zi operațională + membru, politici pentru transferuri), cu sume în bani întregi și verificare server-side.

### Program operațional vs. execuție fizică — clarificare expresă a proprietarului (2026-10-12)

- **23:30 = intrarea echipei în programul de lucru** al turei de noapte. Între **23:30 și 00:00** sunt, în mod obișnuit, **30 de minute de pregătire/cafea**. În acest interval Dashboard trebuie să afișeze **«În program»**, chiar dacă nicio locație nu a fost încă începută și nu există o execuție fizică activă. Nu se afișează «Liber»/«În afara programului» doar pentru că încă nu este ora 00:00. Starea operațională a echipei trebuie distinsă de starea unei locații.
- **00:00 = ora obișnuită de început al intervențiilor fizice**, NU este o limită tehnică de acces și NU blochează butonul «START locație». Dacă activitatea o cere și membrul are drepturile necesare, **poate începe o locație la 23:30 sau chiar înainte de 23:30**. Sistemul salvează **ora reală** și nu o mută artificial la 00:00 sau 23:30; nu refuză execuția numai pentru că are loc în afara intervalului standard.
- **Atribuirea la ziua graficului:** o locație începută înainte de 23:30 pentru tura de noapte ce urmează trebuie să poată fi atribuită **zilei operaționale corecte** (de exemplu, luni 23:15 pentru tura de luni noaptea → marți dimineața, dacă intervenția a fost inițiată explicit pentru acea tură), păstrând separat data/ora calendaristică efectivă în Centralizator și PDF. Nu se deduce automat ziua operațională numai din ceasul dispozitivului la intervențiile începute înainte de fereastra standard: se verifică asocierea cu graficul/ziua selectată. Trebuie prevenite execuțiile atribuite altui grafic și dublarea diurnei.
- **La 09:30** se termină fereastra operațională obișnuită a turei; asta **nu închide graficul complet** și nu șterge automat o intervenție în curs. **La 09:31** se calculează dreptul pentru ziua operațională tocmai încheiată, conform regulilor de eligibilitate și fără a trata cafeaua ca o a doua zi de diurnă.
- **Nu se confundă cele trei evenimente:** START-ul inițial al graficului, intrarea echipei «În program» la 23:30 și START-ul efectiv al unei locații. Au scopuri și momente diferite; Dashboard trebuie să reflecte corect fiecare.

### Pornirea graficului și suma la plecare — confirmate ca direcție

5. După START grafic, gestionarului desemnat îi apare **un indicator discret, neintruziv** pentru completarea sumei **primite la plecare** în decontul legat de acel grafic. Semnalul nu blochează pornirea/execuția; nu se înscrie nicio încasare fictivă. Gestionarul completează suma, metoda, sursa și data; indicatorul încetează după înregistrarea validă ori tratează explicit cazul «nu am primit încă». Drepturile financiare se verifică și pe server.
6. START stabilește plecarea și destinația, calculează estimări distinct etichetate de **distanță (rutieră dacă serviciul răspunde; altfel aproximație precizată), consum combustibil și cost**, în funcție de mașina și datele disponibile, apoi prezintă pe hartă traseul planificat. Culorile solicitate anterior se păstrează: **verde** segmentele deja parcurse, **galben** segmentul către următoarea destinație, **mov** traseul viitor rămas, **verde** returul după începerea/parcurgerea lui. Nu se afișează linia dreaptă drept rută reală și nu se inventează geometrie, GPS ori date despre parcurgere. Un traseu poate necesita actualizarea progresului pe măsură ce echipa lucrează.

### Calendarul diurnelor în Decont — solicitare nouă, de rafinat

7. În decont, gestionarul și membrul, conform drepturilor, trebuie să poată vedea **pe fiecare zi operațională până în prezent**: câte zile sunt cuvenite, câte sunt acoperite de plăți confirmate, sume restante, avans și plăți în așteptarea confirmării. Utilizatorul a cerut o vizualizare simplă **verde/roșu**, per membru și zi, astfel încât gestionarul să știe imediat dacă mai are de distribuit bani. Recomandarea de proiectare (încă de confirmat la detalii UI): verde = diurnă acoperită prin plată confirmată; roșu = sumă cuvenită restantă; galben = distribuire trimisă dar neconfirmată / diferență în verificare; neutru = zi viitoare, încă necuvenită. Pentru plată parțială ori avans, se afișează și cifrele, fără a atribui înșelător o singură culoare ca dovadă de achitare. Un contabilizator agregat («cuvenit», «confirmat», «în așteptare», «restant», «avans») completează calendarul, fără duplicate Firestore la fiecare refresh.

### Deficiențe existente, confirmate prin citirea surselor

- În **lib/expenses/expense_page.dart**, `_createSettlement` creează manual deplasarea, cu început liber ales și final opțional; **TravelSettlement** nu are graphId și nu copiază automat perioada / numărul de zile al graficului.
- `_money(true)` introduce manual «Primit la plecare»; **START** în ProgramPage și Dashboard nu emite momentan semnalul discret către gestionar.
- `_distribute` creează plata manuală cu suma implicită `perDiemRate`; tariful `AppSettings.defaultPerDiem` este 50 lei, dar **nu există în fluxul operațional verificat** generarea zilnică automată a drepturilor la 09:31 pentru toți membrii. Ledgerul separat conține conceptul de `entitlement`, dar simpla sa existență nu îl conectează la ziua graficului. Firebase Functions are scheduler pentru SMS-uri, nu un calcul zilnic de drepturi identificat.
- `lib/utils/operational_dates.dart` atribuie intervalul 23:30–09:30 datei de final, dar pentru un grafic nou creat la 10:00 logica inițială `operationalWorkDate(DateTime.now())` indică **ziua curentă**, nu automat următoarea tură care începe la 23:30; trebuie validată alegerea primei zile pentru a evita un decalaj calendaristic. **Risc suplimentar:** intrarea efectivă într-o locație *înainte* de 23:30, dacă aparține intenționat turei următoare, poate fi atribuită automat zilei greșite; este necesară asocierea explicită cu ziua/graficul corect, fără modificarea timestampului real.
- ProgramPage poate calcula distanța/consumul/costul și rutarea rutieră (cu fallback explicit), dar în MapPage traseul rutier este desenat în prezent în **portocaliu**, nu segmentat consecvent pe verde/galben/mov în funcție de progres. În Dashboard, butonul STOP poate seta `started=false` pentru o singură zi, în dezacord cu regula deja aprobată că graficul rămâne activ până la închiderea oficială completă.
- Diurnele trebuie să rămână reconciliabile cu istoricul, inclusiv avansurile, refuzurile și confirmările existente; fără migrări destructive sau suprascriere de date.

**Teste obligatorii pentru implementarea viitoare:** ture peste miezul nopții și fusul orar România; Dashboard «În program» de la 23:30; interval 23:30–00:00 de pregătire fără START forțat de locație; început fizic obișnuit 00:00; pornirea reală a unei locații la 23:30 ori chiar mai devreme (permisă, timestamp real păstrat, zi operațională corect asociată); START grafic administrativ la 10:00 pentru tura de seară; exact o acumulare la 09:31; utilizatori multipli, grafice prelungite, membri înlocuiți la mijlocul graficului, avans, plată parțială/neconfirmată, offline/retry și concurență, notificare discretă numai pentru gestionar, calcul rutier/fallback, culori și progres pe hartă. Stabilirea politicii de plată a turelor neexecutate și a zilelor de prelungire necesită aprobare contextuală, nu presupuneri ascunse.

**Fără implementare:** nicio modificare de cod, date Firestore, reguli de securitate, producție sau deploy. Aceste cerințe sunt pentru lotul funcțional ulterior modularizării.
