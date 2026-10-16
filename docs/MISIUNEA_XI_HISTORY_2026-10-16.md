# Misiunea XI — append-only candidate / DRAFT ONLY

Issue #79. Bază PR78 reală 291b10ac74d1c0f58d3e44416cf2f48ef8dc347b,
tree d7cbee9e3af6dfe84b8ace251feeb8a9d4d5a77a, checkout curat.
CI bază: Standard38878283734/Identity38878283790/Finance38878283763/
Platforms38878283794 SUCCESS. Nu sunt rezultatele XI.
Ramură nouă fix/finance-history-legacy-safety-mission-xi-20261016.
PR75 observat read-only 48235b14fa7345c454882960aecb0ba66ba1b596;
PR78/75/73/74/main rămân nemodificate. production_ready=false.

## XI-01 — capacitate adversarială

Testele noi măsoară exact numărul octeților UTF8 ai canonicalFinanceJson pe
1000/7300/21900 receipts sintetice și payer ASCII vs Unicode. Dimensiunea după
formula Firestore existentă este etichetată separat: NU este dimensiune wire,
index sau factură măsurată. Două timestamps diferite cu o nanosecundă rămân
JSON distincte, dar au aceeași dimensiune de stocare Firestore (8 bytes/valoare).
Scenariul X 20 receipts/zi × 1KiB +4KiB reproduce 25 zile complete în rezerva
512KiB; ipoteza 1KiB nu înlocuiește măsurarea payloadurilor concrete.
Nu se trunchiază istoric și nu se modifică bani, Home sau vreun pin.

## XI-02 — contract V2 candidat, independent

Namespace demo financeHistoryXi/s_<settlementId> sau f_<teamId>. Summary mic:
protocol2/team/source/revision/totals/lastOperationId. receipts/<operationId>
este simultan rând append-only ȘI markerul imuabil de idempotency (digest V2,
actor, team, target, base/revision, payload). Două writes atomice, fără array,
fără colecție marker duplicată. Nu conectăm Home sau jurnalul V1 la V2.
Envelope protocol2 are digest separat de FinanceIntent V1; nu se importă pending
vechi. Factory SDK este exclusiv demo/loopback. Inițializarea refuză surse legacy
cu bani/istoric/revizie nenulă; bootstrap sintetic zero nu este migrare.

Model/port independente și probe fake: replay, intenții egale distincte,
concurență CAS, ack pierdut și reconcilere explicită, lipsă/conflict marker,
revocare monotonă și consistență completă pe pagini pinned. Sumarul nu este
certificat printr-o pagină parțială. Reordonarea sau diferențele de aritmetică
floating la suma inversă refuză dovada; nu rotunjim bani pentru un PASS.
Rules noi sunt exclusiv fixture emulator separată. Nicio regulă live sau
firestore.rules existent nu este modificat. Validarea CI urmează pe SHA nou.
