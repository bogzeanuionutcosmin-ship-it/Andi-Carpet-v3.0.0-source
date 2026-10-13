# Propunere pentru autorizarea cheltuielilor — 13.10.2026

**Document de analiză, nu decizie aprobată și nu remediere aplicată.** Bază: PR #29, SHA 72fbdaa25deeebec603b5089490973996dc3813a. Work continuă separat PR #28.

## Incompatibilități confirmate în sursa actuală

- Cheltuielile OCR/manuale folosesc `Expense` și `_expenseMap`, care nu conțin `distributedBy`. Regula `expenses.create` îl cere non-administratorilor. Testele existente din emulator reproduc respingerea unei cereri care altfel are drepturi de echipă.
- La actualizarea cheltuielilor, regulile nu disting între modificarea unei sume și confirmarea ei. Testele emulator existente reproduc posibilitatea de actualizare directă a `amount` și `confirmed` de către un membru cu `viewOwnDecont` din echipă.
- UI calculează gestionarul prioritar din `settlement.managerId`, apoi `finance.managerId`, apoi `team.financialManagerId`. Regula `teams` rezervă modificările administratorului, însă `finance` și `settlements` permit actualizări mult mai largi membrilor cu `viewOwnDecont`. **Sursa de autoritate a gestionarului trebuie protejată, nu doar verificată în interfață.**

## Contract recomandat pentru aprobare

1. **Creare:** membrul activ autorizat al propriei echipe poate înregistra un document manual sau OCR ca `confirmed=false`. Identitatea autorului, de exemplu `createdBy`, trebuie verificată server-side și păstrată imuabilă. Nu reutilizăm `distributedBy` din diurne pentru cheltuieli.
2. **Confirmare:** doar administratorul sau gestionarul real, validat server-side dintr-o sursă protejată, poate confirma documentul. Un gestionar autorizat poate crea documente deja confirmate numai dacă această regulă este aprobată.
3. **Corectare:** înainte de confirmare, corecțiile autorului se limitează la propriul document și nu pot falsifica echipa ori aprobarea; modificările de sumă după confirmare au nevoie de un proces separat, auditat, nu de suprascriere tăcută.
4. **Autoritatea gestionarului:** trebuie aleasă o singură sursă canonică sau un mecanism de delegare protejat. Recomand analizarea lui `teams.financialManagerId`, modificabil numai de Admin; schimbările de rol, echipă, decont și istoricul existent necesită validare înainte de orice tranziție.
5. **Legacy și confidențialitate:** păstrăm documentele vechi, calculele, confirmările și avansurile financiare, fără backfill inventat și fără text OCR brut ori fotografii stocate inutil.

## Validări necesare înainte de implementare

Teste cu administrator, gestionar autorizat, autor obișnuit, coleg neautorizat, altă echipă și cont inactiv; verificarea depunerii, confirmării, reviziei sumei, proprietarului, închiderii decontului, delegării gestionarului și a conflictelor offline. Testele actuale care caracterizează drepturile prea largi vor deveni teste de refuz numai odată cu repararea regulilor, cu cazuri pozitive pentru fluxul legitim. Verificări Flutter/Android/web, emulator Firestore și documente legacy, fără acces la Firebase live.

**Încă necesită decizii:** cine poate rectifica o sumă neconfirmată, cine poate rectifica una deja confirmată, cine desemnează gestionarul pentru fiecare deplasare și cum tratăm documentele din deconturi închise.

Fără modificări `firestore.rules`, date Firebase, deploy, merge, billing, diurne sau PR #28.

## Teste suplimentare de integritate pentru finanțe (13.10.2026)

Cinci scenarii noi, exclusiv în emulatorul Firestore `demo-andi-carpet`, caracterizează efectele regulilor **existente** și evidențiază că un simplu control de confirmare în UI nu este suficient:

- `finance`: un membru autorizat al echipei poate desemna ca `managerId` un utilizator din altă echipă; nu se verifică apartenența celui desemnat și nici permisiunea lui de gestionar.
- `finance`: aceeași categorie de membru poate suprascrie direct suma declarată primită, ocolind restricțiile UI.
- `settlements`: un membru al echipei poate redeschide direct un decont închis, fără fluxul de confirmare din interfață.
- `expenses`: un membru poate reveni de la `confirmed=true` la `false` și modifica simultan suma unei cheltuieli confirmate.
- `expenses.create`: dacă adaugă manual câmpul `distributedBy` cerut actualmente de rules (absent din modelul real Expense), un membru poate crea un document cu sumă negativă și `confirmed=true`; serverul nu validează pozitivitatea sumei.

**Atenție:** `assertSucceeds` pe aceste scenarii indică vulnerabilitățile existente, nu permisiuni aprobate. Până la un contract stabilit cu proprietarul nu se schimbă `firestore.rules` ori istoricul. În remedierea viitoare, aceste scenarii trebuie să fie refuzate și testele schimbate explicit la `assertFails`, fără pierderea fluxurilor legitime, a avansurilor și confirmărilor istorice. Nu se consideră că regulile publicate în producție sunt identice cu cele din repository; datele reale nu au fost accesate.
