# XI — propunere de integrare, NEAPLICATĂ

Nu este mandat de modificare pentru main.dart/Home/AuthGate/hashuri/rules live.
Patchul Home X cu flag FALSE rămâne neaplicat. Contractul XI este numai candidat
receipt append-only, nu poate înlocui mecanic callbacks care salvează modele.

Diff conceptual pentru punctul de rutare (NU cod executabil sau aplicat):

```diff
- saveSettlement: _saveSettlementDirect, saveFinance: _saveFinanceDirect
+ // NUMAI după mandat distinct și toate gate-urile de mai jos:
+ // feature flag implicit FALSE; protocol selectat autoritativ per source.
+ // Receipt V2 → v2 versioned journal → append-only repository → marker/refresh.
+ // manager/rate/bootstrap/expense/perDiems → contracte distincte aprobate.
+ // Niciun fallback automat spre set(merge:true) când V2 e incert/conflict.
```

Gate înainte de orice implementare în fișiere protejate:

1. Alegere server-side exclusivă protocolV1/V2 per source; niciun interval în care
   două scheme independente pot contabiliza aceeași intenție. Main admin catch-all
   exclus nominal din noul namespace. Teste old/new APK pe aceleași sources.
2. Contract de migrare explicită: snapshot vechi, opening amounts verificabile,
   receipt IDs, marker/source version, conteazătoți writerii și retryurile. Candidatul
   XI refuză nonzero legacy; NU conține backfill/import sau script de activare.
3. Jurnal V2 separat de V1, envelope protocol-bound, persist-before-send,
   exclusivitate RMW pe toate taburile/procesele cooperante, fail-closed fără lease.
   Intențiile V1 pending nu sunt decodate sau retrimise drept V2.
4. Model UI înlocuit autoritativ numai după dovada aceleiași intenții. Pagini pinned
   incomplete rămân incomplete; un timeout nu este refuz/rollback. Dovada snapshotului
   trebuie să trateze exact aritmetica monetară și limitele double înainte de release.
5. Factory pe UID+AuthGate generation+echipă, dispose sincron înainte de sesiune nouă,
   inclusiv A→B→A2 și team transfer. Confirmarea financiară nu vine din Vision.
6. Export bounded cu prefix pinned și receipts/markeri compleți pentru fiecare source;
   inventar global și coordonarea importului autorizate separat. Nicio ștergere pending.
7. Mapping Vision numai enum anonim: operationUncertain → financeOperationUncertain;
   revisionConflict → financeRevisionConflict. Fără UID/amount/digest/revision/payload.
   Sinkul revocat sau defect nu schimbă rezultatul și nu reexecută operația.
8. Staging separat, probe native secure-storage/cross-process/OS crash și consum real,
   apoi review nominal deprotejare, upgrade gate, migrare, rules și rollout aprobate.

Rollback după activare nu poate însemna revenirirea la rules permisive sau writerul
legacy peste sources deja V2. Se păstrează markerii și jurnalul, se opresc operațiile
noi și se reconciliază manual aceeași intenție. Nu se șterg bani/istoric sau markeri.

Toate aceste treceri rămân neexecutate. production_ready=false.
