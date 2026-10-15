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
