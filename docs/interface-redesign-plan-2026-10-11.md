# AndiCarpet v3 — plan reorganizare interfață (decizii aprobate 2026-10-11)

## Navigare
- Dashboard rămâne ecranul principal, cu datele existente. Profilul rămâne în poziția și forma actuală.
- Grupuri laterale glisante din dreapta, cu butoane proeminente: **Tură**, **Hartă**, **Centralizator**, **Setări**; chatul rămâne accesibil separat.
- Fiecare grup reține ultimul subtab deschis; navigarea înapoi nu resetează selecția.

## Tură
- Subtaburi: Grafic activ editabil; Locații în grafic; Decont echipă (vizibil numai membrilor echipei).
- Graficul poate fi **pornit de orice membru al echipei**; operațiunea trebuie autorizată server-side pentru membrul echipei respective, cu prevenirea pornirilor concurente/dublurilor și jurnal de audit.
- Graficul rămâne deschis peste miezul nopții, schimbarea datei și închiderea aplicației.
- Închidere automată când **toate intervențiile** sunt finalizate și nu există activități/așteptări în curs; administratorul poate închide manual, cu confirmare, fără a marca intervențiile incomplete ca finalizate.
- **STOP** marchează intervenția ca finalizată. Întrebările obligatorii („Ai intrat pe sală?”, „Ai făcut fațada?”) rămân înregistrate și vizibile până primesc răspuns; nu se pierd la STOP. Dacă răspunsurile sunt necesare pentru raportare, semnalizează lipsurile separat, fără a schimba arbitrar starea intervenției.
- Locații: bifă verde pentru rezolvate; clepsidră galbenă pentru următoarele ore/zi; clepsidră roșie pentru celelalte. Iconuri clare cu relief discret și contrast.
- La pornirea graficului, decontul preia orele **planificate** de început și sfârșit; orele reale se înregistrează separat, fără suprascriere.

## Hartă
- Harta este primul și cel mai important element vizual; dedesubt legendă și filtre selectabile.
- Membri: afișează **toți membrii**, cu ultima poziție disponibilă și indicator explicit al vechimii poziției; verde = Live, galben = Economic. Nu prezenta poziții vechi ca poziții în timp real.
- Listă de locații pe categorii: Million, Magic, HoReCa, Sediu, Membri.
- Administratorul poate edita locațiile; ceilalți membri pot sugera modificări spre aprobare, fără a modifica direct datele.
- Traseele și categoriile păstrează comportamentul existent până la validarea modificărilor.

## Centralizator
- Centralizatorul complet existent.
- Decont informativ: statistici complete, fără acțiuni de editare.
- Buletin diurne și printare numai pentru rolurile/utilizatorii autorizați explicit de administrator.
- Documente.

## Setări
- Preferințe personale: notificări, locație, culoarea numelui în chat/profil, font/stil unde este compatibil cu lizibilitatea.
- Setări aplicație: temă luminoasă/întunecată și alte opțiuni existente.
- Panou Admin accesibil numai administratorilor, inclusiv protecție în regulile backend.

## Widget Android
- **Un widget mare combinat**, în loc de două widgeturi separate: grafic/tură, sală apropiată detectată, START verde, AȘTEPTARE galben, STOP roșu după START, întrebări obligatorii cu DA/NU.
- Când nu există sală în apropiere, afișează sigla AndiCarpet; când există, numele sălii și starea detectării. Proximitatea nu pornește automat intervenția.
- Butoane și săgeți cu suprafețe de atingere mari; aspect modern cu ramă luminoasă discretă, fundal distinct pe sală, contrast text garantat.
- Tratare explicită a lipsei conexiunii, prevenirii comenzilor duplicate și sincronizării sigure înainte de activarea acțiunilor offline.

