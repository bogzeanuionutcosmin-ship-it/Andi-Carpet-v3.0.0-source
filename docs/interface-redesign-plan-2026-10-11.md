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
