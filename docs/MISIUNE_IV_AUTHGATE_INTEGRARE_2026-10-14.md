# MISIUNEA IV — AuthGate P1 peste Home modularizat
**2026-10-14 · plan, NU fix implementat · doar ramura `fix/authgate-on-modular-home-20261014`**

## Mandat autorizat
Utilizatorul a aprobat începerea reparațiilor reale în ramură separată, cu CI și fără intervenții în producție. Prima misiune este **izolarea utilizatorilor A→B, callbacks întârziate și granița sesiunii**, nu backup, OCR sau Vision.

**Bază exactă:** PR #28 HEAD `fd602ed4bd727e2c2b41cf24ac988a818a2564ff` (274 Flutter, 158 Python, 3 Node, 15 emulator, standard 5/5 + identity SUCCESS; 116 protected hashes). **Sursă semantică read-only:** PR #33 HEAD `a5f43ef9ce0bfedaf59766aafe18732fef7f8f47`. PR #34 `264610624b26d0718c80c49c599e9451f858fcab` și PR #29 `545e0202755a8ee86a7b3406adccd469aac84f9e` rămân read-only. Reverifică toate HEAD-urile înainte de lucru.

**PR nou Draft:** HEAD `fix/authgate-on-modular-home-20261014`, BASE `refactor/home-financial-writes-20261013` (#28), nu `main`. Nu face merge nici în #28, nici în main.

## Citește înainte de cod
`ChatGpt`, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, `ARHITECTURA_VISION_ULTRON_JARVIS_ZERO_COST.md`, `docs/MISIUNE_EXTINSA_III_2026-10-14.md`, `docs/PLAN_PORTARE_TESTE_SECURITATE_PR33_2026-10-14.md`, `docs/INTEGRARE_PR28_PR33_PR34_2026-10-14.md`, `docs/PROTECTII_BACKUP_MIGRARE_PROPUNERE_2026-10-14.md`. Citește `docs/AUTH_SESSION_SECURITY_2026-10-14.md` și cele două suite de acceptanță din PR #33. Planul de portare al #28 este sursa exactă pentru **A01–A12, C01–C08**.

## Lot 0 — checkout și granița de lucru
Verifică HEAD local/origin, working tree și CI. Păstrează toate fixture-urile, porturile, proiecțiile și modulele #28; nu șterge cele 59 Dart `part`. Nu copia `home_page.dart` monolitic din #33: ar elimina modularizarea. Nicio modificare în PR #28/#33/#34/#29/main. Notează matricea fișierelor destinație.

## Lot 1 — RED verificabil
Portează/adaptează pe această ramură 12 acceptanțe și 8 controale #33 la `AuthGateSources`, `activePageBuilder`, ports Home și SDK fakes #28. Testează A→B pending/error/null/logout, A→B→A, root route/dialog/SnackBar, auth-stream error cu SDK UID diferit, callbackuri personale post-frame, delayed FCM/GPS, plus regresiile same UID/reconnect/Back/financial scope. **Commit/test CI RED înainte de fix**, cu eșecuri de comportament reale. Erori de compilare, timeout/fixture bug nu sunt dovadă RED. Nu relaxa testele doar pentru verde.

## Lot 2 — AuthGate și ROOT
Portare semantică #33 în AuthGate cu `AuthGateSources` păstrat: invalidare sincronă la UID/logout, generație sesiune și profil, verificare SDK currentUser la callbacks/onError, fallback numai same UID. Extinde builderul pentru ownership fără să strici API-urile existente. ROOT Navigator **și** ScaffoldMessenger resetate la schimbarea UID/generației, nu la reconectare same UID. Profile/Home/rute/dialoguri/SnackBar A dispar înaintea datelor B, inclusiv în pending/error. Branding și setările globale rămân; numai preferințele personale se resetează. Lot atomic + standard CI și identity pe SHA.

## Lot 3 — guarduri în Home modularizat
Aplică ownership `sessionIsCurrent`/epoch guard la intrare/după fiecare `await`/înainte de subscribe, write, route, `setState`, post-frame în modulele `home_push_notifications.dart`, `home_live_location.dart`, `home_sync_listeners.dart`, `home_directory_definitions_audit_sync.dart`, `home_financial_sync.dart`, `home_navigation.dart`, păstrând HomePage și porturile din #28. FCM: zero attempted token A/listeners A după B/dispose; GPS: zero late attach/write. Păstrează funcționarea same UID, token payload/owner/merge, GPS thresholds, datele financiare și avansurile nealterate. Nu pretinde că root reset revocă tokenuri deja scrise sau anulează retroactiv commits. Cazurile KNOWN DEFECT direct remediate devin acceptanțe pozitive; celelalte rămân documentate separat.

## Lot 4 — validare completă
Rerulează cele 274+ teste Flutter din #28 și cele 12+8 security adaptate, plus Python/Node/Functions/web, 10 emulator financiar + 5 identity, Dart smoke, protected 116 hashuri. Probe A01–A12/C01–C08 cu matrice PASS/FAIL, dovezi RED→GREEN pe teste nemodificate semantic și CI **5/5 + identity pe SHA final**. Controlează regresiile Admin restore/OCR și same UID. Actualizează concis `ChatGpt`, `docs/MISIUNE_IV_AUTHGATE_REZULTATE_2026-10-14.md` și descrierea PR cu HEAD, job IDs, ce rămâne NEEXECUTAT, checkout clean/sync.

## ATENȚIE — CI manual obligatoriu pe PR cu bază #28
Workflow-urile `.github/workflows/validate.yml` și `.github/workflows/test-identity-lifecycle.yml` au trigger `pull_request: branches: [main]`, deci **PR #35 cu BASE #28 nu le pornește automat**. Ambele declară `workflow_dispatch`. Luna trebuie să le declanșeze explicit pentru branch-ul nou și să citească run SHA/concluzia; de ex. din checkout autentificat:
```bash
gh workflow run validate.yml --ref fix/authgate-on-modular-home-20261014
gh workflow run test-identity-lifecycle.yml --ref fix/authgate-on-modular-home-20261014
```
Dacă nu are acces CLI, folosește GitHub Actions → workflow → Run workflow → branch nou. Dacă dispatch nu funcționează, **STOP cu blocaj clar**, nu pretinde verde. Nu modifica `validate.yml` sau alte workflow-uri protejate, nu schimba baza PR spre main ca scurtătură. Pe RED explică eșecurile acceptanțelor; pe GREEN verifică ambele pe SHA EXACT al HEAD-ului. Niciun CI istoric #28/#33 nu certifică această integrare.

## Stop și predare
**Fără merge/rebase/deploy/release/APK/publicare, Firebase production/rules/config/data, billing, migrare reală, AI plătit sau editări ale altor ramuri.** Nu modifica drepturi/finanțe/START-STOP, parser OCR ori backup în acest lot. Dacă o protecție depinde de schimbări server-side sau de o politică business neconfirmată, documentează și oprește acea subetapă. Nu considera un fake drept probă pe hardware real. La ~15–20% buget nu începe risc major; finalizează și documentează. Dacă toate fazele nu sunt verzi, raportează corect P1 încă deschis pe ramura integrată.

**Următoarele misiuni, numai separat:** backup/migrare fail-closed și idempotency; OCR grouped/TVA/rights Issue #32; integrarea Vision #34 și PDF Million cu verificare combinată. Nu relua loturile #28 deja finalizate.
