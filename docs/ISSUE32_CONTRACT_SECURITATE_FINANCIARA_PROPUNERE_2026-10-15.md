# AndiCarpet — Issue #32: contract propus pentru securitatea financiară

**15.10.2026 · DRAFT DE ANALIZĂ / NU ESTE APROBARE DE IMPLEMENTARE**  
Sursă: `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` (mai ales secțiunile 10–12, 14), `ChatGpt`, `firestore.rules`, `lib/home/home_document_codecs.dart`, Issue #30 și #32. Bază de diagnostic: PR #38 (Vision integrat în test) și PR #40 (teste emulator izolate). Nu sunt examinate regulile Firebase live.

## A. Decizii EXISTENTE aprobate, care nu trebuie repuse la vot

1. **Admin** este autoritate distinctă de funcții profesionale, server-validated; `developer`, `director` sau `driver` nu conferă automat rol admin.
2. **Director** poate consulta deconturile celorlalte echipe numai read-only. Drepturile sunt contextuale, cumulative între funcții active, iar vizualizarea nu înseamnă editare.
3. **Echipa** are maximum 2 membri activi, fiecare într-o singură echipă; înlocuirea pe grafic deschis este excepție administrativă controlată și nu rescrie istoricul.
4. **Gestionarul** este desemnat explicit; poate exista cel mult unul principal per echipă. Înlocuirea anticipată în grafic deschis este decisă exclusiv de Admin, inclusiv în urgență și chiar fără predarea completă a banilor. Succesorul primește drepturi viitoare, fără preluarea contabilă automată a soldurilor neconfirmate.
5. **Beneficiarul diurnei** confirmă/refuză propria plată, nu gestionarul în locul lui. Avansurile peste diurna deja cuvenită **sunt permise**, iar `perDiems` și `per_diem_settlements_v2` nu se comasează tacit.
6. Schimbarea funcțiilor/drepturilor trebuie aplicată pe server. Retragerea dreptului este reală, nu cosmetică; audit minim al operațiunilor sensibile.

## B. Neconcordanțe dovedite în repository / emulator, NU în producție

| Suprafață | Comportament prezent verificat | Risc |
|---|---|---|
| `expenses.create` | DTO `_expenseMap` nu include `distributedBy`, dar rules cer `distributedBy == auth.uid` pentru non-admin | Salvari OCR legitime refuzate |
| `expenses.create` | Cu `distributedBy` injectat de client, lipsesc verificări comune de sumă validă și `confirmed=false` | Documente fictive/negative ori autoconfirmare la creare |
| `expenses.update` | `viewOwnDecont` + apartenență la echipă permite editarea `amount`/`confirmed` | Coleg schimbă valori sau confirmări fără autoritate de gestionar |
| `finance/{teamId}` | `viewOwnDecont` + apartenență permite create/update fără allowlist de câmpuri | Gestionar neautorizat, `receivedDeparture` modificat, inconsistență `teamId` intern |
| `settlements` | Membri cu `viewOwnDecont` creează/actualizează inclusiv `managerId`, `closed` | Redeschideri sau închideri neautorizate |
| `hasLegacyPermission` | Pentru `function='director'`, fără `effectivePermissions`, se acordă orice permisiune cerută | Director vechi din echipă poate scrie deconturile sale, contrar politicii director read-only |
| Fallback `driver` | `effectivePermissions=[]` blochează, dar **absența** câmpului reactivează permisii legacy | O migrare/ștergere de câmp poate reautoriza operații |
| `_expenseFromDoc` | `confirmed: d['confirmed'] != false` | Lipsa câmpului la documente vechi apare ca „confirmat”; necesită reconciliere, nu migrare oarbă |

Dovezile sunt teste sintetice în `tests/firestore/expense_security_characterization.test.cjs`. **`assertSucceeds` la un abuz demonstrează vulnerabilitatea**, nu siguranța. Un test static sau emulator nu certifică setul de rules efectiv publicat în Firebase.

