# ANDICARPET / VISION — avatar static în antetul diagnosticului, fără deschidere a jurnalului

**16 octombrie 2026 · Shiva · PR Draft separat · fără merge/deploy**

## Scop

AndiCarpet are deja widgetul vectorial `VisionAssistantAvatar` în PR #56, previzualizarea offline pentru tema/dimensiunea în PR #57 și verificările web/Android ale previzualizării în PR #58. Această etapă îl leagă exclusiv vizual de `VisionDiagnosticsPage`, pentru a pregăti noua interfață fără a adăuga funcții AI, diagnostic în fundal sau acces nou la date private.

**Bază:** PR #59 HEAD `f7b523c3375b0137d09911469e3d1f21d0a823c1`. **Luna:** PR #55 MISIUNEA VIII, exclusiv financiar, urmărit read-only. Nu au fost aduse commituri din PR #55.

## Implementare

- `lib/vision/vision_diagnostics_page.dart`: importul stateless `vision_assistant_avatar.dart`, corp vectorial **40 dp** lângă textul exact `Vision` în `AppBar` pentru ambele variante ale ecranului: **fail-closed** (jurnal indisponibil) și log injectat scos dintr-o sesiune autorizată. Nicio altă componentă sau cale de date nu este modificată.
- Elementul este **decorativ/inert** din punct de vedere al accesului: fără gesturi, buton de navigare, clipboard, transport, Firebase, animație sau loguri. Eticheta semantică existentă „Vision, asistent grafic” rămâne accesibilă.
- `test/vision_diagnostics_avatar_header_test.dart`: 4 widget tests ce verifică mesajul de blocare al jurnalului, refuzul de a afișa intrări fără proprietar, dispariția datelor când sesiunea este revocată, refuzul singletonului global chiar dacă callbackul întoarce `true`, semantica și ecranul mic.
- `test/vision_diagnostics_avatar_boundary_test.py`: 3 surse de contract pentru avatar strict în antet, păstrarea gardurilor `_canInspect` și absența accesului extern adăugat.
- `.github/workflows/verify-vision-modular-android.yml`: numai extinderea condiției de rulare pe acest branch, reutilizând testele AuthGate/Vision și `flutter build apk --debug --target lib/main.dart`; fără upload/install/release.

## Bariera UID/epoch existentă, păstrată

`VisionDiagnosticsPage._canInspect` respinge în aplicația reală `log == null` sau `identical(log, VisionErrorTelemetry.log)`, deoarece jurnalul singleton de device este comun tuturor conturilor. Pentru un log injectat distinct este necesar `isSessionCurrent == true` pentru **UID și epoch**, iar excepțiile de check închid accesul. Report copy verifică aceeași condiție înainte/după construire. **Acest PR nu rezolvă izolarea jurnalului singleton per utilizator** și nu pretinde că orice caller poate furniza un log arbitrar sigur: validarea ownership dinamică rămâne contract al callerului. Misiunea de izolarea UID reală va necesita design și teste separate, înainte de afișarea jurnalului principal.

Avatarul este vizibil numai dacă pagina Vision este accesată — această etapă nu o adaugă în Home, nu modifică AuthGate sau Navigator, nu oferă acces la diagnosticul unui cont anterior și nu schimbă semnificația indicatorilor de sănătate.

## Gărzi și limite

- **Fără** editarea surselor financiare/UI Home/ExpensePage/Admin Restore, Firestore rules, date live, Cloud Functions, billing, API, caching, GPS/FCM, OCR ori ajutor AI cu cost.
- **Fără** editarea manifestului `docs/ROUTING_PDF_PROTECTED_2026-10-13.json` (116 SHA) sau a pinurilor `test/vision_hardening_freeze_test.py`. Fișierul `vision_diagnostics_page.dart` nu este inclus în cele 116 de fișiere protejate.
- Zero mișcări ale avatarului, animații sau date noi de telemetry. Corpul nu demonstrează că aplicația este pregătită pentru producție sau că jurnalul poate fi deschis în siguranță.

## CI și handoff

Pe HEAD final, obligatorii: standard 5/5 (Flutter, Python, Node, Firestore emulator, Functions și build web), Identity, Android compile-only cu testele Vision/AuthGate. Workflowurile specifice finanțelor, mascotei offline și browser pot fi **SKIPPED intenționat**, nu PASS. Rezultatele trebuie verificate și raportate exact, fără creditarea unui SHA precedent.

**STATUS: DRAFT / DO NOT MERGE**, niciun deploy/instalare/publicare, fără intervenție pe PR #55.