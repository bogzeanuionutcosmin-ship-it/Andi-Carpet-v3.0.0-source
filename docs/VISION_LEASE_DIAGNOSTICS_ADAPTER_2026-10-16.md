# Vision — adaptor vizual pentru jurnalul de sesiune, fără integrare AuthGate

**16 octombrie 2026 · Shiva · PR Draft separat / NU MERGE**

## Context

- [PR #61](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/61) a adăugat avatarul pasiv în `VisionDiagnosticsPage` (CI standard + Identity + Android GREEN).
- [PR #62](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/62), HEAD `be90a9cb4a6612ff955536c85f3d71566a1a4b2c`, a introdus `VisionSessionJournal` strict în memorie și lease revocabil, testat cu A→B→A2 și callbackuri întârziate. Standard 5/5, Identity și Android toate SUCCESS.
- **De făcut:** vizualizarea doar a jurnalului unui lease *autorizat*, fără acces la `VisionErrorTelemetry.log`, care rămâne persistent și comun întregii instalări.

## Livrare în acest Draft

1. `VisionSessionJournalLease.snapshotForDisplay()`: creează un `VisionErrorLog` **detașat** din snapshotul strict sanitizat și bounded al lease-ului. Verifică ownership atât la citire, cât și după snapshot. Folosește clock/capete identice cu sursa ca să nu piardă arbitrar evenimente la testele temporale. Nu furnizează pointerul mutabil către jurnalul original, nu face I/O și nu persistă.
2. `lib/vision/vision_scoped_diagnostics_page.dart`: adaptor Flutter `VisionScopedDiagnosticsPage(lease: ...)`, care furnizează un snapshot validat și callbackul `() => lease.isCurrent` către **pagina deja fail-closed**. Dacă lease-ul este nul/revocat, pagina afișează doar mesajul de acces indisponibil. Nu există buton Home/route nou.
3. `test/vision_scoped_diagnostics_page_test.dart`: șapte probe Flutter: view autorizat, clipboard blocat la revocare chiar fără rebuild programat, A→B→A2 cu două identități și întoarcere A, callback ce aruncă, snapshot detașat, revocare între citire și verificare, logout explicit.
4. `test/vision_scoped_diagnostics_adapter_contract_test.py`: patru contracte de sursă privind lipsa accessului la Firebase/Clipboard/rețea, callbackul de owner, snapshotul independent și protecția jurnalului instalării.
5. Workflow Android compile-only existent activat pentru branchul nou; standard 5/5, Identity și Android CI trebuie validate pe HEAD exact.

## Limite care NU trebuie ascunse

- **Nu este înregistrată nicio rută nouă în aplicația autentificată.** Nici `main.dart`, `AuthGate`, Home, ExpensePage, Admin Restore, Firestore rules, Cloud Functions, Mapbox, OCR sau FCM nu au fost modificate. Adaptorul este reutilizabil, dar **nefolosit încă în producție**.
- `VisionSessionJournalLease` **nu își dovedește independent identitatea**. Callerul care îl creează trebuie să folosească un callback AuthGate cu **UID plus generația sesiunii**, nu doar UID, `() => true` sau un flag UI. Acest contract este condiție obligatorie pentru integrare, documentată în [Issue #63](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/issues/63).
- Un snapshot deja returnat poate exista încă în RAM după revocare; **nu este o nouă capabilitate de acces**. Widgetul din acest lot folosește callbackul `lease.isCurrent` al paginii existente înainte de build/copy. Pe logout, navigatorul și adaptorul trebuie distruse/remontate; alte UI-uri nu au voie să salveze sau distribuie referința la snapshot. Clipboardul deja copiat înainte de revocare nu poate fi șters retrospectiv în siguranță.
- Când AuthGate revocă sesiunea *fără rebuild*, pagina deja afișată poate conține temporar ultimul frame până la următorul eveniment/reconstrucție; testele garantează **blocarea clipboardului și reconstruirea fail-closed**, nu ștergerea instantanee din GPU. Un listener/route invalidation va trebui realizat odată cu integrarea AuthGate.
- Acest flux **nu importă istoricul global**. Evenimentele trebuie instrumentate explicit numai pe lease-ul activ, eventual ulterior și numai cu coduri anonime. Niciun Firebase read/write, polling, secure storage, cost nou ori servicii AI.
- Manifestul 116 hashuri și `test/vision_hardening_freeze_test.py` rămân neatinse; `VisionErrorTelemetry.log` rămâne blocat în aplicația actuală.
- Luna continuă independent Misiunea VIII în PR #55, fără modificare/merge din partea Shiva. Compatibilitatea la integrare va necesita testele tuturor pe arborele combinat.

## Release gates

Înainte de a închide lotul verificați standard CI 5/5, toate probele widget, Identity, Android build compile-only, web și integritatea manifestelor pe HEAD-ul exact. **Fără** merge, deploy, modificări Firebase în producție, APK publicat/instalat, billing/Blaze sau reguli financiare noi.
