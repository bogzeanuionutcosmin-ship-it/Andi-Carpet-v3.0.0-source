# Creare/editare decont — caracterizare separată, fără remediere runtime

Bază verificată: PR41 HEAD b0f8687862e005097889b495c0da8d40f8547431,
tree88970f32a604aa3c7a5cd8aaf9d0be39a744470e. Ramură nouă
`test/settlement-create-edit-characterization-20261015`, PR Draft TEST ONLY.
Baza main este numai pentru CI. PR41 și PR44 rămân nemodificate.

## Scop și proveniență

Continuare solicitată din HEAD. Issue42/43 și comentariile Shiva identifică două
riscuri statice încă neconfirmate: lifecycle `_createSettlement` și mutațiile
`_editSettlement` înainte de save. Nu repetăm Misiunile III–VI sau proba endDate
la închidere din PR44 (0c8f81337f41d03be470eedcb84034f498e0f750).

Folosim ExpenseDocumentFixture existentă și ExpensePage reală; niciun algoritm
financiar nu este copiat în fixture. Trei probe pregătite:

- Control pozitiv normal: editare nume/ștergere final, un save confirmat, un audit.
- RED strict: aceeași editare și save fals respins; starea locală trebuie să fie
  cea inițială. Gate-ul save este ținut până dispare ruta, pentru a separa
  rollbackul de defectul controllerului. Verificăm lipsa oricărei erori Flutter,
  o singură încercare și zero audit înainte de aserțiunea de rollback.
- RED strict: dialog nou → Anulează, zero save/audit și zero erori de controller
  în timpul tranziției. Proba nu modifică sume sau date reale.

RED-urile au entrypointuri explicite `.red.dart`, în procese CI independente,
cu exit1 și markeri specifici obligatorii. Compile errors, precondiții eșuate sau
un RED devenit verde fac wrapperul FAIL. GREEN al wrapperului nu înseamnă UI reparat.
Proba originală financiară VI și toate contractele/hashurile rămân nemodificate.

## Limite

Nu prescriem rollback automat pentru commit Firestore incert, retry, idempotency
ori schimbare de roluri/sume/confirmări. Fake failure nu este dovadă server-side.
Issue32/PR40 rămân distincte. Fără lib/runtime/rules/dependențe/config/assets diff,
merge, deploy, APK/web publication sau Firebase producție.

Flutter lipsește local; rezultate dinamice încă NEVERIFICATE până la CI.
Standard și identity obligatorii; workflow separat pentru cele trei probe.
Android integrat este SKIPPED pe această ramură de teste; runtime identic cu baza
PR41, unde compilarea lib/main.dart este deja verificată. Hardware NEEXECUTAT.
Rezultatele finale, HEAD/tree și etapa de reluare se consemnează în PR după CI.

## Dovezi dinamice confirmate, 15.10.2026

PR46, commit ee7ab66913ad584a6a2db91c117ec2c8754ae0c9,
tree3f5876021e6ca2ed141ee7121e907f9f3acdf1e6. Merge-ref62c12e9 are același
tree (git fetch verificat). [Probe izolate38682160481](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/38682160481)
SUCCESS ca detector al celor două RED-uri; control pozitiv1PASS. Logurile sunt
verificate, nu deduse din statusul verde al workflowului.

- Editare: precondițiiPASS, o singură salvare falsă respinsă, niciun audit și
  zero erori Flutter înainte de aserțiunea finală. Expected name='Synthetic Trip',
  endDate=2026-10-09; actual name='Synthetic revised trip', endDate=null.
  Marker SETTLEMENT_EDIT_LOCAL_STATE_NOT_RESTORED, +0 -1 Some tests failed.
  Sunt confirmate numele și endDate; startDate nu a fost modificat în această
  probă, deci mutația sa după failure rămâne numai revizuire de sursă.
- Creare→Anulează: zero save/audit, CREATE_CANCEL_PRECONDITIONS_PASS, apoi
  controller-used-after-dispose și CREATE_DIALOG_CANCEL_LIFECYCLE_BROKEN,
  Expected:null / Actual:multiple exceptions. Defect lifecycle confirmat chiar
  fără încercarea unei scrieri financiare. Nu am certificat Back/barrier/logout.
- Control pozitiv: un save fals returnează succes după terminarea tranziției;
  modificările rămân și se generează exact un audit. Nu este Firebase live.

Identity38682160404 SUCCESS5;171Python local PASS și contractele CI PASS.
Standard38682160388 era încă în execuție la salvarea acestui checkpoint. Ultimul
HEAD documentar este verificat separat, iar run IDs/SHA/tree finale sunt în PR46.
Android SKIPPED deliberat; nu revendicăm build nou sau hardware PASS.

## Izolare și reluare

PR41 b0f8687, PR44 0c8f813 și PR45 (probe NaN) sunt surse independente, read-only.
Nu importăm testele lor și nu le schimbăm ramurile. Scope-ul acestui PR este exact
cele trei probe, helperul lor, workflowul nou și documentația:7fișiere față de baza41.
Toate fișierele runtime, testele și hashurile de freeze originale sunt nemodificate.

REIA din HEAD-ul final din PR46 numai pentru eventuale probe suplimentare aprobate.
Nu repeta MisiuneaVI, endDate la închidere din PR44 sau probele create/edit confirmate
aici. Remedierea lifecycle-ului și orice rollback/retry/state financiar se separă
într-un mandat explicit, cu review al contractelor înghețate și probe RED→GREEN;
nu slăbi aserțiunile pentru a obține verde. Nu există remediere runtime în acest PR.
