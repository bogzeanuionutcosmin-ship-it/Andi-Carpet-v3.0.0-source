# Vision — coordonator local pentru ciclul de viață al sesiunii

**16 octombrie 2026 · Shiva · lot separat și fără intervenție în PR #55**

Bază: PR #65 HEAD `f5594834e3ff44c7bdc4558b2de49cc461582238`, CI standard 5/5, Identity și Android SUCCESS. Înainte de modificare au fost recitite `ChatGpt`, `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` și `ARHITECTURA_VISION_ULTRON_JARVIS_ZERO_COST.md`. Sursa `lib/auth/auth_gate.dart` are deja callbackul `sessionIsCurrent()`, care verifică UID și `_sessionGeneration`, transmis prin `activeSessionPageBuilder` sau Home.

## Livrare

- `lib/vision/vision_session_lifecycle_coordinator.dart`: port pur Dart, fără backend/UI. `replaceSession(isSessionCurrent: ...)` creează o epocă și invalidează lease-ul anterior chiar dacă același UID revine; `clear()` invalidează imediat la logout/root swap; `dispose()` invalidează idempotent și împiedică reactivarea; `activeLease` verifică live predicate-ul autoritativ.
- `test/vision_session_lifecycle_coordinator_test.dart`: 8 teste pentru A1→B→A2, același UID/generație nouă, revocare și notificare, invalidare externă la următoarea verificare, callback throwing, dispose idempotent, listener defect, lease învechit.
- `test/vision_session_lifecycle_coordinator_contract_test.py`: 4 contracte privind importuri exclusiv Vision, absența Firebase/HTTP/timers, revocare și existența callbackului UID+generation în AuthGate.
- Extinderea condiției workflow Android compile-only numai pe branchul dedicat; fără semnare, upload, instalare sau publicare.

## Limite și gates

Acest port **NU este încă montat în AuthGate/Home** și NU tratează automat schimbările de cont. Integrarea viitoare trebuie să apeleze `replaceSession` în rădăcina autorizată cu predicate-ul UID+generation al epocii corecte și `clear()` sincron la logout/switch, înainte de resetarea Navigator; nu se folosește un closure UID-only sau `() => true`. Schimbarea callbackului în afara acestui contract este observată doar la următorul acces. Jurnalul existent de instalare rămâne blocat pentru UI, iar portul RAM nu interceptează automat erorile operaționale.

Fără modificări în `lib/auth/`, `lib/home/`, finanțe, Admin Restore, `firestore.rules`, functions, Firestore de producție, manifestul celor 116 SHA sau hashurile Vision. Cost incremental Firebase zero. Luna continuă PR #55 independent.

Pe HEAD final: standard CI 5/5, Identity, Android compile-only și testele Flutter + Python trebuie confirmate. **DRAFT/DO NOT MERGE, fără deploy sau publicare APK.**
