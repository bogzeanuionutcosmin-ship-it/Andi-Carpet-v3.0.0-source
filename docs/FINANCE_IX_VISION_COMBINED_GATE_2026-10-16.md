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
- două verificări de reconciliere simultane primesc un singur rezultat cu **o singură citire a markerului**; actualizarea modelului UI este o citire server separată, explicită, neefectuată de acest wrapper, fără retry;
- la completare (inclusiv excepție) lockul de instanță se elimină dacă încă deține cheia. Nu există timer, polling, păstrarea payloadului după încheiere ori proces de fundal.

Teste noi deterministe: `test/finance_vision_observed_coordinator_test.dart` + `test/finance_vision_observed_coordinator_contract_test.py` (cinci condiții statice). Contracția pentru UID/epocă și protocolul financiar IX rămân în straturile existente.

**Nu este lock multiproces, multi-tab, între dispozitive sau CAS la nivel secure storage.** Absența dublurilor când rulează 30 de apeluri în același obiect nu autorizează activarea implicită Home, modificarea regulilor live sau eliminarea markerilor Firestore. Fără schimbări în PR #73 sau `main`.

## Lot de siguranță: revenire A1→B→A2 și eliminarea drepturilor observerului

`FinanceVisionObservedCoordinator` verifică și predicatul autorizat al `FinanceRepository` și al `FinanceIntentJournal` (ambele sunt legate de AuthGate+generație în compoziția permisă), **înainte** să returneze un eventual Future comun, să înceapă o execuție sau o reconciliere. Prima negare/eroare marchează definitiv acel observer ca închis; UID-ul A2 redevenit egal cu A1 nu îi mai poate reda accesul. `dispose()` este idempotent și blochează operațiuni viitoare. Nu șterge journal financiar, nu pretinde că anulează o tranzacție server deja pornită. Un rezultat după logout rămâne al operației originale, dar nu se mai promovează într-un jurnal Vision al altei epoci.

Teste: `test/finance_vision_observed_coordinator_test.dart` include A1→B→A2 cu callback vechi devenit fals și reactivat artificial, `dispose` repetat, fără scrieri server, fără reset de date, plus overlapul de 30 de apeluri, reconcilierea unică și cleanup. Contractul Python verifică monotonicitatea doar suplimentar probelor runtime. Nu înlocuiește drepturile Firebase/security rules și nu justifică activarea Home.


## Lot independent: două instanțe de UI în același isolate

După lotul single-flight per obiect, rămânea cursa între două `FinanceVisionObservedCoordinator` distincte pentru același UID/target, când ambele citeau jurnalul **înainte** ca primul să execute `prepare`. `FinanceIntentJournal` serializează `prepare`, dar vechiul coordinator poate ajunge în read-back/replay al aceleiași intenții.

Adaptorul opțional impune acum un **lease efemer static per (ownerUid, targetPath), exclusiv în același Dart isolate**: un al doilea wrapper răspunde `uncertain/finance_operation_in_another_scope`, cu `blockedByPendingIntent=true`, fără a primi `Future` sau date din prima sesiune și fără apel la Firestore. Leaseul se eliberează pe succes/eșec prin identitate strictă de token. Prima intenție, dacă rămâne în jurnal cu ACK incert, necesită în continuare `reconcileExplicitly` după eliberarea leaseului; deblocarea leaseului nu înseamnă autorizare de retrimitere.

`test/finance_vision_observed_coordinator_test.dart` simulează două instanțe pentru A cu același target, commit cu răspuns pierdut, 0 citiri/0 tranzacții la a doua instanță în timpul primei, diagnostic nepartajat, apoi recuperare explicită fără a doua tranzacție; testul structural Python verifică absența transportului/stocării în această protecție.

**Limită:** nu este CAS între procese sau taburi, nu previne writerii legacy/Home și nu poate oferi consistență inter-device fără marker/revizie și rules server. Nu activează implicit Home și nu modifică PR #73, rules, Firebase live sau publicarea APK.


