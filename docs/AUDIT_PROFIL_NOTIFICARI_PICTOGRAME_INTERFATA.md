# AndiCarpet — Audit de proiectare: profil, notificări, pictograme și interfață

**Data analizei:** 2026-10-13. **Statut:** analiză read-only a sursei GitHub și recuperare cerințe istorice; **NU** implementare, NU test de funcționare reală, NU deploy. Categoriile 2 (interfața finală a profilului) și 3 (evidența istorică a echipelor) se **decid împreună cu proprietarul**; categoriile 1, 4 și 5 sunt **delegate explicit asistentului spre alegerea logicii după audit atent**; categoria 6 (implementare, teste finale) rămâne **la sfârșit**.

## 1. Mandatul actual al proprietarului și ordinea corectă

Mesajul proprietarului, în esență:
- **1.** Informațiile operaționale indispensabile când datele sunt ascunse în profil: decizia tehnică logică este delegată asistentului.
- **2.** Structura/aspectul final al profilului: se decide **împreună**.
- **3.** Evidența istorică a echipelor: se decide **împreună** (fără schema de producție unilateral).
- **4.** Excepțiile randamentului: asistentul decide după analiza atentă a fiecărei ipoteze.
- **5.** Securitatea și sincronizarea: asistentul proiectează conform practicilor normale; **nu este acord pentru modificări live**.
- **6.** Testele/implementarea **la final**. **ÎNAINTE** de această etapă trebuie investigat sistemul actual de notificări (proprietarul raportează probleme), pictogramele lipsă și trebuie recuperate și reconfirmate împreună cerințele de interfață.

**Etapele proiectului stabilite anterior au prioritate:** curățare/refactorizare completă cu CI → reguli aprobate pe categorii → prima implementare nouă Diagnostics & Self-Healing → alte funcții, apoi testare și lansare controlată. Prezentul audit nu schimbă această ordine și nu autorizează vreun deploy sau editare Firebase.

## 2. Decizie delegată 1 — separarea confidențialității PROFILULUI de informațiile necesare activității

**RECOMANDARE TEHNICĂ ADOPTATĂ CA REGULĂ DE PROIECTARE ÎN LIMITELE DELEGĂRII:**

1. Preferința ochi deschis/închis din «Editare profil» controlează **afișarea în profilurile vizitate de colegi** și în copii/preview-uri ale profilului. NU anulează automat evidențele operaționale, drepturile de lucru sau jurnalul de audit.
2. În **echipe, grafice, repartizări, operații de START/STOP și chat**, persoanele care trebuie legitim să colaboreze pot vedea **minimul de identitate necesar** (numele de lucru/pseudonim neechivoc și funcția/rolul când influențează atribuțiile), chiar dacă titularul a ascuns câmpurile *din profil*. În operații protejate se folosesc ID-uri stabile pe server, nu doar text sau poză. **Nu** extindem această excepție asupra tuturor membrilor/colecțiilor din aplicație; minimizarea și autorizarea se verifică per ecran și per scop. Identificarea în rapoarte istorice și audit trebuie să rămână corectă.
3. **Fotografia personală nu este indispensabilă** pentru execuție; dacă este ascunsă în profil, în contexte sociale/neesențiale ale colegilor se poate folosi avatar generic, fără afectarea contului. Un identificator operațional neechivoc rămâne în grafice și mesagerie. Nu inventăm obligativitatea afișării fotografiei tuturor.
4. **Telefonul/emailul ascunse din profil** sunt OMITSE din proiecția de profil accesibilă colegilor, dar pot fi accesibile administratorului autorizat și, numai când este justificat și permis, prin fluxuri operaționale strict distincte de comunicare/SMS; acele fluxuri se auditează separat. Ascunderea socială nu șterge contactele, nu modifică autentificarea și nu împiedică alertarea prin token push.
5. **Diurnele sunt strict private în profil**: beneficiar + admin, fără comutator de publicare, fără sume transmise în directoarele colegilor. Drepturile gestionarului pentru distribuire/confirmare în modulul financiar nu sunt modificate tacit.
6. O informație istorică prezentă într-un document operațional deja autorizat (grafic vechi, mesaj trimis, audit) **nu dispare retroactiv** atunci când titularul își închide ochiul în profil. Interfața trebuie să explice clar scopul controlului: «Ascuns din profil pentru colegi», nu promisiunea imposibilă «nimeni nu îmi va vedea identitatea nicăieri».
7. Dacă utilizatorul ascunde un card de randament în propriul profil, un alt participant poate afișa aceeași statistică în **propriul** profil conform alegerii deja aprobate «Fiecare controlează exclusiv». Ascunderea nu schimbă numărul sau calculul.

**Excepțiile de acces se validează prin matrice [rol × scop × resursă × operație], nu printr-un singur flag global**, cu test de acces pentru fiecare sursă citibilă clientului, nu doar pentru widget.

## 3. Decizie delegată 4 — situații-limită randament și suprafață: comportament conservator, verificabil

