# Protecții backup/migrare — propunere pentru un PR funcțional ulterior

Document de recomandări, nu autorizare sau implementare. Probe sintetice din MISIUNE_EXTINSA_III_2026-10-14.md; runtime #28 păstrează comportamentul original. Datele de producție nu au fost accesate.

## Riscuri demonstrate și criterii propuse

| Risc | Protecție de proiectat | Dovadă de acceptanță viitoare |
|---|---|---|
| Future badge schema intră în migrare destructivă | Fail-closed pentru versiuni necunoscute/downgrade; identificarea exactă a schemelor eligibile | Zero delete/reset la future schema; old/new fixtures și emulator |
| Două migrări pe metadata veche execută aceleași comenzi | Identitate operație și idempotency server, cu lease/transaction potrivită limitelor; nu doar flag local | Două dispozitive, un singur rezultat, fără golirea funcțiilor valide |
| Deletes confirmate înainte de failure fără marker | Plan validat integral; marker după confirmed commit; recovery/compensation explicită | Failure înainte/după fiecare batch, timeout și răspuns ambiguu, fără pretenție de atomicitate multiplă |
| Restore manual unknown-only marchează succes | Preflight operațional semnificativ, schemă/version/allowlist și rezumat explicabil | Unknown/empty/snapshot parțial nu devin succes fals; zero comenzi înainte de accept |
| Restore concurent și continuare după page dispose | Ownership/generație la fiecare await și identitate stabilă a operației; politică explicită pentru operațiile deja aprobate | Zero comandă nouă din owner expirat; duplicate clicks/idempotency; nu se anulează fictiv un commit confirmat |
| JSON/parent/items failure scapă din try | Boundary complet de tratare a erorilor, status neambiguu și retry manual sigur | Fișier malformed/read timeout/offline la fiecare await; zero false success/duplicate writes |
| Ștergere urmată de insert parțial | Mecanism recovery verificabil; eventual staged replacement/compensation numai după proiectare | Store durabil/emulator, snapshot complet/parțial, eșecuri și concurență; continuitatea finanțelor și istoricului |

## Decizii care nu se iau tacit

Nu inventăm rollback automat, dry-run UX, marker nou, schema nouă, server rules, migrare producție sau resetări de drepturi. Restore accept este acum destructiv pentru grupurile prezente; anularea înainte de accept nu este rollback. Recuperarea trebuie să respecte drepturile, datele financiare/diurne/săli și auditul obligatoriu; jurnalul diagnostic și cache-ul regenerabil sunt distincte de operațiile offline nesincronizate.

Fixul se face pe ramură/PR separat după autorizare, cu teste RED→GREEN și CI. Emulatorul demo este necesar pentru autorizare/idempotency/ambiguitate de commit; fake store-ul actual modelează respingere înainte de aplicarea batchului și nu certifică Firestore SDK/cache sau server evidence.