## Lot: excepții neclasificate după un eventual prepare durabil

La granița dintre controller și coordinator, o excepție neașteptată poate surveni *după* persistarea intenției și nu dovedește că serverul a refuzat operația. Wrapperul opțional captează excepțiile din `coordinator.executeExplicitly` și `coordinator.reconcileExplicitly`, întoarce invariabil `uncertain/finance_unclassified_result` cu `journalPending=true` și păstrează dovezile din jurnal. Nu inventează un succes, nu șterge jurnalul și nu execută retry. Întoarce `finance_session_expired` fără telemetrie dacă sesiunea este revocată.

Testul `test/finance_vision_observed_coordinator_test.dart` injectează un `FinanceRepository` a cărui execuție și reconciliere aruncă mesaje brute cu text sensibil; dovedește 0 tranzacții, 0 citiri server, journal recuperabil, două incidente agregate doar sub cod anonim, fără text brut/operationId. Contractul Python interzice interpolarea excepțiilor în raport. Acesta este un fail-closed defensive seam, nu o confirmare a durabilității hardware sau a protecției între taburi.


## Vision: panou diagnostic autentic pentru sesiune, încă opt-in

`lib/vision/vision_session_diagnostics_panel.dart` este un `StatefulWidget` mic, fără servicii backend, care consumă exclusiv `VisionSessionJournalLease`, niciodată `VisionErrorTelemetry.log` global/persistat pe instalare. La fiecare build, verifică `lease.isCurrent` și obține o copie temporară prin `snapshotForDisplay`. Jurnalul nu este memorat în widget. La evenimentul de `revoke` notificat sincron de jurnal, ascunde lista la următorul frame; la înlocuirea `lease` se deabonează și curăță referințele la generația veche.

UI disponibil numai pentru sesiunea demonstrată: explicații determinate prin `VisionDiagnosticAdvisor`, lista codurilor fixe și numere de repetări, refresh manual (fără polling) și buton explicit pentru copierea raportului anonim. Revocarea este verificată din nou înainte de `Clipboard.setData` și după încheierea apelului; un callback de clipboard întârziat nu poate afișa succes pentru sesiunea B. *Limită a clipboardului platformei:* dacă apelul a început înainte de logout, bytes deja predați sistemului de operare nu pot fi retrași ulterior; utilizatorul trebuie să confirme explicit exportul.

`test/vision_session_diagnostics_panel_test.dart`: panou închis pentru `null`, eveniment inexistent până la refresh, emitere fixă și raport copiat manual, A→B fără raportul A, revocare în timp real, clipboard lent în logout și A1→B→A2 cu același UID diferit ca epocă. Nu există pretenție de restart real, UI Home sau acces la alte conturi.

Aceasta este **doar piesă opt-in** și nu instalează nicio rută Vision în aplicația principală. Condiție obligatorie înainte de folosire în Home: `VisionAuthGateEpochBridge` sub AuthGate autentic, callback UID+generație verificat, generarea sesiunilor la fiecare login, teste de integrare protejate și aprobarea de modificare a Home. `production_ready=false`.


## Witness: AuthGate epoch bridge + Vision panou, aceeași compoziție de widgeturi

`test/vision_session_panel_authgate_composition_test.dart` montează **împreună** `VisionAuthGateEpochBridge` și `VisionSessionDiagnosticsPanel`, fără Home, Firestore sau rețea. Un rebuild simplu al callbackului păstrează același lease și observațiile curente. Tranziția A1→B și întoarcerea A2 în altă generație rotesc tokenul autoritativ, curăță ecranele și resping raportul vechi, fără să acceseze logul global. Aceasta extinde testele de UI session-scoped, dar **nu** înseamnă că AuthGate Home de producție montează deja acest widget; modificările protected Home/AuthGate rămân BLOCKED.
