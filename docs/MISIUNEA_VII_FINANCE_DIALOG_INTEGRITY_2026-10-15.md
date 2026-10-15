# MISIUNEA VII — Issue #48, Draft / DO NOT MERGE

## VII-01: intrare și matrice de acceptanță
Bază exactă PR46: 736ef9ea66bec5ff0c431d05808e43423c1f3ba9, tree 4221469b6ea94ef26a46706d9f8b129429188f38. Ramură nouă, PR-urile existente intacte. PR40 c010e23, PR41 b0f8687, PR44 0c8f813, PR45 da922ef citite. Niciun fișier runtime modificat în preflight.

| Flux real | Controller / stare | Persistență | Martor înainte de fix |
|---|---|---|---|
| _createSettlement | nameC, start/end locale, apoi selectedSettlementId | saveSettlement(result) | create cancel RED #46; zero saves/audit |
| _editSettlement | nameC, mutație shared name/startDate/endDate | saveSettlement(s), audit după await | rejet RED #46; succes pozitiv existent |
| _toggleSettlementClosed | closed/endDate shared, catch reface doar closed | saveSettlement(s) | close endDate RED portat selectiv #44 |
| _money | amountC/fromC, receivedEntries/departure/during shared | saveSettlement sau saveFinance | controller RED #41; NaN RED portat selectiv #45 |

HomeFinancialWriteActions serializează obiectul prin set(merge:true). Callback Future<void> nu clasifică certitudinea eșecului: excepția nu dovedește inexistența scrierii. Fără retry, rollback server sau confirmări inventate. Semantica avansului diurnei (poate depăși acumulatul), perDiems/per_diem_settlements_v2, OCR, roluri și rules rămân intacte.

### Freeze înainte de primul diff
Sursa settlement SHA256 13a2dd2aaa9b50ef8172ca1ebc5468bb4cf286b9a454385936ca67f0c017ba33. 116 protected hashes plus 21 VI freeze checks; numai hashurile unui fișier explicit reparat pot fi actualizate, cu valori old/new și motiv. Testele originale #41/#44/#45/#46 și ramurile lor nu se modifică. Probe noi rulează explicit în workflowul acestei ramuri; SUCCESS al detectorului RED nu este remediere.

### Stare
VII-01: matrice statică pregătită; reproducere independentă în CI în așteptare. VII-02–12: neexecutate. Hardware/SDK/Firebase live NEEXECUTATE. Flutter absent local; CI este executorul testelor Flutter. Fără merge/deploy/publicare/rules/producție/servicii plătite. Issue47 exclus.

## VII-02: controller ownership — implementare în verificare
Baseline 5250918: workflow38685978298 SUCCESS ca detector, cele cinci defecte specifice reproduse, control pozitiv PASS; identity38685978321 SUCCESS. Prima încercare de workflow a fost anulată din cauza concurrency comun cu workflowul istoric; grupul propriu a reparat exclusiv schedulingul.

FinanceDialogFields (bibliotecă Flutter independentă, import main) creează controllere în State și le dispose numai la unmount. Create/edit/money transferate; edit capturează text înainte de pop. Datepicker callbacks cer context mounted. Închiderea cere ruta curentă pentru a ignora al doilea tap în reverse transition. Nicio schimbare de save/mutații/sume în acest lot. 22 probe lifecycle noi, inclusiv dovadă explicită controller viu în tranziție și disposed după unmount. Testele #41/#46 au aceleași aserțiuni; poarta proprie cere acum exit0 pentru cele două lifecycle witnesses, nu exit1. Edit/close/NaN rămân expected RED, fără mascare.

Hash settlement old13a2dd2aaa9b50ef8172ca1ebc5468bb4cf286b9a454385936ca67f0c017ba33 → new88b39531c23bf7d23b6b39a98e939e6f7d663f786130ef344907197998cdc43f. Actualizat strict entryul acestui fișier din freeze VI și pinul fără hook din inversion; OCR/per-diem/Home/AuthGate/116hashuri păstrate. CI Flutter în așteptare; fără revendicare de remediere verificată până la GREEN.

## VII-03: validare numerică minimală
VII-02 ea70d4494e9da8b92e9b6eb8c2a96429a55363f9 validat: standard38686340436 SUCCESS5/5, identity38686340354 SUCCESS, probe38686340372 SUCCESS:24PASS lifecycle (22noi+2martori originali), control pozitivPASS, edit/close/NaN încăRED la acelHEAD.

Singura schimbare runtime VII-03: `!amount.isFinite` după tryParse. Zero/negativ/gol/invalid/nume gol rămân respinse; 200/200.00/200,00/0.01 și123.456 păstrează valoarea exactă a parserului. Nu introducem rotunjire sau plafon nou; precizia peste2zecimale rămâne regula existentă, nu o decizie nouă. OCR și istoricul nemodificate. 26probe noi (22settlement+4legacy), fixture opțional legacy/saveFinance cu fallbackurile originale. ProbaNaN portată din#45 cere acum PASS real, fără schimbarea aserțiunilor.