1. **M² cunoscuți și participanți verificați:** pentru o intervenție unică de mochetă efectiv Finalizată cu doi participanți, suprafața de mochetă **S** se atribuie **integral fiecăruia**, **S** perechii și **o singură dată S** companiei. NU se împarte după cine face mocheta/fațada sau după timp. O sală curățată efectiv în două vizite reale distincte contribuie de două ori la volumul prestat, nu la suprafața fizică unică a portofoliului.
2. **Suprafață lipsă/eronată, istoric fără snapshot:** nu folosim 0 ca substitut pentru necunoscut, nu atribuim `Location.surfaceM2` actual trecutului. Arătăm subtotal documentat + «total incomplet» și numărul de intervenții afectate. Nu blocăm istoricul de facturare sau evidența că lucrările au fost executate.
3. **Membri înlocuiți / pereche reformată:** se folosește componența reală verificabilă **la intervenție**, nu membrii echipei actuale. Păstrăm totalul General și m² când aceiași doi membri redevin parteneri, indiferent de `teamId` sau perioadele petrecute cu alții. Înlocuirea între START/STOP se marchează pentru reconciliere, fără atribuire retroactivă inventată; mecanismul precis de dovadă și schema se **decid împreună** la punctul 3.
4. **Timp invalid:** START lipsă, STOP lipsă, STOP înainte de START, durată zero/negativă, retry duplicat, așteptare înainte de START, refuz/nerealizare sau cronologie nevalidată — NU generează o pereche nouă `T_ref/T_real` de randament. Datele fizic reale/serviciile pot rămâne evidențiate separat.
5. **Intervenții mixte simultane:** fațadă și mochetă efectuate în paralel de cei doi membri => reper de timp al **întregii intervenții mixte**, calculat doar din alte vizite mixte comparabile credibile; **nu adunăm** durate, nu individualizăm minute, nu adunăm m² fațadă cu m² mochetă. Fațada revenită ulterior nu rescrie timpul mochetei sau vechiul scor. Datele `facadeDone` vechi nu dovedesc singure simultaneitatea.
6. **Randament fără etalon:** perechea `T_ref/T_real` se exclude din **ambele totaluri** când reperul valid lipsește, nu se atribuie 0% sau 100% fictiv. Rămân cele **două procente per componență**: «Luna în curs» și «General», maximum 100%; `MIN(100%,100 × ΣT_ref_eligibil / ΣT_real_același_set)`, fără medie a procentelor de locație. «Fără lucrări luna aceasta» când nu există execuții, «Date insuficiente» când există dar reperul e nesigur.
7. **Reamenajări:** configurațiile de suprafață/format cu dată efectivă diferită nu sunt automat comparabile, chiar dacă au același nume și aproximativ aceiași m². Corecțiile de m² efectuate ulterior necesită dovadă și audit, nu rescriere tacită a intervențiilor vechi. Fără folosirea datelor din viitor pentru a prezice trecutul.
8. **Anomalii:** limitări pentru outlieri, trafic de evenimente, ceasuri greșite/dispozitive offline, duplicate și model insuficient calibrat; nu facem penalizări personale sau decizii salariale automate.

## 4. Decizie delegată 5 — arhitectură securizată, în sincron cu drepturile existente

1. `users/{uid}` rămâne privat titularului/adminului autorizat; `memberDirectory` este o **proiecție minimizată și filtrată backend**, nu o copie integrală a profilului privat. Ochi închis => valoarea lipsește din resursa accesibilă colegului; nu e suficient «visible:false» în JSON sau ascunderea widgetului. Identificatori stabili de câmp și preferințe per titular, câmpuri operaționale separate de prezentarea socială.
2. Calculul m²/randament folosește evidența autentică a intervențiilor, cu agregare **read-only și autorizată**, fără a deschide tuturor membrilor colecția completă de execuții și fără contori m² editabili de membru. Fiecare document/actualizare se autorizează server-side, cu audit și compatibilitate legacy.
3. Revalidare la operații protejate (editare echipă, transfer, atribuții, diurnă, STOP, finanțe). Comutatorul de profil nu acordă acces la datele interne și nu îi permite titularului modificarea propriului scor.
4. **Offline, cache și sincronizare:** nu promitem anularea instantanee a informației deja descărcate pe dispozitivele altora; actualizarea serverului, invalidarea afișărilor în aplicație, sincronizarea când revine online și politica de cache/retenție trebuie proiectate și testate. Nu ștergem operațiile utilizatorului nesincronizate.
5. **Minimizați notificările push sensibile:** pentru telefon blocat utilizați text neutru unde sunt diurne, contacte, sume sau conversații private, fără date inutile care ajung pe ecranul de blocare. Conținutul detaliat se vede după autentificare în aplicație. Alerta de la administrator trebuie autenticată de server, nu identificată doar după textul titlului.
6. **Tokenurile push sunt legate de sesiune/utilizator și dispozitiv**: pe schimbarea rapidă a contului și pe logout, vechiul cont nu trebuie să rămână abonat în mod activ la tokenul aceluiași dispozitiv, iar schimbarea proprietarului tokenului se sincronizează/reconciliază sigur. Controlați tokenuri vechi, expirate și duplicate. Verificați roluri și accesul la `users/{uid}/pushTokens`.
7. O modificare a regulilor Firestore, Cloud Functions ori datelor live **NU** este autorizată prin delegarea deciziilor tehnice; necesită ramură/PR, teste de emulator/staging și aprobare explicită înainte de deploy.

## 5. Recuperarea interfeței stabilite anterior: cerințe GĂSITE, NU pierdute

**Sursă:** `ChatGpt` secțiunea 6, intrările «Navigație / UI», «Hartă / rute» și «Comunicare / notificări».

