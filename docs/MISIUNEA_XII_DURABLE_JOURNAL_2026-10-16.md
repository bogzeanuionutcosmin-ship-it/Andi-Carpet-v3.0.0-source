# XII — Durable Financial Journal & Cross-Process Safety

Candidat izolat, `production_ready=false`. Nicio activare în main/Home/AuthGate.
Bază exclusivă PR80: `81e81f2bb6c066d2fa2e1a9a5ebe41c715b7a920`, tree
`2be59f1b2d5b648ff98148c0f3ae9c89ce79eadd`. HEAD reconfirmat prin API înainte
să creăm `fix/durable-journal-mission-xii-20261016`. PR Draft separat #83.

## Închiderea verificării XI, fără merge

Cele patru workflowuri active au fost recitite pe exact HEAD-ul PR80, toate
SUCCESS: Standard38890474083 (5/5), Identity38890474075,
Finance38890474142 (3/3), Platforms38890474113. Șase workflowuri istorice SKIPPED
condiționat, nu PASS. Dovezile XI:834Flutter/199Python/3Node standard,
230Dart/77JSemulator/21FlutterSDK, 161AuthVision/412VM/398Chrome și Android
compile-only. Aceste rezultate închid verificările tehnice ale candidatului XI,
NU blocajele sale de lansare și NU se reutilizează drept verde pentru XII.

Surse consultate: ChatGpt, registrul regulilor, arhitectura Vision zero-cost,
rapoartele X/XI, rollout proposal XI, codul checked journal V1, witnessul XI de
lost update, repository append-only, fixture-urile și workflowurile existente.
PR80 și ramurile existente rămân read-only; PR82/Shiva nu sunt modificate.

## Contractul candidatului

Implementarea browser este un ES module în
`lib/finance/journal_v2/browser_journal_v2.mjs`; portul și coordonatorul Dart sunt
în același director. Hostul trebuie să servească explicit modulul și să instaleze
`globalThis.andiCreateFinanceJournalV2 = createJournalV2` înainte de factory.
Aplicația existentă nu îl încarcă; asset packaging/CSP de producție nu sunt gata.
Testele îl servesc numai loopback. Nu s-a editat pubspec sau adăugat plugin.

Domeniul fix al stocării:
- IndexedDB `andi-finance-history-v2`, object store `journals`, schema1;
- key JSON `['history-xi',2,ownerUid,teamId]`;
- Web Lock `andi-finance-history-v2/journals/` + aceeași key;
- envelope `AndiFinanceHistoryJournalV2`, protocol2, UID, team, revizie monotonă,
  lista raw+digest și checksum SHA256 al envelope-ului fără checksum.

Key/lock nu pot fi înlocuite prin opțiuni de constructor. UID+team au validarea
existentă:1..128 caractere, fără slash. Cheile V1 nu sunt citite, resetate,
convertite sau șterse. Intenția este exact stringul `HistoryXiIntent.encode()`;
SHA256 se calculează pe aceiași octeți UTF8. Payloadul financiar nu este
reserializat în JS și nu se rotunjesc sume sau nanosecunde. JS verifică schema
receipt/protocol, binding, ID, revizie sigură, bani finiți pozitivi și timestamp
exact. Portul Dart verifică suplimentar `decode(raw).encode()==raw` la recuperare.

Envelope-ul întreg este validat la fiecare acces, inclusiv toate digesturile,
IDs și targets unice, UID/team/protocol/revizie/checksum. Corupția rămâne pe
storage și blochează operațiile; nu avem fallback către listă goală. Limite:
32 intenții,128KiB envelope UTF8,16KiB/intenție; limite de spațiu, nu bani.
Nicio evacuare pending, TTL, deleteAll, migrare, import sau API de restore.

## Exclusivitate și argumentul de siguranță

Fiecare `pending`, `prepare` și `confirm` solicită același Web Lock exclusiv cu
`ifAvailable:true`. Fără lock/API/context secure/IndexedDB/crypto, operația este
refuzată. Nu există `_queues` static ca substitut cross-process, timeout care
continuă fără lock, `steal`, localStorage lease sau retry financiar automat.
Contenția produce `journal_v2_busy`; apelantul poate relua explicit operația
locală după blocaj, fără să inventeze autorizare de trimitere.

