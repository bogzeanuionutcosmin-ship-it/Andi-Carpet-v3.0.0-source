# AndiCarpet — port Vision cu jurnal temporar, izolat pe epoca sesiunii

**16 octombrie 2026 · Shiva · PR Draft izolat · FĂRĂ deploy sau integrare Home**

## Scop și motiv

`VisionErrorTelemetry.log` este un singleton criptat local cu un storage key pentru **toată instalarea**, fără partiționare pe UID. Din acest motiv `VisionDiagnosticsPage` blochează vizualizarea jurnalului principal chiar și când un cont este autentificat; altfel utilizatorul B poate vedea evenimentele lăsate de A. Avatarul adăugat în PR #61 nu schimbă această regulă.

Acest lot construiește un **port reutilizabil doar în memorie**, conceput ca viitor jurnal separat pentru o sesiune autentificată, fără să citească ori să modifice logul device-wide existent.

## Cod livrat

`lib/vision/vision_session_journal.dart`:
- `VisionSessionJournal.startSession(isSessionCurrent: ...)` atribuie o identitate de epocă nouă prin `Object()` și un `VisionErrorLog` nou, cu capete bounded: implicit 150 intrări, 48KiB encoded, TTL șapte zile **numai în RAM**.
- `VisionSessionJournalLease` validează identitatea epocii și callbackul extern de ownership la fiecare `record`/`entries`/`resolve`/`buildReport`. Revocarea explicită, callbackul `false` ori excepția invalidează și abandonează imediat jurnalul.
- Un lease vechi nu poate invalida B sau A2; A→B→A2 are mereu jurnale diferite, chiar dacă UID A revine. Apelurile întârziate sunt refuzate fără logare.
- Evenimentele sunt acceptate exclusiv ca identificatori normalizați prin `VisionErrorLog`, iar exportul folosește `VisionDiagnosticReport`, fără excepții brute, UID, token, SMS, OCR ori coordonate.
- **Zero** importuri Firebase, HTTP, secure storage, singleton telemetry, UI/Navigation sau cron/Timer; nu generează documente Firestore, scrieri Cloud, citiri, trafic și costuri.
- Jurnalul **nu este serializat/persistat** și nu supraviețuiește restartului — o limitare intenționată care evită moștenirea datelor între conturi.

## Teste și acceptanțe

- `test/vision_session_journal_test.dart`: nouă teste Flutter pure pentru A→B→A2, aceeași identitate cu alt epoch, callback revocat/throwing, callback vechi întârziat, bounds/identificatori siguri, liste imuabile, reconcilierea unui incident în RAM, export care verifică din nou ownershipul și logout.
- `test/vision_session_journal_contract_test.py`: patru teste de sursă pentru absența transportului/storage, revocare fail-closed și izolarea de UI.
- `.github/workflows/verify-vision-modular-android.yml`: doar enable branch pentru suita AuthGate/Vision + Android compile-only deja existentă; nu a fost schimbată semantica de build sau publicare.
- Pe HEAD final se cer standard CI 5/5, Identity și Android compile-only; nu reutiliza verdele PR #61 fără a testa tree-ul nou.

## Condiții de securitate fundamentale

1. **Acest port nu își poate autentifica singur callerul.** Viitorul cod integrator **trebuie** să furnizeze closure-ul de ownership exact al AuthGate (UID **și** generation), nu doar UID sau `() => true`. O simplă etichetă textuală de UID nu înseamnă izolare.
2. O listă de intrări sau raport deja returnate sunt snapshoturi; UI trebuie să le elimine și să reverifice `lease.isCurrent` înainte de fiecare prezentare, copiere sau share, inclusiv după `await`. Nu păstra pointeri la acestea după logout.
3. `VisionDiagnosticsPage` **rămâne fail-closed** pentru `VisionErrorTelemetry.log` și pentru surse fără owner valid; acest PR nu îi injectează noul jurnal și nu adaugă rută Home. Integrarea viitoare necesită matrice dedicată cu A→B→A2, token revoked, offline și race de navigare, pe dispozitiv real.
4. Nu promite că „toate erorile” ajung automat în jurnalul nou: în acest PR evenimentele sunt înregistrate doar de callerii expliciți ai lease-ului. Hooks-urile vechi din singleton rămân active conform codului existent.
5. Sursa `lib/vision/vision_session_journal.dart` este nouă și nu atinge cele 116 hashuri înghețate, regulile Firestore, contractul financiar, `main.dart`, Home/ExpensePage sau Admin Restore.

## Separare de Luna și release

Bază: [PR #61](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/61), HEAD `473e985f4d1a253e887fa9665d758af7509443fd`, standard 5/5 + Identity + Android SUCCESS. Luna continuă Misiunea VIII în [PR #55](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/55); acest lot nu îi schimbă ramura, fișierele sau testele.

**Status:** componentă pregătitoare izolată, nu funcționalitate user-facing, neintegrată cu AuthGate/Home. Fără merge, deploy, modificări Firebase live, plan plătit, APK sau web release și fără publicare în aplicația curentă.
