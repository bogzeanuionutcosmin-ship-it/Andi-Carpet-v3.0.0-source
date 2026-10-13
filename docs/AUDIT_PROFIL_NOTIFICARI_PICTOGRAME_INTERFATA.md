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