Callbackul deține lockul până după întreaga secvență:
read → validate/checksums → compare/modify → checksum → write transaction STRICT
→ `transaction.oncomplete` → readback exact → guard sesiune. `put.onsuccess` nu
este barieră de commit. Dacă `tx.durability !== 'strict'`, abortăm; fără fallback
`default` sau `relaxed`. O mutație înlocuiește atomic UN envelope IndexedDB.
Conexiunea este închisă în finally; versionchange o închide, nu șterge datele.

Pentru doi writeri cooperanți din același storage bucket, B fie este refuzat cât
A deține lockul, fie citește starea după commitul lui A. B nu poate valida un
snapshot anterior lui A și apoi suprascrie envelope-ul nou. Revizia/checksumul
servesc integritatea, nu sunt prezentate ca lock/CAS sau protecție anti-rollback.
Confirmarea elimină numai raw+digest identice și păstrează toate celelalte
intenții din snapshotul citit sub același lock. Reconcilierea/network I/O NU ține
lockul: astfel un ACK pierdut sau Firestore offline nu blochează toate targets.

Scope-ul Web Locks este cooperant și comun cu IndexedDB: aceeași origine,
partition/storage bucket/profil/browser. Alte profile/dispozitive au jurnale
independente și se coordonează prin CAS+receipt server XI, nu prin Web Locks.
Codul legacy sau XSS care scrie direct în DB fără lock nu este protejat de
acest protocol. Nu pretindem sincronizare universală de procese arbitrare.

## Persist-before-send, incertitudine, crash și sesiuni

`prepare` acordă autorizare de send numai după commit+readback și numai pentru o
intenție NOUĂ. Același ID/raw deja pending întoarce false; ID cu alt payload sau
alt ID pe același target este refuzat. Coordonatorul nu retrimite intenția găsită:
întoarce uncertain/reconcile-required. Constructorii, pending/restart/login nu
execută tranzacții financiare. Nicio rebase sau intenție nouă automată.

Chiar eșecul prepare este UNCERTAIN la nivelul intenției: apelul curent nu a
trimis nimic, dar alt context poate avea deja același ID pending/comis. Nu îl
etichetăm global rejectedBeforeWrite doar pentru că lockul sau storage a eșuat.
Refuzul cert primit din repository după un prepare nou rămâne rezultatul său,
dar intenția se păstrează conservator pentru review. Nu există dismiss/cancel
neprobat; această alegere sacrifică liveness și poate umple jurnalul.

`reconcileExplicitly` cere întâi exact intenția locală și apoi repository XI
citește receipt+summary autoritativ (`Source.server`, fără cache/pending),
verifică raw-derived digest/payload/binding și revizia. Marker lipsă, cached,
mismatch sau eroare păstrează intenția; suma egală nu este dovadă. Numai confirmed
autoritativ permite `confirm` local. Eșecul cleanup păstrează confirmed financiar
și `journalPending=true`, fără o nouă tranzacție. `confirm` este port intern de
încredere, nu mecanism de autorizare împotriva unui script malițios same-origin.

Crash înainte de commit: tranzacția atomică păstrează envelope-ul anterior;
nu există send autorizat. Crash după commit înainte de return/send: intenția
persistă, recuperarea nu o trimite singură. Server commit cu ACK pierdut:
intenția persistă și se reconciliază cu același ID; zero tranzacții financiare noi.
Crash în cleanup: envelope-ul este cel vechi sau cel nou; în ambele cazuri
receiptul imuabil server rămâne dovada și împiedică efectul financiar dublu.

Guardul sincron bool UID+team este verificat după fiecare await; false/throw sau
dispose închide monoton instanța. Logout nu șterge pending. O instanță nouă pentru
același UID/team poate revizui aceeași intenție. Vechiul owner nu reînvie la A→B→A.
BLOCKED: propagarea atomică a generației AuthGate/team între TOATE taburile nu
poate fi garantată de un callback local care încă nu a observat logoutul altui
tab. Factory/generație partajată și integrarea AuthGate cer mandat separat.
Repository/rules rămân obligatorii; nu invocăm Web Locks ca autorizare Firebase.

## Probe și nivelul dovezii