**Cerințe istorice ale proprietarului ce trebuie păstrate:**
- **WEB:** bară de **categorii glisantă din DREAPTA**, deschisă prin buton dedicat; gestul de tragere și accesul cu mouse/tastatură trebuie validate.
- **ANDROID:** taburile de jos au fost cerute **pe DOUĂ rânduri** (sau să se reconfirme împreună echivalentul accesibil înaintea unui redesign; NU considerați rândul unic actual drept aprobarea unei schimbări).
- **Mesagerie:** panou **glisant din dreapta**, **popup** și buton **X** de închidere; chat privat/de grup, stickere ca imagini și mesaje necitite clar semnalizate.
- **Antet:** «sus doar poză profil + nume» ca direcție istorică solicitată; nu presupunem că antetul aglomerat actual respectă acel design.
- **Temă VERDE**, navigare lizibilă, icon nou pentru Setări, redesign profil cu ochi vizibilitate confirmat ulterior, pictograme sociale corecte.
- **Hărți:** butoane mari cu DOAR pictograme Google Maps/Waze, rute pe drum, culori de progres (verde parcurs, galben următorul oraș, mov rest, verde retur).
- **Notificări:** buton explicit **«Marchează ca citit»** și indicator/icon contextual când există notificări, diagnostic push, sincronizare corectă.

**Audit de cod (nu de deploy):** `lib/home/home_page.dart` la final are `endDrawer: kIsWeb ? Drawer(... 'Categorii'...)` și `openEndDrawer()`, deci **bara dreaptă pentru web EXISTĂ ÎN SURSA ACTUALĂ**, nu e probat că e în buildul public. Pe Android apare un singur `NavigationBar` cu toate destinațiile pe un rând, NU două rânduri. `_openGroupChat` și `_openChatFromAlert` folosesc `Navigator.push` către pagini, NU panoul glisant cu X cerut. Antetul actual include logo, «Despre», notificări, profil, buton meniu și acces membri/chat, NU simplu «foto + nume». `web/manifest.json` are `theme_color:#B97A2B` (maro) și `background_color:#FFF8EC`, în contradicție cu direcția de temă verde; modificarea culorii manifestului trebuie făcută coordonat după verificarea cerinței și a efectului pe PWA. `lib/profile/profile_page.dart` încă nu are ochii confirmați: sunt proiectare viitoare.

**ATENȚIE:** nu se decide unilateral layoutul final al punctului 2; proprietarul vrea să îl stabilească ÎMPREUNĂ. Proiectați opțiuni/exemple și verificați pe mobil/web, păstrând intențiile vechi. Compararea SHA-ului buildului **publicat** cu codul sursă necesită acces la workflow/loguri de deploy și/sau test vizual; existența în fișierul Dart nu este acceptarea UI final.

## 6. Audit preliminar notificări: constatări vs riscuri (PRIORITARE)

| Prioritate | Dovezi concrete în sursă | Interpretare și verificare necesară |
| --- | --- | --- |
| **P0 securitate, RISC** | `HomePage._savePushToken` scrie în `users/{uid}/pushTokens`; `SettingsPage._switchQuickAccount` schimbă direct contul, iar logout-ul este simplu `FirebaseAuth.instance.signOut()`; `functions/index.js::sendToUser` livrează tuturor tokenurilor stocate, fără verificare `active`/deconectare. | **Posibilă scurgere de push-uri către un dispozitiv care a schimbat contul**, mai ales telefon comun. Nu este probată în producție. Stabiliți revocarea/mutarea atomică a tokenului pe schimbare cont/logout, deduplicare, verificare în test cu 2 conturi reale/de test. |
| **P0/P1 securitate, RISC** | `functions/index.js::notificationCategory` interpretează titluri «sistem» ori conținând «admin» drept obligatorii; `firestore.rules::match /notifications` permite creare unor membri activi pentru alți membri prin `canNotifyUser`. | **O notificare creată de un membru poate părea provenită de la Admin** și poate ocoli preferințele numai pe baza unui titlu textual. Verificați regulile reale de creare, evitați categorizarea privilegiată prin text, folosiți autor verificat/categorie validată pe server și limite de volum. |
| **P1 comportament, CONSTATAT ÎN COD** | `HomePage.notifyUser` face `if (!settings.pushNotifications) return;` înainte de a crea `notifications` în Firestore. | Dezactivarea push poate **opri și înregistrarea notificării interne/istoricului**, dacă acel flux utilizează metoda; decuplați crearea evenimentului în aplicație de canalul push, potrivit tipului evenimentului și permisiunilor, fără notificări duplicat. |
| **P1 UX, CONSTATAT ÎN COD** | `_openNotificationsSheet` marchează citit **prin tap pe rând**; `SettingsPage` face la fel; nu există butonul explicit cerut «Marchează ca citit». | Introduceți control explicit per notificare și/sau «Marchează toate ca citite», cu comportament clar. La erori, nu afirmați că a fost citită. |
| **P1 UX, CONSTATAT ÎN COD** | Sheetul construiește lista `mine` înainte de `showModalBottomSheet` și nu are `StatefulBuilder`; callbackul setează `n.read=true` înainte de `await set(...)` fără tratament de eroare. | **Risc de vizualizare neactualizată** în sheet și stare optimistă rămasă incorectă la eșec Firestore; folosiți model reactiv și rollback/mesaj de eroare, fără a afecta alte notificări. |
| **P1 UX, CONSTATAT ÎN COD** | La prima `notifications.snapshots()` din sesiune, `_notificationsPrimed=false`, `ownUnread` sunt prezentate popup indiferent de vârsta documentului. | **Alertele vechi necitite pot reapărea la fiecare pornire**, inclusiv dacă au fost văzute anterior; diferențiați «eveniment primit acum» de «restanțe necitite» și folosiți sumar discret/popup numai pentru evenimente noi. |
| **P1 corectitudine** | `functions/index.js::notificationCategory` și `HomePage._notificationCategory` clasifică notificarea din fragmente de text, nu din categorie tipizată/semnată. | Coliziuni «locație/grafic/learning/decont», diferențe de clasificare/diacritice și ocolirea filtrelor sunt posibile. Introduceți **tip/categorie stabilă** autorizată, păstrând fallback pentru documente vechi. |
| **P2 deschidere destinație** | `_initPushNotifications` navighează din `onMessageOpenedApp/getInitialMessage` **numai pentru `type='chat'`**. `pushSystemNotification` trimite `type='notification'`. | Tap pe o notificare de sistem poate deschide aplicația fără a deschide mesajul/detaliile relevante. Adăugați rutare sigură cu verificare de acces/deep link; testați foreground/background/terminated. |
| **P2 Web/PWA** | `web/firebase-messaging-sw.js` există, la fel `web/icons/Icon-192.png`; `_initPushNotifications` necesită VAPID compilat; există `PushDiagnosticsPage`. | Sunt fișiere/fluxuri în sursă, dar NU a fost verificată cheia VAPID efectivă a buildului publicat, permisiunea în browser, service worker activ, livrarea FCM ori notificările iPhone PWA. Testare pe dispozitive reale și buildul efectiv. |
| **P2 indicator** | `HomePage` afișează `Badge` doar când `myUnreadNotifications>0`, dar **iconul de notificări** este în antet tot timpul. | Cerința veche «indicator/icon numai când există notificări» trebuie aplicată coerent: când e zero, semnalul de alertă să nu pară activ; istoricul rămâne accesibil din Setări. Aspectul exact se reconfirmă împreună la interfață. |

