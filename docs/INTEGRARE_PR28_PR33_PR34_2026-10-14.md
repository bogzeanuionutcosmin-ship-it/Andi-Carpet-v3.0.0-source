# Audit de integrare — continuarea misiunii 6163825575

## Snapshot verificat, numai read-only

PR #28: **8ae3b4c4f51c7d2385a72a0ef9bbe6ab9aadd342**, lot27 de cod/teste verde. PR #33: **a5f43ef9ce0bfedaf59766aafe18732fef7f8f47**. PR #34: **4fea0e8e2b488e880cae9e430dd2bccfd4487fb7**, ramură activă în altă sesiune. PR #29: **545e0202755a8ee86a7b3406adccd469aac84f9e**. Main: **377f1fd5e73ae78a0df5cab58b09770c873cd167**. SHA-urile #34 trebuie reverificate la reluare; niciun avans extern nu este atribuit acestei misiuni.

Auditul precedent: comentariul 6163337665. Misiunea curentă interzice orice integrare sau schimbare a ramurilor sursă. Recomandarea viitoare **#33 → #28 → #34** este păstrată, fără merge/cherry-pick/rebase în această sesiune.

`git merge-tree --write-tree --name-only` a simulat perechile la SHA-urile de mai sus. Exit1 pentru fiecare; sunt numai obiecte Git temporare locale, fără commit sau mutare ref de integrare.

| Pereche | Fișiere cu conflict Git confirmat |
|---|---|
| #28 / #33 | ChatGpt; lib/auth/auth_gate.dart; lib/home/home_page.dart |
| #28 / #34 | ChatGpt; lib/expenses/expense_page.dart; lib/home/home_page.dart; lib/main.dart |
| #33 / #34 | ChatGpt; lib/home/home_page.dart |
| #29 / #34 | lib/ocr_parser.dart |