## C. Matrice țintă — PROPUNERE, nu contract aprobat integral

| Operațiune | Autoritate de principiu | Limită obligatorie |
|---|---|---|
| Citire cheltuieli/decont echipă | Membru activ al echipei, Admin; director read-only pentru aria aprobată | Nu expune alte echipe unui simplu `viewOwnDecont` |
| Creare cheltuială OCR/manual | Membru activ autorizat pentru echipa proprie; Admin | Autorul real din `request.auth.uid`, echipă/decont real, sumă și tip valide; în mod normal neconfirmată |
| Corecție cheltuială înainte de confirmare | **DE DECIS exact**: autor, gestionar și/sau Admin | Fără schimbarea autorului/echipei/gestionarului/confirmării arbitrar; traseu de revizie justificată |
| Confirmare cheltuială | Gestionar curent autorizat sau Admin, nu `viewOwnDecont` generic | Verificare gestionar pe server și stare/decont; identitate și timestamp protejate |
| Corecție după confirmare | **DE DECIS** mecanism de rectificare; Admin pentru excepții justificate conform principiului de audit | Nu suprascrie retroactiv fără urmă sumele/confirmările originale |
| Schimbare gestionar (`managerId`) | Numai Admin pentru înlocuire anticipată aprobată; regularizarea inițială trebuie corelată cu desemnarea | Un gestionar principal, istoric și solduri păstrate, revocare promptă a fostului gestionar |
| `receivedDeparture` și alte predări | Gestionar/actor definit explicit **DE DETALIAT**, Admin în excepții | Sursa, sumă efectiv primită și audit, fără bani fictivi |
| Închidere/redeschidere decont | **DE DECIS** autorii și stările permise; excepții Admin auditate | Nu prin simpla vizualizare a decontului |
| Confirmare/refuz diurnă personală | Beneficiarul real, Admin doar pentru excepții deja definite | Avansul permis, confirmările vechi intacte, fără dublare |
| Schimbare echipă / funcție / suspendare | Admin / backend conform regulilor aprobate | Verifică apartenența actuală și drepturile la commit, fără acces prelungit prin cache sau fallback absent |

**Nu implementa automat această matrice:** trebuie confruntată cu fluxurile reale pentru `Home`, OCR, `perDiems` legacy, `settlements`, `finance` și gestionarii din `Team.financialManagerId`, `TeamFinance.managerId`, `TravelSettlement.managerId`.

## D. Contractul de câmpuri: pași obligatorii înaintea unui PR de fix

1. Inventariem **toate** scrierile pentru fiecare colecție și actor, inclusiv batch/transaction, offline, restore/backup, paginile Admin și fluxurile istorice. Nu folosim un `createdBy` fictiv în rules înainte să-l includă în mod sigur **toți** writerii aprobați.
2. Stabilim schema minimă: autor, `teamId`, `settlementId`, gestionar canonic, valori financiare validate, `confirmed`, revizie/timestamps și legătura la audit. Validăm tipurile numeric și limitele, inclusiv cazurile de retur/storno, fără a respinge avansurile legitime.
3. Facem diferența dintre **permisiuni explicit goale** și **câmp absent**: fallbackul legacy trebuie înghețat/restrâns într-o politică tranzitorie aprobată, nu extins implicit. Nu eliminăm compatibilitatea altor funcții fără inventar. Administrarea `effectivePermissions` rămâne separată de editarea profilului.
4. Documente financiare vechi fără `confirmed`: păstrăm citirea istorică, dar nu presupunem o stare contractuală nouă ori nu rescriem în masă documente. Inventar anonim în staging, apoi decizie de reconciliere/audit.
5. Desemnare gestionar: clarificăm sursa autoritară unică pentru fiecare acțiune între `Team`, `TeamFinance`, `TravelSettlement`. Schimbarea de gestionar este distinctă de confirmarea predării banilor. Tranzacții atomice/idempotente unde e posibil.
6. Definesc controale Firestore `affectedKeys().hasOnly(...)` și predicatul de tranziție per acțiune, nu un drept global `viewOwnDecont` pentru toate scrierile. Blocăm schimbarea `teamId`, identificatorilor și valorilor de către cititori.
7. Plan de compatibilitate: inventar numai în staging, dry-run, migrare controlată și reversibilă (unde e permis), etape de rollout + rollback. **Niciun update direct pe Firebase live fără mandat separat.**

