# AndiCarpet — audit automat pentru declanșatoare de producție (KNOWN UNSAFE)

**15 octombrie 2026 · Shiva · PR Draft read-only în privința producției**

## Riscuri identificate, încă NEREPARATE

Inspectând toate workflowurile GitHub ale proiectului, am descoperit aceste căi existente:

| Fișier | Eveniment / drepturi | Efect care ar putea fi declanșat |
| --- | --- | --- |
| `.github/workflows/publish-authorized-release.yml` | `push` pe `main` la schimbarea sa; și `workflow_dispatch` fără confirmare obligatorie | OIDC + `firebase deploy --only hosting` |
| `.github/workflows/restore-member-directory.yml` | `push` pe `main` la schimbări Functions/Firestore rules/workflow | OIDC + `firebase deploy --only firestore:rules` + `functions:syncMemberDirectory` + backfill utilizatori |
| `.github/workflows/import-v3.0.1.yml` | `workflow_dispatch` cu `contents: write` | import de ZIP și `git push` |
| `.github/workflows/setup-source.yml` | `workflow_dispatch` cu `contents: write` | extragere ZIP și `git push` |

Primele **două reprezintă riscuri de deploy automat** la `main`; celelalte două sunt operații **manuale** care pot totuși modifica arborele sursă. Există deja `.github/workflows/firebase-oidc-deploy.yml`, exclusiv manual, cu confirmarea `DEPLOY` și `main` pentru operațiile de producție. Acest audit nu demonstrează că un deploy real a avut loc, nici că GitHub environment-ul `firebase-production` are sau nu aprobări separate.

## Bariera de integritate care a decis rezultatul

Cele patru workflowuri de mai sus (plus `firebase-oidc-deploy.yml`) sunt incluse în setul cu **116 SHA256 imutabile**, specificate în `docs/ROUTING_PDF_PROTECTED_2026-10-13.json`. Într-un commit intermediar s-a încercat eliminarea triggerurilor automate din primele două și introducerea `workflow_dispatch` cu confirmare `DEPLOY_HOSTING` sau `RESTORE_MEMBER_DIRECTORY`. **CI a refuzat aceste modificări** prin două verificări reale `routing_pdf_boundary_test.py` (SHA mismatch).

**Am restaurat ambele workflowuri exact la conținutul bazei PR #58**, verificând egalitatea SHA de blob GitHub la restaurare. **Nu am modificat manifestul, nu am scos fișiere de sub protecție și nu am relaxat testele existente.** În consecință, remedierea propriu-zisă a triggerurilor de deploy este **ÎNCĂ NECESARĂ, NEIMPLEMENTATĂ** și trebuie autorizată separat într-un proces de schimbare a surselor protejate. Nu afirmați că actualul repository a devenit manual-only.

## Ce oferă efectiv acest PR

- `test/production_workflow_manual_gate_test.py`: **5** teste Python descoperite automat de CI-ul standard, toate read-only. Ele (1) detectează orice nou workflow cu `firebase deploy`/backfill și `push`/`pull_request` în afara celor două excepții `KNOWN_UNSAFE_AUTO_DEPLOY`; (2) verifică hashurile oficiale ale celor două workflowuri vechi, fără bypass; (3) caracterizează operațiile reale și garda `firebase-oidc-deploy.yml`; (4) caracterizează cele două importuri manuale care au `git push`; (5) resping orice **nou actor `git push` automat**.
- Documentul acesta și checkpointul `ChatGpt`: risc clar, experimente CI RED și restaurare, recomandări pentru protejarea producției.
- Niciun fișier de runtime, Firebase rules, business, financiar, release workflow sau sursă protejată nu este schimbat în arborele final.

**Atenție:** aceste verificări pot fi GREEN chiar dacă *cele două riscuri cunoscute rămân nesigure*. Sunt **teste de caracterizare și non-regresie**, NU validare că lansarea este sigură. Nu se atinge producția, nu se declanșează autentificare/deploy/backfill, nu se schimbă planul Spark, nu există APK publicat.

## Remedierea ulterioară recomandată, NEAUTORIZATĂ pentru fișierele protejate

1. După review și autorizare explicită, renunțare la `push` în cele două workflowuri de producție; `workflow_dispatch` cu confirmare textuală distinctă, plus `github.ref == refs/heads/main` la nivelul jobului; menținerea environment `firebase-production`, OIDC și serializarea deployului.
2. Audit de protecție pentru `main`, approval reviewers pentru `firebase-production` și drepturile IAM ale service account-ului de deploy; până atunci nu se certifică siguranța.
3. Teste YAML/static RED→GREEN, reconcilierea manifestului înghețat într-un **proces explicit autorizat**, CI standard/identity + verificare controlată staging; niciodată deploy „de probă” în producție.
4. Abia apoi evaluarea dacă importer-ele legacy cu `contents:write` și `git push` mai sunt necesare ori trebuie limitate la ramuri de import dedicate. Nu modificați tacit `main`.

## Separare și checkpoint

- Pornit din [PR #58](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/58) HEAD `570d6a3a30206730be894589f5c7a552cfc11110`.
- [Luna PR #55](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/55) rămâne read-only, fără intervenții. `main` este bază numai pentru declanșarea testelor de PR.
- **Nu declarați PASS pe un HEAD nou înainte de verificarea GitHub CI.** Workflowurile Android/Finance dedicate altor ramuri pot fi SKIPPED intenționat.
- Zero merge, deploy, producție, Firebase rules reale, date reale, billing, modificări `lib/`, schimbare de costuri, APK publicat ori autentificare OIDC.

**STATUS:** audit și caracterizare, două vulnerabilități de automatizare `KNOWN UNSAFE`, *nu remediere*.