`validate.yml`, `repository_hygiene_test.py` (#28/#34) și `ocr_parser_test.dart` (#29/#34) se combină textual în aceste simulări. Nu rezultă de aici compatibilitate semantică sau CI pentru un arbore combinat. Proiecția Admin adăugată în lot26 nu introduce un nou conflict cu #33/#34.

## Matrice de portare pentru viitoarea integrare autorizată

| Destinație reală #28 | Protecție/dependență #33 de păstrat la reconciliere |
|---|---|
| lib/auth/auth_gate.dart | invalidare sincronă profile/profileUid/ownership la UID schimbat/logout; generațiile profile/sesiune; currentUser SDK la callbacks și auth onError; fallback numai same UID; reset numai preferințele personale |
| lib/auth/auth_gate_sources.dart + adaptorul din main | păstrează sursele lazy #28; reconciliază auth/firestore injectate #33 cu sources/activePageBuilder. Builderul security are al treilea argument ownership; nu crea un al doilea flux de auth/profile |
| lib/ui/app_root_theme.dart | ROOT Navigator ȘI ScaffoldMessenger recreate la UID nou/logout; onSessionChanged; branding/global settings păstrate. Fișier fără conflict nu înseamnă că poate fi omis |
| lib/home/home_page.dart | sessionIsCurrent capturat de AuthGate; `_sessionActive`; callback setări programat cu reverificare; constructorii sync/maintenance/query/platform ports existenți, init order și dispose/cancel |
| lib/home/home_push_notifications.dart | guards la popup/post-frame/deschidere chat; SDK seam și token owner; checks după permission/delay700/getToken/saveToken/getInitialMessage, înainte de attach; nu reintroduce metodele în HomePage |
| lib/home/home_live_location.dart | verificări la intrare și după service/permission/cancel/position/locality awaits, înainte de stream attach/write; delay250 reintră prin funcția guardată; păstrează pragurile, foreground indicator și throttling |
| lib/home/home_sync_listeners.dart | ownership la deliveries operaționale/chat/notification/settings și callbackurile post-frame; păstrează query ports și ordinea core |
| lib/home/home_directory_definitions_audit_sync.dart | ownership directory/own profile/definition/audit callbacks; role-based query paths și fallback; post-frame settings fără A după dispose |
| lib/home/home_financial_sync.dart | ownership delivery/error; patru scoped subscriptions/cancel/reset; zero schimbare formule/advance/query/filter/server rights |
| lib/home/home_navigation.dart | rutele rămân sub granița ROOT; callbacks și mark-read/context checks nu readuc A. Root reset nu substituie autorizarea server sau anularea retroactivă a unei scrieri |

Testele #33 de acceptanță + controale (20 noi, 12 acceptanțe) trebuie adaptate la API-ul modularizat, fără slăbirea assertions. Fixture-urile security Home folosesc parametri SDK diferiți de syncFirestore/platformEffects/query ports #28; ele nu se copiază fără wiring verificat.

## Registrul caracterizărilor care trebuie reevaluate numai după integrare

- `auth_gate_identity_characterization_test.dart`: trei scenarii KNOWN DEFECT profile/Home/route retention; rapid switch control se păstrează.
- `home_sync_lifecycle_characterization_test.dart`: State Home A viu până la profil B; celelalte controale lifecycle/scopes se păstrează.
- `home_settings_lifecycle_characterization_test.dart`: preferințe A comune, post-frame după dispose/mount B și startup injectat întârziat; globals/clamps/reconnect legitimate se păstrează.
- `home_platform_sdk_characterization_test.dart`: GPS real cu platform fake poate atașa după dispose. Este acum dovadă runtime sintetică, nu doar portul HomePlatformEffects. Testul se transformă în acceptanță zero late attach pe ramura combinată, nu acum.
- `home_admin_maintenance_characterization_test.dart`: maintenance in-flight, destructive badge_v2 și backup failure sunt riscuri distincte; #33 nu le repară automat. Nu schimba aceste așteptări doar fiindcă root UI este izolat.

## Hook-uri Vision și diferențe funcționale

| Hook-uri #34 | Module #28 după separare |
|---|---|
| FCM initialization_failed/token_refresh_failed | home_push_notifications.dart |
| GPS background_start_failed/background_stream_failed/location_update_failed | home_live_location.dart |
| per_diem sync_failed | home_financial_sync.dart |
| received_amount_save_failed | expense_settlement_actions.dart |
| acknowledge_failed/supplementary_save_failed/distribution_save_failed | expense_per_diem_actions.dart |
| automatic_recognition_failed/recognition_failed/document_save_failed + UI OCR prudent | expense_document_actions.dart |
| telemetry init/global handlers/startup critical | main.dart, păstrând bootstrap independent și handlerii existenți |

Păstrează fiecare hook o singură dată, în catch-ul real, fără raw payload și fără pierderea guard-urilor de sesiune. `vision_operational_diagnostics_contract_test.py` caută încă amplasările monolitice; trebuie să verifice modulele reale, nu să oblige revenirea la monolit. Manifestul de hashuri protejează șase fișiere schimbate de #34 (validate, documents, download implementations, OCR/parser tests): reconcilierea necesită justificare și dovezi, nu dezactivarea protecțiilor.

Vision #34 conține #21 și antecedente #19, documente/PDF și modificări OCR. Nu integra aceleași commituri de două ori. HEAD #20 și #29 nu sunt automat absorbite ca ancestrie. #29 respinge date imposibile prin comparația componentelor DateTime; #34 păstrează în parser normalizarea DateTime din bază și schimbă selecția totalurilor la total etichetat/ambiguitate/refuz. Datele fiscale invalide și totalurile TVA/PLATA trebuie reconciliate și testate; merge textual al testelor nu certifică produsul.

Million din arborele #34 are SHA256 **3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23**. Assetul Million nu există încă în #28; nu s-a copiat acum. Cele 116 hashuri #28, inclusiv Magic și finanțe/rules/config, sunt intacte.

Verificatorul pur `VisionExpenseSaveVerifier` rămâne neconectat la ExpensePage/Firestore. Necesită UID/generație din #33, drepturile financiare Issue #32, ID/team/settlement exact, read autoritativ fără cache/pending writes și teste emulator/device. Nicio citire sau retry nou nu este introdus aici.

#34 adaugă față de primul audit starea locală de persistență și prioritizarea rezumatelor. Cheia logului este device-wide, nu per UID; 150 entries/48KiB/7 zile. Storage failure/queued revision/sanitizare și schimbarea contului necesită probe combinate. Nu echivala statusul local cu sănătatea backend.

## CI și probe rămase

Pe snapshotul #34 inspectat, cele trei workflow-uri Android full-app/documente/Vision sunt SKIPPED prin head_ref; offline smoke este separat. CI standard pentru snapshotul #34 a fost CANCELLED la avansul extern; acest raport nu așteaptă și nu declară verde acel HEAD. Offline smoke nu exercită AuthGate/Home/Firebase. Niciun APK nu a fost pornit sau publicat de această misiune.

Pentru un viitor SHA combinat: Flutter suite complete/build web/smoke Dart, Python boundaries/contracts, Node, Functions, financial și identity emulator; A→B pending/error/null/ABA/logout/auth SDK error, routes/dialog/SnackBar/Back, settings globale vs personale, GPS/FCM după fiecare await și UID ownership, duplicate listener/cancel, OCR/monetary1ban/avans, PDF hashes/download/share, redacție și persistență Vision. Probele hardware/cache/reconnect/live se fac separat numai într-un mediu autorizat.

**Nicio integrare nu a fost executată.** Următoarea sesiune reverifică toate SHA-urile, mai ales #34 activ în paralel, și urmează mandatul nou primit.