**Sunt concluzii de audit static, nu un diagnostic final al problemelor observate în producție.** Proprietarul trebuie să poată explica ce notificări lipsesc/reapar/se dublează; nu inventăm simptome specifice unui cont.

## 7. Audit pictograme și resurse statice

- `lib/ui/icon_badge_catalog.dart` mapează pictograme către asseturi `assets/ui/` și `assets/badges/`; `pubspec.yaml` declară aceste directoare ca assets. Au fost **verificate în GitHub** existența a cel puțin **27** fișiere de navigare/categorii/badge/web, inclusiv `tab_dashboard.png`, `tab_grafic.png`, `tab_harta.png`, `tab_centralizator.png`, `tab_decont.png`, `tab_documente.png`, `chat_live.png`, `teams.png`, `members.png`, `security.png`, cele 4 categorii, toate cele 10 badge-uri și cele 4 iconuri principale de PWA (unele verificate în grupuri diferite).
- Această verificare demonstrează **existența fișierelor la căile din sursă**, NU randarea lor, dimensiunea/contrastul în UI, încărcarea în APK/web publicat, concordanța numelui funcției cu iconul, cache PWA, badge-urile opționale ori toate posibilele resurse folosite în aplicație.
- **Lipsa raportată de pictograme NU poate fi considerată remediată.** Verificați pe Android și web pentru fiecare secțiune, în stare normală/selectată, cu accent pe meniul din dreapta, funcții, profil, categorii și hărți. Pentru icon lipsă ori corupt, fallback cu semnificație corectă; NU eliminați imaginile doar pentru că un test static trece.
- **Logo-urile sociale din profil încă nu sunt implementate** în `ProfilePage`/`MemberProfilePage` (acolo există `Icons.link` generic), deși sunt aprobate pentru implementarea viitoare; fallback necunoscut = glob/link extern neutru, niciodată logo Google doar prin necunoașterea site-ului.
- Testați resurse de `pubspec.yaml` atât în Flutter web/release cât și în Android/APK, plus `web/manifest.json`/PWA și culorile față de tema verde.

## 8. Pașii în ordinea delegată de proprietar

1. **Acum, documentare/audit:** reguli tehnice delegate 1,4,5 conform secțiunilor 2–4; se clarifică prin teste și dovezi simptomele notificărilor și icoanelor, se verifică SHA-ul publicat pentru UI. Nu se atinge Firebase live.
2. **ÎMPREUNĂ cu proprietarul:** punctul 2 — aspectul final al profilului și interfeței, comparând cerințele vechi; punctul 3 — contractul istoric al echipelor, comportamentul la schimbări și migrarea legacy. Nu impunem unilateral layout sau schemă de date.
3. **Înainte de implementare:** matrice de drepturi, date minimale, fluxuri de sincronizare, lista de riscuri și criterii de acceptare inclusiv notificări/icoane; staging separat, teste de permisiuni.
4. **La sfârșit:** modificări controlate în PR, CI/teste Flutter/Functions/Rules/web/Android, validare în browser și pe telefoane, dovada versiunii/SHA efectiv publicat, apoi release/deploy numai după aprobare.

**Următoarea clarificare utilă:** ce manifestări observă concret utilizatorul la notificări (lipsă, întârziere, repetare, fără sunet, neafișare, imposibilitate de marcare ca citit), pe ce platformă și în ce stare a aplicației? Alegeți o singură întrebare concentrată; nu presupuneți motivul.

## 9. Reguli confirmate pentru notificările inteligente și Chat live (decizie proprietar 2026-10-13; documentare, fără implementare)

### 9.1 Cerințe reale și comportamente greșite raportate de utilizator

Proprietarul descrie în utilizarea reală:
- **Chat live**: badge-ul numeric «1» ori alt număr revine după fiecare reîncărcare, chiar după ce a intrat în chat să citească.
- **Pop-up-uri**: unele alerte se repetă la redeschiderea aplicației inclusiv după ce notificările au fost citite.
- **Dialogul „Ai terminat sala?” și „ANULEAZĂ”**: apasă Anulează și intervenția se **redeschide**; dorește eliminarea tipului acesta de feedback reversibil/derutant.
- **Notificări persistente numai când solicită răspuns ori acțiune reală și imediată**; restul informărilor trebuie să fie scurte, neintruzive și să dispară.
- **Clopoțelul:** la deschidere să se presupună citirea și să se marcheze automat ca citite; simplificare față de controlul «Marchează ca citit» cerut anterior.
- **Paletă obligatorie a feedbackului tranzitoriu:** **VERDE** succes/salvare confirmată (sală începută/finalizată), **GALBEN** așteptare de acces în sală ori acțiune de schimbare a stării locației, **ROȘU** erori/probleme/conflicte (inclusiv imposibilitatea salvării închiderii). Mesajele reale de **Admin/Sistem** primesc aspect propriu **elegant/premium, diferit** de aceste categorii.

