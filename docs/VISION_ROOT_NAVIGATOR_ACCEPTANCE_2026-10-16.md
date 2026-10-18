# Vision — probă de izolare a rutei reale Navigator în A→B→A2

**16 octombrie 2026 · Shiva · test-only PR Draft · fără schimbarea aplicației instalate**

## Ce lipsea

PR #66 demonstrează în teste că `AuthGate` real furnizează closure-ul UID + generation și că un `VisionSessionJournal` revocat se golește la schimbarea identității. Dar harness-ul PR #66 montează direct `AuthGate`, nu rădăcina completă `AndiCarpetaApp` care înlocuiește `NavigatorState` și `ScaffoldMessengerState` la schimbarea UID. Fiindcă diagnosticul Vision poate fi deschis într-o rută proprie, este necesar să verificăm și aceasta.

## Implementare exclusiv de test

`test/vision_root_navigator_session_acceptance_test.dart`: trei teste noi construiesc adevăratul `AndiCarpetaApp`, cu fixture-urile `SessionAuth` / `SessionFirestore` existente (Firebase exclusiv simulat). Prin portul deja existent `homeBuilder`, o pagină sintetică, nu Home-ul de producție, poate deschide `VisionScopedDiagnosticsPage` cu un lease temporar. Probe:
1. Ruta Vision deschisă de A1 trebuie să dispară pe schimbarea SDK→B înainte ca B să primească profil; jurnalul A1 nu trebuie citit sau exportat. După deschiderea rutei pentru B și reîntoarcerea la A2, B dispare, A2 primește lease separat.
2. Ruta Vision A deschisă trebuie eliminată la logout; LoginPage nu conține intrările A. Autentificarea ulterioară cu același UID folosește un lease nou, iar callbackul vechi nu poate scrie.
3. Un eveniment temporar `null` din stream, când SDK `currentUser` încă are UID A, **nu** trebuie tratat ca logout și nu trebuie să elimine ruta ori să reinițializeze jurnalul.

`test/vision_root_navigator_session_contract_test.py`: trei contracte statice pentru setupul cu Firebase simulate, protecția reală Navigator/Messenger din `lib/ui/app_root_theme.dart` și matricea de probe negative. Workflow Android Vision existent este extins cu branchul, astfel încât testele să ruleze lângă AuthGate/Flutter și să se compileze `lib/main.dart` în debug fără publicare.

## Limite

- Codul de producție `main.dart`, `lib/ui/app_root_theme.dart`, `lib/auth/auth_gate.dart`, `lib/home/home_page.dart`, `firestore.rules`, Cloud Functions, finanțe și Admin Restore rămâne **byte-identic**. Nu se modifică manifestul cu 116 SHA sau testul imutabil Vision.
- Harness-ul pornește un lease la montarea unei pagini private sintetice și îl invalidează la verificarea ownership/dispose; **nu conectează Vision la Home** și nu promite colectarea automată a erorilor.
- Rezultatele verifică widget tree, Fake Firebase și Navigator într-o suită de teste Flutter, NU efectul traficului nativ pe telefon, secure storage, offline persistence, Android/iOS background sau cote Spark Free în producție. Acestea rămân blocaje reale de release.
- Luna dezvoltă separat Misiunea VIII financiară în PR #55. Nicio modificare, cherry-pick, merge sau comentariu conflictual nu se face în branchul ei.
- Nicio operație Firebase reală, deploy, APK instalat/publicat, billing, AI plătit sau mutare în `main`.

## Validare necesară

Toate joburile CI pe HEAD final: standard 5/5, Identity, Android debug compile-only. Workflowurile finanțe/preview din alte branchuri pot apărea SKIPPED intenționat. Nu declarați verde înainte de dovezi.
