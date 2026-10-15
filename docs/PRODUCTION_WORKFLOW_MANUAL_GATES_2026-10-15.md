# AndiCarpet — production release gates (audit + Draft only)

**15 octombrie 2026 · Shiva · numai PR Draft · NU DEPLOY**

## De ce există acest lot

Inspecția read-only a celor 14 workflowuri GitHub din baza PR #58 (HEAD `570d6a3a30206730be894589f5c7a552cfc11110`) a identificat două trasee cu efect direct asupra proiectului Firebase de producție, care puteau porni **automat la push pe `main`**:

| Fișier | Trigger anterior | Efect potențial |
| --- | --- | --- |
| `.github/workflows/publish-authorized-release.yml` | `push main` la schimbarea workflowului și `workflow_dispatch` fără confirmare obligatorie | autentificare OIDC și `firebase deploy --only hosting` |
| `.github/workflows/restore-member-directory.yml` | `push main` la schimbări de workflow, `functions/index.js`, projection/backfill ori `firestore.rules` | `firebase deploy --only firestore:rules`, `firebase deploy --only functions:syncMemberDirectory`, apoi `node functions/backfill_member_directory.js` asupra datelor existente |

**Faptul că un trigger există în sursă nu înseamnă că jobul a rulat recent**, iar activarea environment-ului `firebase-production` poate presupune protecții suplimentare configurate în GitHub pe care acest audit nu le-a verificat. Riscul este un mecanism automat de publicare care contrazice cerința proprietarului „niciun deploy fără aprobare explicită”.

Alte workflowuri au fost inspectate: `firebase-oidc-deploy.yml` este deja `workflow_dispatch` cu `github.ref == main` + `DEPLOY` pentru acțiuni de producție; `build-android.yml` este manual și produce un artifact, nu deploy Firebase; `validate.yml` și testele emulator nu au rol de publicare de producție. Nu ștergem aceste workflowuri și nu modificăm autorizațiile lor în acest lot.

## Remediere propusă, strict în ramură izolată

Am eliminat **numai triggerurile automate `push` din cele două workflowuri de producție** și introdus:
- `workflow_dispatch.inputs.confirm_production` obligatoriu, **text exact** `DEPLOY_HOSTING` pentru publicarea Hosting, respectiv `RESTORE_MEMBER_DIRECTORY` pentru operația de restaurare care include rules/trigger/backfill;
- gardă **la nivelul întregului job**: `github.event_name == 'workflow_dispatch'`, `github.ref == 'refs/heads/main'` și concordanța exactă a confirmării;
- păstrarea environment-ului existent `firebase-production`, serializării `firebase-production-deploy`, OIDC, comenzii de deploy și tuturor pașilor instalați.

Fără noi permisiuni, secrete, API-uri, dependințe, joburi cu cost sau servicii Firebase. Nu am schimbat `main` sau workflowurile deja active în producție: aceste fișiere sunt **numai în acest PR Draft**, neintegrat. Nu s-a declanșat `workflow_dispatch` și nicio autentificare OIDC de producție din această misiune.

## Teste de prevenție

`test/production_workflow_manual_gate_test.py`, descoperit de CI-ul Python standard, adaugă patru teste:
1. inspectează **toate workflowurile** pentru comenzi `firebase deploy`/backfill și respinge automatele `push`/`pull_request` în secțiunea de trigger;
2. cere confirmarea textuală exactă, ramura `main` și evenimentul manual **la nivel de job**, plus `environment: firebase-production`;
3. verifică faptul că operațiile de publicare/backfill rămân explicit declarate și revizuibile, fără ascunderea lor;
4. păstrează garda manuală existentă a `firebase-oidc-deploy.yml`.

Testele sunt contracte de **sursă**; ele nu certifică setările repository environment, rolurile IAM, aprobările reviewerilor, politica de protected branches sau absența tuturor metodelor externe de deploy. Pentru producție sunt necesare separat revizia permisiunilor OIDC, protejarea `main`, approvals și probă controlată în staging (fără date reale).

## Verificări și statut

- Bază `ci/vision-avatar-offline-android-20261015`, [PR #58](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/58), CI standard 5/5 / Identity / preview Android SUCCESS, fără intervenție în [PR #55 Luna](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/55).
- PR nou **DRAFT / DO NOT MERGE** din baza #58, `main` doar ca țintă CI. Pentru un eventual release, proprietarul trebuie să aprobe distinct schimbarea fluxului de publicare și orice deploy.
- Nu se pretinde CI verde până la verificarea ultimului HEAD real și a rezultatelor workflowurilor. Testele standard trebuie să ruleze Python, Flutter, emulator și web; workflowurile Android dedicate altor branchuri pot rămâne SKIPPED, nu PASS.
- Niciun fișier din `lib/`, `firestore.rules`, `functions/`, `android/`, `pubspec.yaml`, hashurile Vision/Schedule protejate ori date din Firestore nu a fost modificat.

**Notă operațională:** dacă aceste schimbări vor fi vreodată integrate în `main` cu aprobarea proprietarului, workflowurile manuale vor necesita deliberat confirmarea exactă. Un simple `push` pe `main` nu ar trebui să mai poată executa respectivele două joburi.
