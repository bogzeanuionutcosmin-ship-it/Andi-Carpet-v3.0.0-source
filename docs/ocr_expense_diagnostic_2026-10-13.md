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