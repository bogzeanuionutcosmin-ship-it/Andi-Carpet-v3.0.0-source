# Plan read-only de portare a testelor PR #33

Sursa #33: a5f43ef9ce0bfedaf59766aafe18732fef7f8f47, fișierele test/auth_session_acceptance_test.dart și test/auth_session_regression_test.dart. Au fost citite cazurile și harness-urile: 12 acceptanțe și 8 controale. Destinația inspectată #28: cod 535f3c52fccb75a9ed79fc4b7d8e0951047e1117, cu porturile Admin și Home/Expense existente. Nu s-a copiat niciun test/guard și nu s-a executat un arbore combinat.

## Reconcilierea harness-ului, într-un mandat viitor

#33 montează AndiCarpetaApp(auth, firestore, settings, homeBuilder) și builderul Home primește sessionIsCurrent. #28 are AuthGateSources lazy/currentUser/authStateChanges/uiSettingsSnapshots/profileSnapshots și activePageBuilder cu două argumente; root-ul nu expune acele porturi. La portare, adapterul trebuie să păstreze cele patru surse existente și fallbackurile SDK, să furnizeze ownership ca al treilea argument și să conecteze onSessionChanged la ROOT Navigator și ScaffoldMessenger. Nu creați un al doilea auth/profile listener și nu reveniți la Home monolitic.

Fixtures Home #28: syncFirestore, maintenanceFirestore, pushFirestore, query ports, HomePlatformEffects. În probele SDK păstrați State-ul real și efectele reale, substituind SDK/data sources, nu întreaga funcție. Fixture-urile security #33 au alte seam-uri SDK/token writer; reconcilierea este explicită, nu o copiere textuală. Admin backupFirestore/backupFiles se păstrează pentru testarea operațiilor administrative, dar #33 nu rezolvă automat restore deja pornit.

## Cele 12 acceptanțe

| ID | Caz existent #33 | Destinație #28 și aserțiune care trebuie păstrată |
|---|---|---|
| A01 | Pending A dispare imediat la B înainte de snapshot | auth/auth_gate.dart + Sources: invalidate profile/ownership sincron; zero nume/email/date A în loading B |
| A02 | Eroare profil B și global settings nu readuc A | AuthGate fallback numai same UID; callbacks Sources și rebuild global nu pot păstra profilul A |
| A03 | Home A și listeners dispuse înainte de profil B | home/home_page.dart, home_sync_listeners, home_financial_sync, directory_definitions_audit: zero listeners/cache financiar A; ordinea normală query ports păstrată |
| A04 | Ruta privată A dispare la B și nu supraviețuiește profilului B | ui/app_root_theme.dart ROOT Navigator keyed + home_navigation; Back nu poate readuce A |
| A05 | Dialog root A eliminat la UID B | Același ROOT Navigator pentru showDialog implicit; zero dialog A după switch |
| A06 | Logout scoate ruta privată și login nu o reînvie | Root reset și generație sesiune, inclusiv logout/login același UID; zero route A din epoca veche |
| A07 | A→B→A ignoră callbacks primei epoci A | AuthGate profile/session generations, nu doar comparație UID; snapshot vechi A nu modifică A nou |
| A08 | Callback personal post-frame nu rulează după owner dispose | Home directory/own-profile și callbackuri settings; ownership verificat la execuția post-frame, zero mutații personale vechi |
| A09 | FCM delayed real nu scrie/atașează după dispose | home_push_notifications: guards după permission, Web700, token, save, initial și înainte de listeners; zero attempted token A și zero late attach |
| A10 | GPS delayed native nu creează subscription după dispose | home_live_location: service/permission/request/cancel gates, boost250 și position/geocoding/write boundaries; zero late subscription/write |
| A11 | SDK UID schimbat și auth-stream error nu păstrează ruta A | Sources.currentUser trebuie să citească SDK curent, nu _user cached; AuthGate onError invalidează root și profile |
| A12 | SnackBar privat root nu trece din A în B loading/Home | Root ScaffoldMessenger keyed împreună cu Navigator; zero snackbar/action closure A, inclusiv queue/post-frame |

## Cele 8 controale de regresie

| ID | Caz existent #33 | Ce rămâne legitim |
|---|---|---|
| C01 | Same UID null/reconnect/profile error păstrează profil și route | Fallback profil valid numai pentru aceeași sesiune; fără reset inutil Navigator |
| C02 | Same SDK UID auth-stream error păstrează fallback | Sources.currentUser și ownership coincid; nu delogați dintr-o eroare temporară |
| C03 | Same UID păstrează preferințe; B resetează numai personale | Globale AppSettings/branding/defaultPerDiem păstrate; tema/font/prefs personale izolate |
| C04 | Home member păstrează scope financiar propriu; B nu vede ledger A | Cele patru scoped subscriptions/cancel/reset din home_financial_sync; zero schimbare formule/avans/rights |
| C05 | Guard devine false înainte de dispose și respinge own-profile queued mutation | Guard propagat din AuthGate la Home; nicio fereastră de mutație între UID switch și Flutter dispose |
| C06 | Active FCM owner token/refresh și cancel la dispose | Payload/merge/owner/ID și o singură atașare; pushFirestore opțional păstrat |
| C07 | Active native GPS attach și cancel normale | Praguri/accuracy/foreground notification/throttling originale; fără fake-success care să certifice hardware |
| C08 | System Back pop normal în aceeași sesiune | Root key stabil same UID; route stack legitim funcțional |

## Transformarea caracterizărilor #28, numai după fix integrat

KNOWN DEFECT profile/Home/route retention și settings/post-frame tardive trebuie convertite în acceptanțe zero date/mutații A. GPS service/permission delay devine zero attach; FCM late-success/refresh după B devine zero token attempts/listeners A. Păstrați controalele pozitive și nu ascundeți eșecul prin schimbarea numelor sau relaxarea așteptărilor.

Migration, restore parțial/duplication/dispose, controller Admin și OCR sunt riscuri distincte: #33 nu le repară automat. O scriere deja pornită/confirmată nu este anulată retroactiv prin root reset. Cazurile acestea necesită mandat funcțional separat, server evidence și probe emulator.

## Suprapuneri și ordine

Ordine propusă viitoare: #33 → structura #28 → #34. Reconcilierea semnăturilor, generațiilor și amplasării guardurilor cere revizuire semantică și CI pe SHA combinat; nu este autorizată aici. Query ports și proiecții pot fi păstrate structural, fără schimbarea drepturilor. Finanțele/START/STOP/avansul și rules/config rămân protejate.

OCR #29 versus #34: conflict parser real, nu doar test text. Cazurile grouped, subtotal/TVA și invalid date trebuie reconciliate semantic. Million există pe #34, hash SHA256 3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23; nu se copiază alt PDF și nu se relaxează manifestul protected pentru a permite merge. Vision handlers se păstrează o singură dată în modulele actuale; source-contracts/hygiene urmăresc amplasarea reală. VisionExpenseSaveVerifier rămâne pur și neconectat; conectarea sa cere UID/epocă, rights Issue32 și dovadă autoritativă server fără cache/pending writes.

Nicio portare, integrare, APK, staging, deploy sau producție nu a fost executată de acest plan.