## Audit și criterii de acceptare
1. Rezolvare eroare roșie la memorarea conturilor / navigare, inclusiv verificare mounted/dispose.
2. Remediere overflow în formulare, liste, navigare și ferestre pe ecrane înguste.
3. Teste automate pentru permisiuni de pornire, închidere, STOP, diurne și modificări de locații; teste widget și navigare.
4. Verificare că niciun ecran/flux existent nu a fost pierdut în reorganizare.
5. Nu se face merge, deploy sau APK fără verificările verzi și aprobarea utilizatorului.

## Animație la lansare — cerință aprobată
- Dashboard-ul își păstrează exact conținutul și aspectul actual.
- La deschiderea aplicației, fundalul temei este vizibil imediat, la fel și comenzile laterale pentru panouri, profilul, chatul și membrii; acestea rămân interactive.
- Dashboard-ul este inițial ascuns și începe să apară prin fade-in după 3 secunde, cu durată țintă ~700 ms.
- Întârzierea se aplică o singură dată per lansare a aplicației, nu la navigare sau revenire dintr-un panou; timerul se anulează corect la dispose.
- Respectă preferința de reducere a animațiilor; evită întârzieri suplimentare pentru interacțiuni, mesaje urgente sau stări critice.
- Teste: controalele sunt accesibile imediat; Dashboard ascuns înainte de 3 secunde, vizibil după fade; navigarea nu repornește întârzierea; fără setState după dispose.

## Agendă — înlocuiește tabul Mesaje (cerință aprobată)
- Redenumește tabul existent **Mesaje** în **Agendă**; mesageria rămâne numai în panoul lateral **Chat**, fără funcție duplicată în Agendă.
- Buton dedicat **Agendă**; la deschidere afișează lista locațiilor și, sub fiecare, contactele disponibile: manager (nume/rol și număr), casierie și orice alte numere configurate.
- Fiecare număr are propriul buton de apelare, cu schemă `tel:` și validare/normalizare conservatoare a numerelor; nu iniția apeluri automat.
- Agenda este **read-only** pentru toți utilizatorii: fără editare, adăugare sau ștergere.
- Editarea numerelor/contactelor se face exclusiv în **Hartă → Locații → Detalii locație**, în aceeași interfață în care se editează celelalte detalii, doar de către administrator; utilizatorii neautorizați pot sugera corecții, dacă există fluxul de aprobare.
- Nu afișa rânduri fictive pentru numere lipsă; teste pentru contactele multiple, lipsa numerelor, permisiuni și deschiderea dialerului.

## Actualizare aprobată: Agendă în grupul Chat
- Panoul lateral **Chat** are două subtaburi distincte: **Mesagerie** (funcția existentă) și **Agendă** (doar citire); Agendă NU este un buton lateral independent.
- Agendă include filtre selectabile după categoriile existente în aplicație: **Toate, Magic, Million, HoReCa, Sediu, Membri** (sincronizate cu nomenclatorul real al categoriilor).
- Afișează toate locațiile din categoriile selectate, chiar dacă nu au numere; pentru **Membri**, afișează membrii echipei și contactele telefonice disponibile, în limitele permisiunilor de vizibilitate existente.
- Sub fiecare locație: manager, casierie și alte contacte disponibile, fiecare cu număr și acțiune de apelare; lipsa contactelor se afișează discret.
- Fără editare în Agendă; modificarea contactelor locațiilor se face numai în editorul detaliilor locației, cu autorizare de administrator.
- Panoul reține subtabul și filtrul selectat la revenire. Teste pentru filtre, membri, contacte lipsă și autorizare.
- Această secțiune înlocuiește propunerea anterioară de buton Agendă separat.

