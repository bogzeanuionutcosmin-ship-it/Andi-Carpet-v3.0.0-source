# Rezultate financiare incerte — contract propus, NU implementat

PR #50 / Issue #48. Bază de audit: `c49c1f2765f3cb06e08adc46fe3b78c2982ff1b0`.
Acest document cere decizii separate înainte de implementare. Nu autorizează
retry, rollback, reconciliere, noi scrieri, scheme, roluri sau Firestore rules.

## Ce știm din sursă

- ExpensePage trimite un model mutabil prin `Future<void> saveSettlement` sau
  `saveFinance`. Home materializează payloadul înainte de await și face
  `.set(..., SetOptions(merge: true))`. Lista `receivedEntries` și agregatele sunt
  prezente în payload; nu există în aceste două adaptoare tranzacție, precondiție
  de revizie ori registru server al operațiunilor.
- `ReceivedMoneyEntry.id` și ID-ul unui decont nou sunt produse de `idNow()`
  (microsecunde ale ceasului local). Reintroducerea manuală este o operațiune nouă,
  fără legătură persistentă cu tentativa incertă. Nu confundăm această identitate
  cu idempotency sau cu garanție de unicitate între dispozitive.
- Garda `(epoch, teamId, settlementId)` este numai în State ExpensePage. Nu
  coordonează alt State, alt dispozitiv, Admin sau joburi server.
- Sincronizarea Home ascultă `snapshots()` fără includeMetadataChanges și fără
  evaluarea hasPendingWrites/fromCache. Un model primit de listener nu este
  dovadă că tentativa proprie a fost confirmată de server.
- Home pornește `_writeLearningEvent` după await-ul scrierii financiare. Auditul
  UI este ulterior întoarcerii callbackului. Acestea nu sunt un singur commit
  atomic și nu reprezintă confirmarea independentă a rezultatului financiar.
- Admin financiar afișează/șterge cheltuieli; nu are un handler nou de receipt
  sau close pentru settlements. Calea Admin care poate înlocui aceste documente
  este backup restore (manual/automat), prin delete și batch.set pe colecțiile
  allowlisted, inclusiv finance și settlements. Nu inventăm un writer Admin
  identic cu ExpensePage. Exportul este citire și nu rezolvă concurența.

## Ce NU afirmăm despre SDK

În lockfile: cloud_firestore 6.10.0. Nu există în cele două adaptoare un timeout
aplicativ nou; nici testele nu adaugă unul în aplicație. Lipsa conexiunii poate
lăsa scrieri în așteptare, nu produce obligatoriu o excepție imediată.

Documentația oficială descrie cache/offline, sincronizare la reconectare și
last-write-wins pentru documente, precum și metadatele pentru sursa observației:
https://firebase.google.com/docs/firestore/manage-data/enable-offline

Tranzacțiile pot relua funcția la concurență și eșuează offline:
https://firebase.google.com/docs/firestore/manage-data/transactions

Folosim aceste limite ca motiv pentru probe adverse. Nu deducem din ele că orice
cod FirebaseException este cert înainte sau după commit. Nici timeoutul unui
wrapper și nici logoutul nu dovedesc anularea cererii deja expediate.
Nu s-a accesat Firebase live, cache SDK real sau un dispozitiv fizic.

## Probe deterministe și limitele lor

`finance_uncertain_outcome_test.dart`: 19 probe cu handleri ExpensePage reali.
`finance_other_writer_uncertainty_test.dart`: încă 9 probe, inclusiv Admin restore
real prin porturile existente. Fake-urile capturează la invocare, separă commitul
de ack și nu citesc obiectul mutat ulterior. Datele sunt sintetice. Proiecția
financiară acoperă câmpurile observate; NU este o copie a codec-ului Firestore.

| Situație | Observație verificată / criteriu | Clasificare |
|---|---|---|
| Pending fără ack timp de 30s | un singur apel; zero audit și zero eroare fabricată | control al limitei |
| Commit + ack normal | un apel; un audit UI | control pozitiv |
| Timeout fără commit | memoria poate păstra tentativa nesalvată | KNOWN UNSAFE, nereconciliat |
| Commit apoi timeout | durable poate conține tentativa; UI fără audit succes | KNOWN UNSAFE, nu no-write |
| Commit după timeout | completarea apelului nu dovedește anularea comenzii | caracterizare adversă |
| Reintroducere receipt după eroare | două ID-uri, două sume pentru aceeași intenție | KNOWN UNSAFE |
| Prima tentativă fără commit, apoi reintroducere | a doua scriere poate include și prima mutație locală | KNOWN UNSAFE |
| Două instanțe, două receipts | ultimul payload poate pierde lista/totalul celuilalt | KNOWN UNSAFE |
| Editare cu/fără commit + timeout | starea locală identică poate ascunde rezultate durable diferite | KNOWN UNSAFE |
| Create comis apoi eroare, creare manuală nouă | două ID-uri de document pentru aceeași denumire/intenție | KNOWN UNSAFE |
| Close comis apoi timeout | closed local false vs durable true; endDate rămas | KNOWN UNSAFE |
| Admin restore vs receipt în curs | ambele comenzi pot continua; rezultatul depinde de ordine | KNOWN UNSAFE |
| Commit vechi după A→B→A2 | serverul poate fi modificat; zero UI/audit/telemetrie veche în succesor | sesiune UI protejată, nu server anulat |

