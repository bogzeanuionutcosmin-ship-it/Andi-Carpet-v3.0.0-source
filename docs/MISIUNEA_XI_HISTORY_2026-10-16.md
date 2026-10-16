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