Acestea sunt **decizii funcționale explicite** și simptome reale raportate, dar **nu au fost aplicate în cod**.

### 9.2 Rezultatul auditului țintit al codului — surse exacte

**Chat de grup (cauză probabilă susținută de cod):**
- `lib/chat/group_chat_page.dart::_markChatOpened` scrie `users/{uid}.lastGroupChatSeenAt = FieldValue.serverTimestamp()` **o singură dată la `initState`**, cu `catch (_) {}` care ascunde orice eșec.
- `lib/home/home_page.dart::_recomputeGroupUnread` compară `groupChatMessages.createdAt` cu `lastGroupChatSeenAt` și folosește ultimele **20** mesaje; `_openGroupChat().then(...)` setează **numai local** contorul grupului la zero când revine din chat. Dacă scrierea markerului eșuează sau în chat vin alte mesaje după deschidere, contorul poate reapărea la următoarea sincronizare/reîncărcare. `GroupChatPage` afișează ultimele **50** mesaje, dar listenerul badge calculează din numai 20: valori de badge pot fi limitate/inexacte. `GroupChatPage._send` scrie `createdAt:Timestamp.now()` (ceas client), comparat cu marker generat pe server, deci decalajul ceasurilor poate crea erori de „necitiți”.
- `_startCoreSync` citeste `lastGroupChatSeenAt` pentru contul actual și apoi reface numărul; o simplă setare locală la zero fără confirmare persistată nu este corectarea problemei.

**Chat privat:** `lib/chat/private_chat_page.dart::_markRead` scrie `read=true` în batch pentru mesajele primite și este declanșat în fluxul de afișare; identificăm și testăm repetarea scrierilor, offline, erori, schimbarea conversației, mesaj nou cât pagina este deschisă. Contorul folosește `chatMessages.read`. Nu declarăm că defecțiunea raportată pentru Chat live este în mod automat și în chatul privat.

**Alerta recurentă:** `lib/home/home_page.dart` inițializează la primul snapshot `notifications` și creează popup pentru orice `ownUnread`; separat primul snapshot `chatMessages` afișează popup pentru necitite, iar grupul poate genera alerte pentru mesaje nou apărute în stream. **IMPORTANT:** în listenerul de `notifications`, `read=true` este exclus din `ownUnread`: o notificare sistem deja marcată citită în Firestore **nu ar trebui** să declanșeze acest popup pe acel traseu. Dacă utilizatorul vede totuși popup, cauza poate fi alt listener (chat), o scriere „citit” nereușită, un eveniment diferit ori o notificare nou creată; se verifică sursa exactă, nu se afirmă automat că aceeași înregistrare deja citită este relivrată.

**Undo defectiv ca UX:** `lib/dashboard/dashboard_page.dart::_finishLocation` după STOP salvat adaugă în `SnackBar` `SnackBarAction(label:'ANULEAZĂ')`; callbackul face `widget.saveRecord(source)` unde `source` are status anterior `running`, deci **redeschide intenționat lucrarea**. Nu este simplă anulare de popup. **Conform noii cerințe, această acțiune Undo din confirmarea verde trebuie eliminată**, dar corecțiile autentice ale unei lucrări finalizate trebuie să aibă flux separat, autorizat și auditat; nu putem șterge o intervenție reală prin apăsarea unui buton ambigu.

**Fațadă și STOP:** `dashboard_page.dart::_finishLocation` întreabă în prezent «Fațada a fost realizată?» **necondiționat**, chiar dacă `source.facadePlanned` nu este true, contrar regulii deja aprobate că întrebarea DA/NU este obligatorie **doar când fațada a fost planificată**. La implementarea noului feedback, păstrăm întrebarea obligatorie **integrată în salvarea STOP numai pentru fațade planificate**, ca element al formularului/acțiunii de salvare, **nu** ca un popup suplimentar după succes. Pentru fațade neplanificate nu inventăm «NU» ori DA automat dacă există o corecție reală ulterioară.

**GPS/automatizare:** `HomePage._handleArrivalDetected` afișează `AlertDialog` cu «Ai ajuns la locație — NU ÎNCĂ / SUNT ÎN AȘTEPTARE / ÎNCEP LUCRUL», declanșat automat după un timp de proximitate. Proprietarul nu dorește pop-up-uri intruzive de decizie în afara salvărilor. Înlocuim dialogurile generate doar de proximitate cu **mesaj galben informativ + acțiune opțională** care DESCHIDE ecranul START/Așteptare; GPS-ul **nu pornește și nu încheie** lucrarea singur. Evităm repetarea acestor remindere la fiecare refresh/proximitate.

**Clopoțel:** `_openNotificationsSheet` marchează acum citit numai la `onTap` pe fiecare înregistrare; `SettingsPage` la fel. Noua cerință de **marcare automată la deschiderea clopoțelului** înlocuiește nevoia de a confirma manual citirea fiecărei informări. `firestore.rules` permite titularului să actualizeze `read/updatedAt` pe propria notificare. Modelul `AppNotification` are în esență `read` boolean, dar **nu** stare independentă de «acțiune necesară / acțiune îndeplinită»: pentru persistență corectă trebuie proiectată o clasificare server-side sigură.

