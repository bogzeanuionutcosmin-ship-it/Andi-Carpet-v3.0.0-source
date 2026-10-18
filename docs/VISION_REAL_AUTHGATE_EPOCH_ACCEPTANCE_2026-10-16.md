# AndiCarpet — probă de integrare Vision cu AuthGate real, fără Firebase live

**16 octombrie 2026 · Shiva · lot autonom strict de teste / CI / documentație**

## Motiv

PR #65 a livrat o notificare sincronă de revocare a jurnalului Vision și ascunderea proactivă a paginii de diagnostic, cu [standard 5/5 (472 Flutter + 211 Python), Identity și Android GREEN](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/65). Totuși, acele teste verificau în principal callbackuri controlate direct în fixture, fără a demonstra ce oferă deja **AuthGate-ul adevărat**.

Auditul codului `lib/auth/auth_gate.dart` a confirmat că în `build` AuthGate transmite deja `sessionIsCurrent()` prin `activeSessionPageBuilder`. Predicatul captează `_sessionGeneration` și verifică simultan `mounted`, `_user.uid`, `_currentUser.uid` și `profile.uid`. Callbackul `onSessionChanged` este invocat când AuthGate procesează un logout/schimbare de UID; nu trebuie substituit cu o comparație simplă de UID.

## Livrarea prezentului lot

- `test/vision_real_authgate_epoch_integration_test.dart`: **trei teste Flutter noi** montează `AuthGate` autentic (nu o imitație) prin `AuthGateSources` cu `SessionAuth/SessionFirestore` din fixture-urile protejate deja validate. Integrează **numai în test** `VisionSessionJournal` + `VisionScopedDiagnosticsPage` prin callbackurile publice AuthGate.
  1. A1 → B → A2: evenimentele din A1 nu mai apar în B, iar la revenirea în A nici B, nici A1 nu sunt reafișate. Callbackul unui profil vechi nu poate resuscita vechiul jurnal sau permite un raport.
  2. Logout → relogin cu același UID: jurnalul anterior și lease-ul vechi nu se reautorizează, noua generație primește log gol, iar evenimentele sosite târziu sunt refuzate.
  3. Stream temporar null/reconnect cu același UID încă prezent în SDK: nu distruge jurnalul autorizat și nu înregistrează o generație falsă, păstrând aceeași copie.
- `test/vision_real_authgate_epoch_contract_test.py`: **trei contracte Python noi** verifică tipul gate-ului real, sursele exclusiv simulate, callbackul UID+generație din sursa înghețată și acceptanțele adverse.
- Activarea workflowului Android compile-only existent doar pentru acest branch. Comanda lui de test include `test/vision_*_test.dart`, deci adaugă noul test în suita Android + AuthGate, apoi compilează `lib/main.dart` fără instalare sau publicare.

## Limite esențiale

**Aceasta este o probă de integrare automatizată, nu activarea funcției în Home!** Callbackurile sunt conectate la un `_VisionGateHarness` local în test. Codul de producție `main.dart`, `AuthGate`, Home, Explorer, ExpensePage, Admin Restore și Navigator rămâne identic. Un eventual wiring de producție trebuie:
- să apeleze `journal.revoke()` **sincron** la `onSessionChanged` și la invalidările de generație/înlocuire a root-ului;
- să păstreze predicatul real `sessionIsCurrent` transmis de AuthGate și să nu stocheze rapoartele/snapshoturile între epoci;
- să utilizeze surse de evenimente cu coduri sanitizate, fără istoric global al instalării, și să treacă probe fizice Android (offline/reconnect, secure storage și lifecycle), plus compatibilitatea cu versiunea financiară a Lunei pe un arbore integrat;
- să respecte statusul fail-closed când sursa nu mai este autorizată, chiar dacă lease-ul era valid înainte.

Jurnalul Vision rămâne temporar numai în RAM. **Zero Firestore reads/writes**, zero upload, polling, backend, API AI plătit, cost nou sau modificări în proiectul Firebase de producție. Nu ne atingem de fișierele înghețate în cele 116 SHA (nici de `test/vision_hardening_freeze_test.py`). Fișierele modificate sunt exclusiv două teste noi, acest raport, `ChatGpt` și condiția workflowului deja folosit de Vision.

## Separare / status de release

Bază: [PR #65](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/65), HEAD `f5594834e3ff44c7bdc4558b2de49cc461582238`, toate workflowurile active GREEN. Luna: [PR #55](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/55), nealterat.

La încheiere, validați standard CI 5/5, Identity și Android compile-only pe **HEAD exact**. Până la rezultate, statusul este „în lucru”, nu „ready for release”. PR Draft, fără merge, deploy sau APK publicat.