## Căutare rapidă în Agendă — aprobată
- În subtabul **Chat → Agendă**, afișează o bară de căutare ușor accesibilă.
- Caută după numele locației, numele managerului, numele membrului și, dacă există, denumirea celorlalte contacte.
- Căutarea se combină cu filtrul de categorie selectat (Toate/Million/Magic/HoReCa/Sediu/Membri), fără a reseta filtrul sau subtabul la revenire.
- Rezultatele se filtrează pe măsură ce utilizatorul tastează; afișează stare clară pentru zero rezultate și opțiune de golire a căutării.
- Căutarea este exclusiv de consultare, fără drepturi de editare și fără afișarea datelor neautorizate.
- Teste pentru căutare fără diacritice, nume parțiale, filtre combinate și rezultate inexistente.

## Paritate de interfață între platforme — aprobată
- Designul, navigarea, panourile laterale, subtaburile, filtrele, Agenda și animația Dashboard trebuie să fie consistente în Android APK, browser pe Android, Safari/iOS și browser desktop.
- Folosește aceeași logică Flutter responsive, adaptată doar la lățime, safe areas, input tactil/tastatură și posibilitățile platformei; evită ecrane separate cu funcții divergente.
- Fade-in-ul Dashboard după 3 secunde funcționează pe toate platformele, cu respectarea preferinței de reducere a animațiilor.
- Widgetul de ecran principal este exclusiv Android; comenzile de intervenție echivalente trebuie să fie accesibile în aplicația web/iOS, fără a promite widget nativ iOS.
- Teste responsive pentru lățimi mici, tablete și desktop; verifică overflow, accesibilitate, scroll, navigare înapoi, tastatura mobilă, apelarea tel: și orientarea ecranului.
- Nu se publică web și nu se generează APK fără validare și aprobarea utilizatorului.

## Flux de dezvoltare și testare — decizie utilizator
- Ciclul de lucru: **implementăm → pregătim testul automat aferent (fără rulare) → implementăm următoarea funcție → pregătim testul**.
- Nu se așteaptă verdictul GitHub Actions după fiecare commit; se pregătesc teste unitare, widget și integrare pe parcurs.
- După finalizarea tuturor modificărilor, se rulează **o singură suită completă** de teste (Flutter, Firestore rules, Functions, responsive, regresie), apoi se corectează erorile și se reexecută verificările relevante.
- Dacă CI pornește automat la push, rulările intermediare nu sunt tratate ca puncte de blocare; nu se pretinde că pot fi împiedicate fără schimbarea workflow-ului.
- Fără merge, APK sau publicare web până la validarea finală și aprobarea utilizatorului.

## Pictograme 3D aprobate
- Utilizatorul a aprobat setul vizual generat de pictograme 3D colorate pentru taburi, subtaburi, filtre și acțiuni.
- S-au extras 48 pictograme WebP într-o arhivă locală `AndiCarpet_3D_Icons.zip`, cu `assets/icons3d/manifest.json`.
- Integrare rămasă: transferul fișierelor binare WebP în repo, înregistrarea directorului în `pubspec.yaml`, înlocuirea iconurilor din navigație și pagini cu imagini responsiv scalate, fallback pentru iconurile lipsă, apoi teste responsive și de contrast.
- Nu marca integrarea ca finalizată până când fișierele binare sunt efectiv în repo și referințele Flutter sunt legate de ele.

## Pachet nou de stickere foto pentru Chat live
- Au fost generate 24 stickere individuale `andi_01.webp` ... `andi_24.webp`, din colajul aprobat de utilizator; pachetul există momentan ca artefact de conversație, nu ca asset în repository.
- Integrarea trebuie să adauge chei stabile distincte (`andi_photo_01` ... `andi_photo_24`) în selectorul comun pentru chat de grup și privat, păstrând stickerele BRC existente.
- Încărcarea fișierelor binare în `assets/stickers/` și declararea lor în `pubspec.yaml` sunt condiții obligatorii înainte de a considera implementarea completă. Nu introduce căi spre fișiere inexistente și nu declara finalizată integrarea doar pe baza planului.
- Teste de pregătit: fiecare asset există, poate fi decodat, este inclus în bundle, cheia poate fi selectată și trimisă, iar receptorul afișează același sticker pe Android/iOS/web.