Hash settlement 88b39531c23bf7d23b6b39a98e939e6f7d663f786130ef344907197998cdc43f → 3c8931aff9b31830670d2ad72f8fc3aba37cf2798e46dee5042e3a49a6028681; aceleași două pinuri specifice actualizate,116hashuri protejate intacte. CI pe noulHEAD în așteptare.

## VII-06/07/08: completări întârziate, observabilitate și probă local-state separată
VII-03 HEAD4bda3851a55a049e7a8e72b06a3546ed48c4d4e9: standard38686620462 SUCCESS5/5, identity38686620461 SUCCESS, probe38686620453 SUCCESS. ProbeleNaN și lifecycle sunt acumPASS real; edit/close încăRED.

ExpensePage păstrează un epoch local schimbat la UID nou. Fiecare acțiune settlement capturează epoch+UID+callbackul de sesiune original; verifică înainte de save și după await înainte de audit/UI/telemetrie. Nu anulăm scrierea server deja pornită și nu facem retry. AuthGate/Home/rules nemodificate. 20probe UI cu State reutilizat deliberat: create/edit/close/money/legacy-money ×success/failure×A→B/A→B→A2. Aserțiunea identity(State) exclude un PASS obținut doar prin unmount.

3probe observabilitate: success0/failure1/revoked0 evenimente, exact1save și fără payload PRIVATE/valoare în Vision. 1probă director read-only: zero acțiuni settlement și zero writes. Acestea nu validează ACL server.

Nou martor explicit `finance_received_state.red.dart`: save fake respins înainte de commit, zero audit și zero erori Flutter înainte de aserțiunea local-state. Dacă starea rămâne modificată, markerulRECEIPT_CONFIRMED_LOCAL_STATE_NOT_PRESERVED rămâneRED, separat de controllerul reparat.

**Limite financiare VII-04/05/06:** callbackurile curente Future<void> nu disting reject sigur de possible-write-then-throw/timeout. Păstrăm martorii edit/close și caracterizăm receipt; nu introducem rollback/retry server sau false certitudini. Implementarea care tratează commit incert rămâneBLOCKED pentru review separat conformIssue48; reparația pe eșec cert necesită un contract de rezultat explicit, fără clasificarea arbitrară a tuturor excepțiilor drept no-write. Nu declarăm aceste3defecte reparate.

**Limită VIII:** testele certifică ExpensePage și callbackurile sale simulate. `_saveSettlementDirect`/`_saveFinanceDirect` declanșează dupăwrite un Learning event în Home; `_writeLearningEvent` nu are verificare explicită de epoch în această sursă. Nu revendicăm zero backend learning-event dupălogout. Home/Learning nu este modificat aici (cooperareIssue47); necesită coordonare și probe SDK separate.

### VII-09: diferențial de securitate față dePR40/Issue32 (read-only)
`firestore.rules` este byte-identic PR40 c010e23 și această ramură: SHA256589fe5eadc06cae665eaa27e9c9df0aea54eea6dffc10994438b4d97c58367da. WorkflowPR40 38671992447/job116217019279 reverificatSUCCESS. Nu rerulăm sau importăm59probe istorice și nu le raportăm drept59teste noi pe acestHEAD.

| Caz caracterizatPR40 | Stare server din repo | Delta misiuneaVII |
|---|---|---|
| OCR legitimate create fără distributedBy | respingere caracterizată | nicio remediere ACL |
| unauthorized amount/confirmed spoof | KNOWN UNSAFE, update permis în emulator | UI finite nu reparăACL |
| finance.managerId | KNOWN UNSAFE pentru membruviewOwnDecont | nicio schimbare |
| reopening settlement | KNOWN UNSAFE în aceleași limite | nicio schimbare |
| outsider/cross-team | controaleDENYPR40, nu garanție exhaustivă | rules neschimbate |
| legacy director permissions | KNOWN UNSAFE fallback | noultestUIread-only nu schimbă backend |

Avansul și schemeleperDiems/per_diem_settlements_v2 neschimbate. TesteleabuzassertSucceeds rămân dovezi de vulnerabilitate, nu acceptanțăsecuritate.

Pin autorizat VII-08 `lib/expenses/expense_page.dart`: 6c948fe71f19246a3c71bd2d2a20ac963bdf0b783f694a14ef81ed73f1ff71d3 → efd42ce1c1944bcf0288aea6ec54d2d9448ecf36dbba833454c8c43603cce01c.

Pin autorizat VII-08 `lib/expenses/expense_settlement_actions.dart`: 3c8931aff9b31830670d2ad72f8fc3aba37cf2798e46dee5042e3a49a6028681 → 3976d0bb5e0eef4c1c54d44443deade6938e6d6498293999e9dab0ad00b459f3.