## E. Teste / criterii RED → GREEN înainte de orice release

- Toate probele de abuz din PR #40 care acum fac `assertSucceeds` trebuie să devină `assertFails` **după fixul autorizat**. Păstrăm cazuri legitime `assertSucceeds` pentru fiecare actor/operator.
- Acoperire: Admin, gestionar vechi/nou, coleg, autor, beneficiar, director cu listă explicită, director legacy fără listă, developer, fost membru, cont dezactivat, outsider, client offline vechi și retry după revocare.
- Tranziții: neconfirmată→confirmată, refuz/reversare, corecție, decont open→closed, handover urgent fără banii predați, avansuri peste diurna datorată, conflict concurent de gestionar, schimbare echipă.
- Compatibilitate UI/Dart: salvare OCR reală pe flux `ExpensePage → Home`, date legacy fără `confirmed`, listări/query scopes, avertizări clare la `permission-denied`, fără duplicare de cheltuieli la reîncercare.
- Gate: toate testele financiare din emulator, contractele Python, identity A01–A12/C01–C08, Flutter și Android real în CI, review al diferențelor, staging cu conturi fictive, apoi test manual în scenariile reale autorizate. `SKIPPED` / hardware neexecutat nu devine `PASS`.
- **Nu se merge în main, nu se face deploy/publicare, nu se schimbă Firestore de producție din acest PR de caracterizare.**

## F. Decizii încă deschise pentru proprietar

1. Cine poate rectifica suma înainte de confirmare și cum se înregistrează rectificarea după confirmare?
2. Cine poate închide/redeschide un decont în regim normal și ce justificare/audit este obligatoriu?
3. Care e regula explicită pentru `confirmed` lipsă la documentele vechi, fără a inventa confirmări?
4. În desemnarea inițială a gestionarului, care este autoritatea canonică pentru echipă versus decont și cum păstrăm compatibilitatea celor trei surse actuale?
5. Politica sumelor nule/negative pentru chitanță, corecții și retur/storno (fără afectarea avansurilor de diurnă).

Acestea sunt **numai punctele încă nerezolvate**. Deciziile din secțiunea A rămân aprobate; nu se reiau.

## G. Separarea agenților și checkpoint

- **Luna PR #41 / Issue #39**: Vision/AuthGate, independent.
- **Shiva PR #40 / Issue #32**: doar teste de caracterizare și acest contract DRAFT.
- PR #38, #34, #35, #28, #29, #41, `main`, `firestore.rules` și Firebase producție sunt read-only.
- Niciun test nu utilizează utilizatori, bani ori documente reale. Rezultatul final se verifică **pe ultimul HEAD**, nu doar pe un commit anterior.


## H. Probe suplimentare de integritate financiară — 15.10.2026 (confirmate în emulator)

**Sursă și verdict:** PR #40, `a31824ff37bab292e416957a4b3ede8db53bf138`; workflow [finance-characterization #38667275432](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38667275432) **49 PASS / 0 FAIL**. Nouă teste de caracterizare (41–49) în `tests/firestore/expense_security_characterization.test.cjs`, fără date reale. Toate `assertSucceeds` denumite `unsafe` probează vulnerabilități; un test negativ probează o limită corect aplicată.

