# Vision — notificare de revocare și închidere vizuală automată

**16 octombrie 2026 · Shiva · PR Draft, independent de Luna PR #55**

## Context și defect

[PR #64](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/64) a validat un adaptor read-only pentru jurnalul temporar, cu 466 Flutter, 209 Python și toate workflowurile active verzi. Totuși, când AuthGate revoca lease-ul fără un rebuild al rutei, ultimul cadru Vision putea rămâne vizibil până la interacțiune. Clipboardul era blocat înainte de copiere, dar fluxul vizual nu era proactiv. Acest lot remediază **numai evenimentele de revocare emise de jurnal**. Nu citește UID sau AuthGate.

## Implementare în ramură nouă

- `lib/vision/vision_session_journal.dart` — subscrieri locale `listenRevocation` strict per epocă, fără dependențe noi. `revoke()` abandonează `_activeLog` înainte de orice notificare, mută listenerii din map înainte de invocare pentru a preveni dublarea/reentrancy, iar o excepție de la UI nu împiedică revocarea. `startSession` invocă `revoke()` înainte de construirea unei noi epoci. Lease-urile vechi nu primesc semnalele altui cont și nu îl pot invalida. Rezultatul subscrierii este o funcție de dezabonare.
- `lib/vision/vision_scoped_diagnostics_page.dart` — `StatefulWidget` care se abonează în `initState`, schimbă abonamentul la o nouă instanță lease în `didUpdateWidget` și se dezabonează în `dispose`. La revocare reconstruiește automat pagina fail-closed; notificarea programează **întotdeauna** un rebuild post-frame prin WidgetsBinding, sigur atât în interiorul, cât și în afara unui build; fără timer/polling și fără import separat de scheduler.
- `test/vision_scoped_diagnostics_page_test.dart` — **6 teste Flutter noi**: logout fără tap/rebuild impus din părinte, tranziție A→B cu pagina veche încă montată și schimbarea lease-ului, dispose-safe, single-shot unsub, listener ce aruncă și vechi lease neautorizat.
- `test/vision_scoped_diagnostics_adapter_contract_test.py` — două teste noi și adaptarea celor existente pentru `StatefulWidget`, verificând revocarea înaintea notificării, ascunderea ecranului și igiena lifecycle.
- Workflow `verify-vision-modular-android.yml` este activat doar pentru acest branch, păstrând `flutter build apk --debug --target lib/main.dart` fără upload/instalare. Alte workflowuri de deploy au rămas intacte.

## Limite obligatorii de comunicat

1. **AuthGate real nu este integrat încă.** Callerul de producție trebuie să invoce `journal.revoke()` sincron la logout/schimbare cont, înainte de a expune noul ecran, și să furnizeze predicate UID + generație. Schimbarea unui bool în closure **fără** `revoke()` nu emite automat notificare; totuși următoarea verificare/blocare fail-closed protejează butoanele și raportul.
2. Rebuildul urmează semnalului de revocare la următorul frame, nu poate șterge instantaneu pixelii deja desenați pe GPU și nu anulează clipboardul deja copiat înainte de revocare. Nu se afirmă că înlocuiește distrugerea/stiva Navigator per user.
3. Fără acces la jurnalul persistent device-wide, fără hooks globale pentru toate erorile, fără logare financiară, fără Firestore, Firebase SDK, stocare, rețea, timer, polling sau servicii cu cost. Niciun fișier Home, ExpensePage, AuthGate, Admin Restore, `firestore.rules`, `main.dart` sau manifestul cu 116 SHA înghețate nu este modificat.
4. Aprobarea pentru merge/deploy nu face parte din acest lot. PR #55 Luna rămâne complet independent.

## CI

Rulează obligatoriu standard 5/5 (Flutter, Python, Functions, Node, emulator, build web), Identity și Android compile-only **pe HEAD final**. Nu credita CI vechi de la #64; dacă un test nou eșuează, reprodu și corectează defectul fără să muți baremul de securitate. Un test pe hardware cu A→B→A2 rămâne pas separat.

**CI:** primul run a semnalat importul nepermis `package:flutter/scheduler.dart` în testul imuabil `vision_hardening_freeze_test.py`. Sursa a fost corectată fără modificarea testului/freeze pinurilor: adaptorul folosește numai `WidgetsBinding` din importul Flutter Material existent și rebuild post-frame. Fixture-urile verifică închiderea după frame-ul programat (`pumpAndSettle`). Rezultatul CI pe HEAD corectat trebuie verificat înainte de verdict.