`tests/journal_v2/browser.test.cjs` folosește producția ES module, Chromium real,
IndexedDB real și Web Locks real, două taburi și un dedicated worker, fără RAM
store substitut. Probe: lock ocupat fail-closed;24 RMW independente cu union exact;
same-ID un singur send permit; reuse ID/target; închidere tab după commit înainte
de release; worker terminat în calcul checksum înainte de write; tranzacție
IndexedDB abortată; API lipsă/strict indisponibil/sesiune revocată; corupție/V1;
cleanup concurent cu prepare;32 slots/UTF8; browser proces SIGKILL+restart același
profil. Pentru procesul nou folosește Chromium executabil real, nu recreare de
obiecte sau `browser.close()` elegant. PID-ul copilului este deținut de test.

Proba opt-in `XII_RENDERER_PID_PROBE=1` este BLOCKED: tracingul Chromium local
returnează TracingStartedInBrowser fără frame-to-PID bindings. Ea a EȘUAT când
a fost invocată explicit și este SKIPPED cu motiv în suita implicită, nu PASS.
Nu deducem PID-uri diferite numai din două taburi. Exclusivitatea este probată
între agenți JS reali tab/worker; certificarea a doi writeri în PIDs simultane
identificate rămâne BLOCKED, separat de SIGKILL al unui browser proces real.
Repetarea manuală storage în test după `busy` se face numai după refuzul explicit,
nu reprezintă o strategie de retry financiar de produs.

Teste Dart de contract cu fixture RAM sunt etichetate separat. Intrarea SDK XII
înregistrează toate cele21 controale XI/IX/VIII, apoi două probe reale:
Dart bridge+IndexedDB+Auth/Firestore emulator, ACK pierdut/recreare/reconciliere,
respectiv prepare fără send, marker absent, logout/relogin. Nu reprezintă OS crash
Dart sau două telefoane. APK este numai build existent, fără instalare/upload.

### Eșecuri observate, fără PASS inventat

Primul run local a pornit înainte să existe Chromium headless:9 startup FAIL,
nu rezultate funcționale. După instalare:9/9 locale PASS. Checkpoint4f4c3ee CI:
236Dart,77JS,23SDK PASS; browser8/9, controlul CDP `Page.crash` așteaptă eveniment
crash și timeoutează în runner. Nu îl numărăm drept renderer-crash PASS; proba
este numită corect context termination, iar crash de proces este probat separat
cu SIGKILL. Nu relaxăm o invariantă de jurnal pentru a ascunde controlul CDP.

Proba locală cu Chromium complet nu a putut porni în sandbox: socket Unix pentru
process singleton refuzat. Headless shell executabil real, selectat explicit prin
`XII_CHROMIUM_EXECUTABLE`, a trecut SIGKILL/restart. CI Linux folosește Chromium
complet implicit; rezultatul său trebuie confirmat separat. Nu escaladăm sandbox.

## Strategii native separate — BLOCKED, fail-closed implementat

| Platformă | Strategie de implementat separat | Probe necesare / status |
|---|---|---|
| Android | SQLite tranzacțional cu `BEGIN IMMEDIATE`, WAL și synchronous FULL, CAS revizie în aceeași tranzacție; criptare/cheie Android Keystore; busy timeout refuză, nu continuă unlocked | două isolates + două procese Android, force-stop în fiecare fază, upgrade APK/backup/key restore: BLOCKED |
| iOS | SQLite tranzacțional + cheie Keychain, protecția fișierului și politica background; App Group numai cu entitlement/aprobare dacă există extensii | două procese autorizate, suspend/kill, locked-device, backup restaurat fără cheie: BLOCKED |
| Windows | SQLite tranzacțional multi-process, ACL profil + cheie DPAPI; un named mutex singur nu asigură atomicitate/durabilitate | două exe procese, terminare brutală, lock abandonment, disk-full, backup/key binding: BLOCKED |

Factory non-web aruncă `journal_v2_native_platform_blocked`; nu presupune că
Web Locks există în Flutter Android/iOS/Windows și nu reutilizează un mutex Dart.
Nu adăugăm SQLite, entitlements sau dependențe în pubspec protejat prin acest PR.
Strategiile de mai sus sunt proiectare, NU implementare sau garanție fsync testată.

## Cost și limite de platformă