**Comportamente permisive demonstrate pentru membrul activ cu `viewOwnDecont` și apartenență la echipa documentului:**
- Poate înlocui `expenses.documentImageBase64`, `imageFingerprint` și `documentNumber` ale unei cheltuieli deja confirmate. Integritatea dovezii OCR nu este protejată de regulile actuale.
- Poate reasocia `expenses.settlementId` la un alt identificator (sintetic) și schimba `description` fără verificarea relației cu decontul.
- Poate introduce `confirmedBy`, `confirmedAt` și modifica `supplier` fără o listă permisă de câmpuri. **Nu pretindem că toate aceste câmpuri sunt afișate sau procesate de UI; proba este despre date acceptate la nivel de server.**
- Poate schimba `expenses.amount` în text nenumeric și poate CREA o cheltuială cu `amount` text după injectarea `distributedBy=auth.uid`. În `_expenseFromDoc`, valorile neconvertibile ajung în fallback numeric 0, risc de interpretare; nu echivalăm aceasta cu un bilanț alterat demonstrat în producție.
- Poate rescrie `finance.receivedEntries` și `perDiemRate`, precum și `settlements.receivedEntries` și `perDiemRate` într-un decont deja `closed=true`. Sumele sunt exclusiv sintetice; niciun ban real nu a fost atins.

**Permisiuni cumulative/director:** Un actor activ cu `role=member`, `function=director`, `effectivePermissions=['viewOtherDecont','viewOwnDecont']` și membru al echipei poate modifica `finance.receivedDeparture` din acea echipă. Cu simplul `viewOtherDecont` fără apartenență echipă, testele anterioare au demonstrat doar citire. **Precedența director read-only vs funcție operațională cumulată rămâne o decizie explicită a proprietarului**, nu o schimbare implicită la reguli.

**Control pozitiv al restricției existente:** Simpla valoare `finance.managerId=uid` nu conferă drept de write unui membru cu `effectivePermissions=[]`, chiar dacă aparține echipei. Viitorul fix trebuie să păstreze revocarea, dar să introducă permisiune contextuală explicită de gestionar, nu să folosească `viewOwnDecont` drept autorizație globală.

### Invariante propuse pentru viitoarea remediere (NEAPROBATE)
1. **Document OCR:** `documentImageBase64`, `imageFingerprint`, `documentNumber`, `teamId`, `settlementId`, autorul și starea de confirmare nu se pot schimba fără un flux explicit de rectificare și audit. Trebuie decis separat cine poate rectifica înainte de confirmare și cum se corectează după aceasta. Nu scriem unilateral aceste reguli.
2. **Schema sumelor:** tip numeric, valoare și interval validat în contextul operației; sumele negative sunt permise doar în fluxul de storno/retur dacă este definit și aprobat. Nu confunda cheltuielile cu diurna acordată în avans.
3. **Predări/încasări:** `receivedEntries`, `receivedDeparture`, `receivedDuring`, `perDiemRate` și `closed` cer matrice separată de scriere, identitatea gestionarului canonic protejată, tranziții auditate și eventual revizii/optimistic concurrency.
4. **Câmpuri suplimentare:** validați `keys().hasOnly` la create și `diff().affectedKeys().hasOnly` la update, însoțite de compatibilitate cu documente vechi și cu DTO real; nu ștergeți sau normalizați automat date istorice.
5. **Context director:** dreptul `viewOtherDecont` nu este echivalent cu `editOwnFinancialEntries`. Definiți explicit comportamentul unei persoane director+gestionar pentru propria echipă înainte de testele finale RED→DENY.

**Separare:** Acest document și testele nu sunt remedieri de producție. Corecțiile `firestore.rules`, fluxul `_money` din dialog și mutația locală `receivedEntries` înainte de eșecul salvării rămân lucrări distincte, în funcție de aprobările și acceptanța viitoare. Incidentul controller-used-after-dispose este documentat separat în PR #41 ca proba RED, nu tratat drept fix implementat. Nicio intervenție în Firebase live, PR #41, `main` ori APK.