**Identitate Admin/Sistem:** `functions/index.js::notificationCategory` și `HomePage._allowPersonalAlert` pot considera obligatoriu mesajul doar dacă `title` conține «admin» ori egal «sistem». `firestore.rules` permite membrilor activi anumite creanțe în `notifications`; astfel identificarea mesajului oficial **după titlul liber nu este sigură**. Doar notificările provenite din acțiuni admin autentificate/server-side pot primi aspectul Premium/Sistem, nivel obligatoriu și semn de încredere. `senderName='Sistem'` de chat pentru admin ascuns este situație separată, care tot trebuie validată la sursă.

### 9.3 Comportament țintă — FĂRĂ suprapuneri între citit, afișat și rezolvat

**Trei dimensiuni diferite:** `delivered/displayed` (informare prezentată deja), `seen/read` (utilizatorul a deschis clopoțelul ori chatul corespunzător), `requiresAction` + `resolvedAt` (un lucru necesită efectiv decizie sau salvare). **Citit nu înseamnă rezolvat**.

- **Informare obișnuită**: toast/banner discret, temporar, auto-dispărut; nu deschide dialog de confirmare, nu păstrează popup la pornire, nu reafișează același `eventId` după refresh, poate rămâne numai în istoric conform retenției. Până la deschiderea clopoțelului poate apărea un indicator discret de „nou”, dar nu un popup persistent.
- **Notificare cu acțiune**: creată numai pentru o condiție reală, actuală și acționabilă, cu destinatar, `entityId`, `requiredAction`, `state=pending|resolved|expired|cancelled`, deduplicare pe cheie de eveniment; rămâne evidențiată până la rezolvarea/refuzul legitim/anularea ori expirarea justificată a obligației. **Deschiderea clopoțelului marchează citit, dar NU rezolvă acțiunea**. Validarea la apăsarea acțiunii se face pe starea actuală server-side: nu redeschide o sală Finalizată, nu dublează Start, nu șterge lucrări.
- **Chat live / privat:** contorul reprezintă mesaje noi încă neparcurse, nu „notificări persistente” după citire. În grup, se salvează un **cursor de citire monoton și durabil pe server** (de preferat poziție stabilă/ordine bazată pe eveniment autorizat, nu pe `Timestamp.now()` client neverificat); la intrarea în chat și cât chatul este activ și mesajele sunt efectiv afișate, cursorul se avansează fără regresie. La părăsire/reîncărcare, calculele din aceeași sursă arată **0** pentru ce a fost parcurs. La mesaj cu adevărat nou, contorul crește numai pentru ce nu a fost văzut, o singură dată; propria trimitere nu îl crește. În chatul privat, citirea mesajelor se confirmă în Firestore, cu retry sigur, stare UI corespunzătoare și fără re-scrieri la fiecare `build`.
- **Clopoțel:** la deschidere se pot marca **automat ca citite toate informările vizibile ale utilizatorului care nu cer acțiune**, într-o actualizare permisă, idempotentă și verificabilă. Pentru notificările cu acțiune, citirea se poate consemna separat, dar **starea pending rămâne** și badge-ul de sarcini neîndeplinite nu dispare doar prin vizitare. Nu se marchează citit înainte ca notificările să fie efectiv disponibile pe ecran; dacă scrierea eșuează offline, se sincronizează ori se avertizează fără a falsifica succesul serverului.
- **Push OS / popup aplicație / badge intern** sunt canale de prezentare distincte ale aceluiași eveniment; se deduplică folosind `eventId`, `deviceId` autorizat și stare server. Un push venit la foreground nu trebuie să producă dublu popup cu listenerul Firestore. La repornirea aplicației, evenimentele vechi doar sunt vizibile în istoric ori, dacă încă au acțiune pending, în zona dedicată, **fără fereastră intruzivă relansată**.

### 9.4 Paletă și dialoguri — DECIZII ALE PROPRIETARULUI

| Tip | Aspect | Text/context | Durată/persistență |
| --- | --- | --- | --- |
| **Succes / salvare** | **VERDE**, icon check | «Sala a fost declarată începută», «Sala a fost declarată finalizată», «Salvarea a reușit» | Toast ~3–5 sec. **FĂRĂ «ANULEAZĂ» care face Undo** |
| **Așteptare/avertizare operațională** | **GALBEN/AMBRĂ**, icon ceas/atenționare | «Se așteaptă accesul în sală», «Actualizează starea locației când ai acces» | Toast discret; dacă este necesară o acțiune, **cardul de acțiune** persistă în locul unui popup |
| **Eroare/conflict** | **ROȘU**, icon eroare | «Finalizarea sălii nu a putut fi salvată», «Conflict detectat», «Datele nu se pot sincroniza» | Toast citibil; problema rămâne acționabilă/diagnosticată dacă e încă nerezolvată, fără reafișarea compulsivă a ferestrei |
| **Admin/Sistem autenticat** | **PREMIUM distinct**, propunere: bleumarin închis, accent auriu discret, icon sigiliu/verified | Titlu «Mesaj de la Admin» / «Mesaj de sistem» **doar după validarea sursei** | Banner elegant; informativ => temporar, cu acțiune reală => card pending până la rezolvare, fără spam la fiecare login |

