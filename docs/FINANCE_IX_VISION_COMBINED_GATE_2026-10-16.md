# Test integrat Finance IX + Vision session-scoped — 16 octombrie 2026

**Shiva / DO NOT MERGE / test-only composition.** Bază exactă: Luna PR #73 la `4cd6ee522534b6e5edd45d6112ddadf23c418bac`, deja Standard 5/5, Identity, Mission IX 3/3, Platforms GREEN pe ramura proprie. Vision PR #74 la `5cd131ea148ac32cfacd40a375aa4609222c0555`, Standard 5/5, Identity și Android compile-only GREEN. **Aceste rezultate SEPARATE nu demonstrează arborele combinat; rezultatele acestei ramuri trebuie citite pe HEAD-ul ei.**

## Mod de compunere și izolare
- Ramură nouă `integration/finance-ix-vision-scoped-20261016`, pornită din HEAD PR #73 fără modificarea ramurii ori a PR-ului Lunei.
- Au fost preluate prin **bloburi SHA exacte, auditabile**, doar porturile independente Vision: journal RAM, lifecycle coordinator, widget scope, bridge pentru AuthGate, catalog de semnale și advice-ul financiar `operation_uncertain`, plus teste relevante. Nu am importat Home/AuthGate/main/rules/source-pins din ramura Shiva.
- `lib/integration/finance_vision_outcome_observer.dart`: adaptor **nou, opțional, cu flux unic spre Vision**, care primește doar `FinanceIntentResult.status`. Confirmed și rejectedBeforeWrite nu generează incidente false. Uncertain generează doar codul fix `finance/operation_uncertain`; conflict produce `finance/revision_conflict`. Nu transmite identificatori de intenție, UID, bani, nume, excepții sau OCR, nu execută tranzacții, refresh, retry ori writes.
- `test/finance_vision_epoch_compatibility_test.dart`: probă deterministă cu `FinanceAtomicFixture` + `FinanceCheckedJournalStorage` din IX, simulează timeout după commit, un singur receipt, semnal anonim pentru A, revocarea jurnalului Vision la A→B, jurnalul financiar B gol, A2 fără diagnostic vechi, reconcilierea **intenției identice** prin marker fără re-execuția tranzacției. Încă două teste: statusurile confirmate/refuzate nu inventează incidente și ownerul revocat nu poate emite.
- Workflowurile `mission-ix.yml` și `mission-ix-platforms.yml` includ doar noua ramură ca a doua opțiune de execuție a testelor; nicio modificare a pașilor, serviciilor sau drepturilor CI. Standard, Identity, finance emulator, Chrome, Android compile-only vor valida **același tree**.

## Limite esențiale
- Probe cu fake atomic și storage în RAM pentru cazul încrucișat, **nu dovadă hardware sau certitudine de persistență a web/secure storage după restart**; acceptanțele SDK IX existente în aceeași ramură sunt teste distincte.
- Nu am conectat producătorii reali GPS/FCM/OCR/Finance la aplicația Home. Portul nu este activ implicit. Jurnalul global de instalare Vision rămâne neafișabil între conturi.
- Nicio schimbare în Home, AuthGate, fișiere protejate, runtime financiar IX al Lunei, Firestore rules, Functions sau billing. Niciun merge/cherry-pick în ramurile originale, merge în main, deploy, migrare, date Firebase live ori APK publicat.
- **production_ready=false**. Issues #54/#63/#72 rămân deschise. Urmează închiderea incompatibilității clienților legacy, contracte Home writer, Restore, hardware și audit Spark înainte de orice release.

## Criterii verificabile
1. Tree exact și manifest de 116 SHA/pini intact, fără fișierele înghețate modificate.
2. Standard 5/5, Identity, Mission IX 3/3, Mission IX Platforms + Android pe HEAD exact.
3. `finance_vision_epoch_compatibility_test.dart` trece fără retry dublu și fără păstrarea raportului A la B.
4. Orice FAIL rămâne în PR și se repară în aceeași ramură înainte de verdict. Niciun SKIPPED nu este considerat PASS.

