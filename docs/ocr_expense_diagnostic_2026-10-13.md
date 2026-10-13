# Diagnostic OCR și autorizarea salvării cheltuielilor — 2026-10-13

**Sursă de bază:** `main` la commit `377f1fd5e73ae78a0df5cab58b09770c873cd167`. Acest lot este **independent de Work / PR #28**, care modularizează aplicația. Nu se înlocuiește niciun fișier din ramura Work. Niciun deploy, merge, APK publicat sau schimbare Firebase în producție.

## 1. Defect confirmat prin analiză: parsarea totalurilor cu separatori de mii

În `lib/ocr_parser.dart`, ambele expresii pentru totaluri capturau forma scurtă `[0-9]{1,7}(?:[.,][0-9]{2})?`, care poate extrage doar o porțiune din `1.234,56`, `1,234.56` ori `1 234,56`. `_cleanNumber` știe deja să normalizeze separatori mixti, dar era apelată pe o valoare trunchiată. Patchul schimbă **doar cele două expresii de captură** să accepte grupuri de trei cifre și exact două zecimale; comportamentul formatelor standard rămâne acoperit de regresii.

Teste Flutter pentru totaluri sintetic construite (fără bonuri reale sau date personale), inclusiv `1.234,56`, `1 234,56`, `1,234.56`, `12.345,67`, `123.456,78`, `148,75` și `199.99`; plus separarea între TOTAL TVA și TOTAL DE PLATĂ. Testele fac parte din `flutter test test/`.

## 2. Defect separat: autorizarea scrierii OCR pentru non-admin

Traseul operațional este `ExpensePage._scan()` -> `parseFiscalOcr` -> `_expenseDialog()` și `_expenseAmountBani()` -> `_saveNewExpense()` -> `HomePage._saveExpenseDirect()` -> `_expenseMap(e)` -> `expenses/{id}.set(..., merge:true)`.

Pe `main`, `firestore.rules`, `match /expenses/{expenseId}`, permite `create` pentru non-admin doar dacă utilizatorul este activ, are `viewOwnDecont`, este în echipă și `request.resource.data.distributedBy == request.auth.uid`. **Payloadul real `_expenseMap` nu conține `distributedBy`**, indiferent dacă suma vine din OCR sau a fost introdusă manual. Poate apărea `permission-denied` fără nicio eroare de parsare.

Am adăugat **4 teste emulator Firestore** în `tests/firestore/diurna.test.cjs`, fișierul efectiv rulat în CI pe proiectul `demo-andi-carpet`, care verifică: (1) admin salvează payloadul real; (2) membru activ cu `viewOwnDecont`, membru al echipei, este respins la payloadul fără `distributedBy`; (3) aceeași persoană poate crea un document dacă se adaugă explicit câmpul respectiv în fixture (diagnostic, **nu soluția dorită**); (4) membrul unei alte echipe rămâne respins.

**Nu adăugați arbitrar `distributedBy` cheltuielilor.** În fluxul diurnelor, acest câmp desemnează distribuitorul, în timp ce cheltuiala are autor/solicitant, gestionar și confirmator potențial diferiți. Remedierea sigură necesită contract aprobat pentru `createdBy`, `submittedBy` ori altă proveniență explicită, imutabilă, cu validare server-side, controale update, backfill compatibil și teste roluri. `firestore.rules` rămâne nemodificat în acest lot; datele de producție nu sunt accesate.

## 3. Observații și verificări obligatorii

- `ocrRawText` nu este persistat după confirmarea cheltuielii, pentru confidențialitate, conform deciziei existente. Separat, evenimentul `Learning` al salvării este etichetat `ocr` în funcție de `ocrRawText`, deci poate fi clasificat `finance` chiar după scanare. Nu schimbăm comportamentul fără un indicator de proveniență minim și teste.
- Succesul CI confirmă testele parserului, caracterizarea actualelor reguli și compilarea; **nu confirmă** că acel defect de permisiune este rezolvat, nici ce reguli sunt publicate pe Firebase live.
- Rămân de făcut teste autentificate Android/web cu 2 membri reali, înainte de aprobarea oricărui deploy. Nu se stochează text OCR brut în logs, nu se adaugă API plătite și nu se modifică facturarea.

**Stare finală a acestui lot:** așteptarea CI pe SHA final; PR Draft, independent de Work.

## 4. Consolidare OCR: total de plată vs TVA și validare calendaristică (13.10.2026)

- Defect adițional identificat: algoritmul prefera ultima apariție TOTAL, astfel `TOTAL TVA` tipărit după `TOTAL DE PLATĂ` putea deveni suma salvată. Prioritatea de extragere este acum (1) TOTAL DE PLATĂ / SUMA DE PLATĂ explicit, (2) TOTAL generic dar nu SUBTOTAL / TOTAL TVA, (3) sume cu RON/LEI ca fallback. Această schimbare afectează exclusiv parserul OCR și este verificată cu bonuri sintetice în ordini diferite.
- Defect de dată: `DateTime` normalizează zile calendaristice imposibile, de exemplu 31 februarie în martie. Parserul respinge acum datele care nu corespund exact zilei/lunii/anului; păstrează 29 februarie în an bisect și verifică și formatul ISO. În lipsa unei date recunoscute, utilizatorul verifică manual data în dialog.
- Sfera: două fișiere de parser/test și această notă; fără model financiar, Firebase rules, schema, Learning, folderele Work/PR #28, date personale ori deploy. Sunt necesare Flutter tests/web și celelalte verificări CI pe commitul final.

## 5. Caracterizare suplimentară a drepturilor de modificare cheltuieli

- Regula `expenses.update` existentă permite oricărui membru activ cu `viewOwnDecont` și apartenență la echipă să modifice **orice câmp** al unei cheltuieli din echipa sa, atât timp cât `teamId` rămâne într-o echipă în care este membru. UI cere gestionarului confirmarea, dar cererile directe prin Firestore pot schimba `confirmed=true` și `amount`. Nu este nevoie ca membrul să fie autorul cheltuielii. Aceasta este o constatare de securitate statică, caracterizată prin emulator, nu o acțiune făcută asupra datelor reale.
- Regula de `expenses.create` nu validează `confirmed` pentru non-admin; dacă documentul conține `distributedBy=uid` (câmp pe care fluxul real de cheltuieli nu îl scrie), acel membru poate crea deja o cheltuială cu `confirmed=true` fără aprobarea gestionarului. Această observație nu justifică adăugarea câmpului ca „soluție”.
- Adăugate patru teste suplimentare în `tests/firestore/diurna.test.cjs` (suite deja executate în CI): actualizare neautorizată din punct de vedere business dar permisă în regula actuală, outsider respins, mutare la altă echipă respinsă, creare autoconfirmată permisă. Testele `assertSucceeds` pentru comportamente nesigure sunt **martori ai defectului existent**, nu acceptare a lui. Când fixăm regulile, ele trebuie transformate în teste `assertFails` pentru abuz, iar fluxurile legitime trebuie testate pozitiv.
- Remedierea necesită decizia despre identitatea autorului, dreptul gestionarului la confirmare, câmpuri imutabile (echipă, document, sumă) și compatibilitatea cu documentele deja create, inclusiv OCR și introducere manuală. Nu implementăm reguli financiar-sensibile ori migrarea fără acord. Firebase de producție nu este accesat; singurul mediu de test este emulatorul `demo-andi-carpet`.