**Principiu:** **NU mai folosim dialoguri modale de confirmare inutile în afara salvărilor/acțiunilor explicite**. Confirmarea salvării este un mesaj colorat **după** confirmarea persistenței, nu întrebarea repetată «Ești sigur că ai salvat?» și nici o invitație la undo. Dialogul poate rămâne **numai când este necesară introducerea unor date/decizii obligatorii pentru efectuarea salvării** (ex.: DA/NU fațadă PLANIFICATĂ la STOP, motiv de refuz/nerealizare, alegerea graficului ori confirmarea explicită a unei operații ireversibile sau cu impact major); se integrează într-un singur flux coerent, nu succesiuni de pop-up-uri după salvare. Dacă proprietarul cere ulterior ZERO dialoguri chiar la astfel de operații sensibile, propuneți alternative inline, fără a pierde date obligatorii ori riscurile de autorizare. GPS nu impune modal automat.

**Notă despre galben:** o salvare reușită a statusului «Așteptare acces» poate arăta **confirmare galbenă**, nu verde generic; este un rezultat de stare intermediară și semnalizează nevoia ulterioară de acces, conform clasificării cerute.

### 9.5 Matrice minimă de acceptare și scenarii de test (doar PROIECTATE)

1. Mesaje de grup deja citite => contor zero și la F5 / reconectare / login pe al doilea dispozitiv; mesaj nou primit în timp ce chatul este deschis și vizibil nu crește contorul; mesaj nou după ieșire îl crește o singură dată.
2. Mesaje private citite => badge zero după revenire/offline retry; fără loop de scrieri; neautorizatul nu poate marca mesajele altei persoane citite.
3. Deschiderea clopoțelului => informările vizibile devin citite automat; acțiunea pending rămâne și este marcată rezolvată **doar de operația reală**, indiferent de citirea din clopoțel; notificările deja citite nu reapar pop-up.
4. Salvare START/STOP confirmată => toast verde, fără buton Undo; butonul de abandon al unui **formular înainte de salvare** nu are efect asupra intervenției. Fișă finalizată nu poate fi redeschisă printr-un snackbar.
5. La STOP cu fațadă **planificată** se cere DA/NU, fără execuții parțiale ori minute pe om; la STOP fără fațadă planificată nu se pune întrebarea. Cerința se aplică Dashboard, widget și orice alt flux.
6. Așteptare acces => galben, accesul se confirmă prin acțiune de utilizator; nu se pornește/închide sala din cauza GPS-ului.
7. Eroare de salvare/race între două dispozitive => toast roșu și stare reală păstrată, fără verde fals și fără status «Finalizată» dacă Firestore a eșuat.
8. Notificare «Admin/Sistem» creată prin titlu de un utilizator normal => **nici premium, nici bypass** al filtrelor; numai actorul autorizat și evenimentul verificat pot primi încrederea de sistem.
9. Notificare nouă = o alertă (fără dublare din FCM + stream); după repornire doar acțiunile nerezolvate persistă, informările vechi în istoric fără toast repetat; pushul din fostul cont nu ajunge după schimbarea conturilor.
10. Teste Flutter widget/integration, emulator Firestore+Cloud Functions, scenarii Android/web real, offline, versiune instalată/publicată și acces la API. Nu confundați simularea aritmetică cu verificări ale aplicației.

**Verificări de model**: 15/15 aserțiuni JS fictive (citit vs pending, contor monoton de grup, cont vechi/dubluri, clasificare autentică admin, culori, fără Undo, STOP fațadă doar planificată). **NU** au fost rulate teste Flutter, Firestore, Functions, CI ori teste reale pe telefon/web.

### 9.6 Următorul pas

Actualizați documentele canonice `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` și `ChatGpt`. Apoi decideți împreună UI-ul complet și istoricul echipelor conform mandatului; implementarea și testarea finală rămân la sfârșit conform ordinii stabilite a proiectului. **Fără modificări de cod, Firestore, Firebase live ori deploy prin această notă**.

## 10. Prioritatea notificărilor Learning, semnalizarea în clopoțel și cheia Android (2026-10-13)

### 10.1 Cerințe noi exprimate direct de proprietar

- **Clopoțel:** fiecare notificare poate avea **simbol și culoare reprezentând importanța**, pe lângă separarea `read` și `requiresAction`; iconografia și codarea trebuie să fie accesibile și prin text, nu numai culoare.
- **Learning:** **notificările și sugestiile sale sunt IMPORTANTE**, deci nu trebuie tratate ca simple informări neinteresante ori îngropate în listă. **Atenție la regula deja aprobată:** numai mesajele cu acțiune/răspuns real pot fi persistente; o recomandare informativă importantă nu se transformă automat în popup recurent.
- **Cheia aplicației Android:** proprietarul cere să se **păstreze cheia permanentă pentru actualizările versiunilor viitoare**, evitând instalarea peste existentă cu semnătură incompatibilă. Cerința de **continuitate a cheii de semnare** este aprobată ca obiectiv; **NU se presupune că cheia este deja salvată**.

### 10.2 Propunere de clasificare pentru clopoțel — neconfirmată în toate detaliile