## Continuare: adaptorul operațional opt-in

`lib/integration/finance_vision_observed_coordinator.dart` este un wrapper peste `FinanceIntentCoordinator`: apelează **doar la comandă explicită** `executeExplicitly` sau `reconcileExplicitly`, apoi trimite statusul către sink-ul anonim deja revocabil. Nu deschide intenții la startup/logout/rebuild, nu inițiază citiri server și nu face retries. Chiar dacă Vision e expirat sau aruncă eroare, rezultatul financiar original rămâne nemodificat. Nu este conectat implicit în Home.

`test/finance_vision_observed_coordinator_test.dart` urmărește: commit server cu ack pierdut → uncertain anonim → reconcilierea **aceleiași** intenții fără al doilea submit; plus operație începută înainte de logout care nu poate popula jurnalul Vision al noului utilizator. Aceste teste sunt fake/stub, nu substituie SDK și hardware.

Criteriu: verifică toate joburile pe **noul HEAD**; verdele anterior de pe `fd355d6` nu validează această completare. Înghețarea surselor, datele live, APK publicat și producția rămân neatinse.

## Protecție suplimentară la reluarea unei intenții

Wrapperul `FinanceVisionObservedCoordinator.executeExplicitly` citește jurnalul înainte de orice comandă spre server:
- aceeași identitate + același digest încă pending ⇒ `uncertain`, cod `finance_existing_intent_requires_reconciliation`, **zero apeluri atomic noi**; operatorul folosește doar `reconcileExplicitly`;
- aceeași identitate, alt digest ⇒ refuz înainte de scriere (`finance_intent_identity_reuse`);
- intenție diferită spre același target ⇒ refuz (`finance_unresolved_target`);
- jurnal corupt, indisponibil sau autentificare revocată ⇒ `uncertain`, fără să trimită și fără să șteargă jurnalul.
Testele verifică ACK pierdut după commit fără retransmitere, respingerea jurnalului corupt fără reset și revocarea proprietății la logout.

**Limita nerezolvată:** read-before-send + jurnalul serializat în același isolate NU garantează unicitatea transacțiilor între procese, două taburi web sau dispozitive. Nu se activează în Home pe acest criteriu. Marcajul/revizia server-side și migrarea legacy rămân obligatorii; zero read/write Firebase noi pentru această observație client-side.

## Lot nou: deduplicare sincronă a apelurilor suprapuse

Între verificarea jurnalului și pregătirea/execuția intenției poate exista o cursă la apăsări simultane pe același buton, chiar și într-un singur widget. Pe această ramură, `FinanceVisionObservedCoordinator` are un **single-flight per target per instanță**:
- 30 de apăsări identice care se suprapun primesc același `Future` și un singur rezultat/incident Vision, fără 30 de tranzacții;
- intenții diferite spre același target și combinațiile executare/reconciliere în același timp sunt blocate cu `finance_operation_still_in_flight`, fără să fie confundate cu respingeri server dovedite;
- două verificări de reconciliere simultane primesc un singur rezultat și o singură pereche de citiri server, fără retry;
- la completare (inclusiv excepție) lockul de instanță se elimină dacă încă deține cheia. Nu există timer, polling, păstrarea payloadului după încheiere ori proces de fundal.

Teste noi deterministe: `test/finance_vision_observed_coordinator_test.dart` + `test/finance_vision_observed_coordinator_contract_test.py` (cinci condiții statice). Contracția pentru UID/epocă și protocolul financiar IX rămân în straturile existente.

**Nu este lock multiproces, multi-tab, între dispozitive sau CAS la nivel secure storage.** Absența dublurilor când rulează 30 de apeluri în același obiect nu autorizează activarea implicită Home, modificarea regulilor live sau eliminarea markerilor Firestore. Fără schimbări în PR #73 sau `main`.
