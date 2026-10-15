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