- **Roșu, `circle-alert` / triunghi de atenționare:** blocaj sau eroare serioasă care cere intervenție. Card `pending` dacă nu a fost rezolvat; simple erori istorice deja încheiate nu persistă.
- **Galben/ambra, clepsidră:** acces în așteptare ori schimbare operațională necesară, cu termen/scop real. Dacă necesită acțiune, rămâne card pending.
- **Learning: violet sau albastru-indigo, icon creier/scânteie/carte:** recomandare/analiză de valoare, **prioritate mare în clopoțel** și categorie distinctă. Sugestia care cere aprobare/alegere utilizatorului e candidat la persistență **doar până la aplicare, respingere, amânare explicită ori expirare bine definită**; observația pur informativă se marchează automat citită la deschiderea clopoțelului. **Culoarea exactă și acțiunile trebuie confirmate cu proprietarul pe rând.**
- **Verde cu bifă:** operație salvată, informare scurtă, fără Undo din mesaj.
- **Admin/Sistem autentic:** stil premium bleumarin + accent auriu/sigiliu numai pentru sursă validată criptografic și autorizată server-side; importanța/severitatea se evaluează separat, nu implică automat `pending`.
- **Gri neutru:** informare obișnuită, neacționabilă, istoric fără popup repetitiv.
- Lista poate prioritiza **acțiuni reale nerezolvate**, apoi Learning acționabil, apoi restul după recență; ordinea exactă și aspectul se decid în discuții separate, nu se impun ca regulă finală acum.
- Pentru toate: texte și iconuri explicite, contrast accesibil, stare `read` distinctă de `resolved`, fără schimbarea drepturilor sau a regulii privind popupurile persistente.

### 10.3 Audit read-only al semnării Android — ATENȚIE, risc de actualizare

**Dovada din sursa GitHub actuală**:
- `android/app/build.gradle.kts` în blocul `buildTypes.release` are comentariul `Signing with the debug keys for now` și `signingConfig = signingConfigs.getByName("debug")`.
- `.github/workflows/build-android.yml` folosește `flutter build apk --release` și NU configurează explicit o cheie permanentă de semnare în acel workflow.
- `pubspec.yaml` arată acum `version: 3.0.1+33`, **dar acesta nu certifică versiunea instalată**, semnătura APK-ului de pe telefon ori configurația unui alt build.

**Concluzie justificată:** **Nu există dovadă că APK-ul actual de release al repo-ului este semnat cu o cheie PERMANENTĂ de release**. Configurația sursei îl semnează cu debug; pe runnerul CI cheia debug poate fi proprie mediului și poate diferi între builduri. O versiune numerică mai mare nu corectează o semnătură diferită. **Nu promitem compatibilitate până nu comparăm certificatele.**

**Plan tehnic obligatoriu înaintea primei lansări APK noi** (nu încă executat):
1. Identifică în condiții autorizate **certificatul/fingerprintul SHA-256 și pachetul** APK-ului instalat pe telefon și ale fiecărui artefact APK candidat. Nu cere utilizatorului parole ori cheia privată în chat.
2. Verifică dacă **keystore-ul privat corespunzător semnăturii instalate mai există**, cine îl controlează și dacă poate fi păstrat în siguranță. Certificatul/fingerprintul public **NU** este cheia privată și nu permite semnarea singur. Nu putem recupera cheia privată din APK-ul semnat.
3. Pentru viitor: **o singură identitate de semnare oficială**, keystore securizat în vault/manager de secrete, backup securizat separat, parole în secret manager, acces limitat, audit și procedură de restaurare. **NICIODATĂ cheia privată, parole sau exporturi de keystore în GitHub public/documentație/artefacte neprotejate**.
4. CI folosește secretul protejat temporar pentru semnarea release; se verifică înainte de publicare certificatul SHA-256, `applicationId`, `versionCode` crescător și faptul că release APK chiar este semnat cu cheia aprobată. Nu folosi cheia debug pentru release oficial. Se previne publicarea dacă identitatea semnării nu corespunde.
5. Dacă semnătura APK-ului instalat nu poate fi reprodusă (cheia originală nu există) și platforma de distribuție nu furnizează mecanism de continuitate permis, **actualizarea directă peste acel APK nu este posibilă**. Va fi necesar un plan autorizat pentru o tranziție/reinstalare unică, fără ștergerea datelor de pe dispozitiv înaintea salvării operațiilor nesincronizate, după evaluarea consecințelor. **Nu faceți acum reinstalare, generare de chei, upload de secrete ori lansare.**

### 10.4 Pasul următor de produs

Proprietarul dorește o discuție **câte o singură propunere despre notificări**, la care să răspundă cu **«Da» / «Nu» / propria variantă**, nu un pachet mare de reguli de aprobat simultan. **Prima propunere:** sugestiile Learning care solicită o alegere explicită să rămână evidențiate cu simbol distinct până la rezolvare, iar analizele Learning informative să rămână prioritizate vizual dar să fie marcate citite la deschiderea clopoțelului. Formularea și culoarea exactă se discută cu proprietarul.

**Statut:** documentare și audit static, fără creare/salvare efectivă a keystore-ului, fără modificări de cod Flutter/Android, Firebase, Rules, CI sau deploy.

## 11. Confirmare Learning — notificări violet-indigo, cu acțiuni explicite (2026-10-13)

**APROBAT EXPRES:** proprietarul a spus «Confirm propunerea 1 pentru notificările Learning. Trecem la următoarea.»

- Notificările Learning au identitate vizuală **violet-indigo**, cu pictogramă specifică Learning (creier/scânteie) și prioritate ridicată în clopoțel.
- Recomandarea Learning care solicită aprobare este **acționabilă și persistentă** până la alegerea **Aplică** sau **Respinge**. **Amână** trebuie să respecte data/momentul stabilit pentru revenire, fără reafișări la fiecare refresh.
- Recomandarea doar informativă rămâne în istoric, se marchează citită la deschiderea clopoțelului și nu creează popup recurent.
- «Citit» este independent de «rezolvat»; simpla deschidere a clopoțelului nu aprobă sugestii. Learning **nu aplică unilateral modificări care cer aprobare**. Validare server-side, jurnal al deciziei, verificări de drepturi și deduplicare la implementare.
- Această regulă este **definitiv aprobată** ca parte din propunerea 1. Detaliile tehnice se testează în staging; nu există implementare în această sesiune.