Jurnalul nu face Firestore calls, polling, listener, timer, serviciu sau upload.
Un pending:1 read transaction + checksum complet. O mutație:1 read +1 strict
readwrite commit +1 readback; hash envelope + cel mult32 hashuri de intenții,
O(bytes envelope) cu plafon128KiB, nu istoricul financiar complet. Strict flush
poate costa latență/IO/baterie; nu avem benchmark reprezentativ hardware.
Probe UTF8 sintetice:32 intenții mici acceptate, a33-a refuzată fără schimbarea
dovezilor;10 receipts cu payer de4000 caractere Han acceptate, următoarea refuzată.
Nu interpretăm aceste limite ca plafon monetar ori volum universal de client.

Firestore păstrează modelul XI:append2writes/2reads(+1 bootstrap); reconcile
0writes/2serverreads, replay repository0writes. Retry SDK max3 și rules accesses
pot mări reads; jurnalul nou nu face autoplay sau scanarea tuturor receipts.
Pending recovery local nu implică factură Firestore. Nu avem cifre live pentru
plan/quota/index/egress; nicio schimbare billing și nicio garanție zero-cost infinit.

STRICT IndexedDB exprimă durabilitatea cerută browserului, nu certifică hardware
fsync sau rezistență la power loss. Test SIGKILL nu este tăiere de curent.
Persistența storage bucket (`navigator.storage.persist`) nu este obținută implicit:
eviction, private browsing, clear site data, profil șters și pierdere disc pot
elimina DB. Missing DB nu poate fi distins local de prima instalare. Checksumul
nu autentifică împotriva XSS și nu detectează restaurarea unui envelope valid mai
vechi. Criptarea la rest nu este oferită de acest candidat IndexedDB; se aplică
izolarea origin/profilului, nu o garanție secure enclave. Toate acestea sunt
BLOCKED pentru afirmația absolută «zero pierderi pe orice platformă».

Backup/restore financiar rămâne fără API de import: V1/V2 separate, snapshotul XI
este numai prefix read-only, nu inventar global sau autorizare rollback. Nicio
restaurare automată peste pending activ și nicio înlocuire după corupție.

## Handoff și porți rămase

Candidatul rezolvă lost updates între writeri V2 cooperanți cu Web Locks disponibile,
în același bucket, cu commit strict și recuperare explicită. Nu este activat și
nu face aplicația pregătită de lansare. SHA/tree/CI final se consemnează în PR83
DUPĂ terminarea tuturor verificărilor obligatorii pe ultimul commit.

Următorul pas sigur: review separat al contractului V2 și al dovezilor CI; apoi
backend nativ tranzacțional și probe hardware, contract persistent Auth generation,
politică encryption/eviction/backup și decizia de cancel cert pentru pending care
nu a fost trimis. Înainte de rollout rămân și blocajele XI: gate exclusiv V1/V2
server pentru APK vechi, migrare auditată a banilor/istoricului, aritmetică monetară
exactă pentru audit, toți writerii financiari și restore global, staging+cost real.
Home/AuthGate/main.dart/116hashuri/21pini nu sunt deprotejate de acest raport.

Fără merge/deploy/live Firebase/rules/date/migrare/billing/APK distribuit. Nu
închidem issues financiare pe baza unui candidat sau a unui Android compile.

Surse primare consultate 2026-10-16: https://w3c.github.io/web-locks/ ,
https://w3c.github.io/IndexedDB/ ,
https://chromedevtools.github.io/devtools-protocol/tot/Tracing/ .
Scope-ul cooperant și durabilitatea cerută sunt contracte API; probele executate
și blocajele hardware sunt enumerate separat mai sus.

### Checkpoint local extins, înainte de HEAD final

Chromium141.0.7390.37:14 probe declarate,13PASS/0FAIL/1SKIPPED explicit BLOCKED
(PID mapping). Include proces browser SIGKILL+profil persistent restaurat identic,
lock ocupat,24 operații tab/worker,32/UTF8 bound,logout în timpul await și
separare team/V1. 199Python și3Node existente PASS; audit_repository exit0 cu
avertismente de conținut duplicat existente. Nu confundați acest rezultat local
cu rezultatul obligatoriu CI pentru ultimul SHA.