PASS al unui detector KNOWN UNSAFE confirmă reproducerea riscului. Nu este
acceptanță financiară. Cele 28 de probe nu sunt 28 verificări server sau plăți.
Rezultatele efective CI sunt consemnate pe HEAD în PR #50, nu anticipate aici.

## Contract candidat pentru aprobare separată

Propunerea separă `pending`, `confirmed`, `rejectedBeforeWrite`, `uncertain` și
`conflict`. Tranzițiile nu sunt implementate în acest PR.

1. La confirmarea utilizatorului se definește o intenție stabilă, legată de
   UID + epoch + echipă + decont + tip + revizie de bază. Identitatea se păstrează
   la verificare/reluare; nu se folosește suma/denumirea drept cheie de deduplicare
   deoarece două încasări legitime egale trebuie să rămână posibile.
2. Snapshotul confirmat, candidatul în curs și observațiile server sunt distincte.
   Payloadul este capturat înainte de primul await. Nicio completare a sesiunii
   vechi nu mută state, audit sau diagnostic al succesorului.
3. `confirmed` cere rezultat legat de aceeași intenție și dovadă autorizată de
   commit. `rejectedBeforeWrite` cere garanție explicită a limitei înainte de
   persistență. Un catch generic nu clasifică. Cache-ul și lipsa unui document
   într-o observație stale nu sunt dovadă suficientă.
4. `uncertain` păstrează dovada intenției, fără nou write financiar/compensare
   automată și fără audit fals de succes. Textul UI propus ar explica incertitudinea;
   nu adăugăm acum acest flux sau un diagnostic document_missing.
5. O verificare viitoare trebuie să citească sursa server autorizat și să
   coreleze intenția/revizia. Lipsa conexiunii ori drepturilor păstrează incert.
   Simpla egalitate a valorilor nu dovedește cine a scris sau dacă alte operații
   au fost suprascrise. Nu este suficient `waitForPendingWrites` global pentru
   identificarea unei intenții sau pentru confirmarea tuturor side effects.
6. Două intenții distincte pe aceeași revizie cer o politică de conflict; nu
   câștigă automat ultimul writer. Auditul unei eventuale decizii trebuie să fie
   minim, asociat intenției, fără UID/sume/OCR/payload în jurnalul Vision.
7. Admin restore necesită coordonare explicită cu scrierile operaționale și un
   plan de recuperare a importului parțial. Un lock doar în ExpensePage nu îl
   coordonează. Nu dezactivăm automat funcția sau schimbăm permisiunile.

## Alternative și decizii necesare

| Alternativă | Beneficiu | Cost / limită / decizie |
|---|---|---|
| Menținere comportament + procedură manuală verificată | nicio schemă nouă | riscurile de mai sus rămân; nu se declară sigur |
| Intenție + revizie tranzacțională în documentul existent | verifică concurența și poate evita repetarea aceleiași intenții | limită de dimensiune/istoric; tranzacții offline; trebuie proiectată autorizarea; toți writerii trebuie adaptați |
| Registru de operațiuni / ledger separat | identitate și dovadă durabilă pentru fiecare intenție | schemă, rules, retenție și citiri/scrieri noi; fără activare în mandatul actual |
| Backend autoritativ | coordonare centrală și audit atomic proiectabil | deployment, drepturi și evaluare cost; neautorizate acum |

Nu selectăm tacit o alternativă. Proprietarul trebuie să aprobe modelul intenției,
conflictele, drepturile de verificare, experiența offline, auditul/retenția și
coordonarea restore. Nu cerem aprobarea unei schimbări nedescrise.

## Acceptanță înaintea oricărei implementări viitoare

- Aceeași intenție retrimisă nu dublează încasarea; două intenții legitime egale
  rămân distincte; operația veche nu poate suprascrie o revizie nouă.
- Scenarii de succes, respingere certă, commit apoi eroare, timeout înainte/după
  commit, reconectare/restart, observații cached/pending/server, două dispozitive,
  Admin și logout/relogin A2; ordini adverse și controale pozitive.
- Un singur audit de succes legat de commit; zero confirmare inventată și zero
  date private în Vision. Eșecul auditului nu provoacă reexecutarea sumei.
- Schemele perDiems și per_diem_settlements_v2 rămân distincte; avansul permis
  și valorile istorice nu se modifică. Nu transformăm aggregate legacy în
  transferuri inventate.
- Emulator pentru atomicitate/autorizare și teste SDK/cache pe platformele țintă,
  apoi staging numai cu autorizare. Probele de port nu înlocuiesc aceste etape.
