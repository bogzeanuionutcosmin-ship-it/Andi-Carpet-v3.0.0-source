# Home Console Privacy — remediere tehnică izolată, 15.10.2026

**Scope:** GitHub Issue #47, dovezi originale în PR #49. Bază PR #49 HEAD `586a5a1cf38c1e251ce1034b20b9b27617dc8855` (derivată din PR #46 `736ef9e`). PR de remediere **DRAFT / DO NOT MERGE**. Nu modificați ramurile #46/#49/#41/main, datele de producție, financiarul sau Firestore rules.

## Diferența tehnică

Au fost înlocuite **numai** mesajele de consolă controlate de aplicație, în trei module:
- `home_page.dart`: excepțiile brute la backup/mentenanță și salvarea Learning devin `[home] maintenance_failed`, respectiv `[learning] save_event_failed`.
- `home_live_location.dart`: 4 interpolări `$e` din stream/background, reverse geocoding și update devin coduri constante `background_stream_failed`, `background_start_failed`, `reverse_geocoding_failed`, `location_update_failed`.
- `home_push_notifications.dart`: UID-ul brut dispare din mesajul de succes FCM, `$error` și `$e` devin coduri constante, iar dump-ul explicit `debugPrintStack(stackTrace: st)` este omis din consola de aplicație. `VisionErrorTelemetry.report` și codurile sale sunt intacte.

Înlocuirile nu introduc rețea, stocare, permisiuni sau retry; nu au fost schimbate apelurile reale `FirebaseMessaging`, `Geolocator`, `Firestore`, `_sessionActive` sau efectele asupra utilizatorului. Nu garantăm sanitizarea stackurilor emise de Flutter/SDK independent de aplicație și **nu** pretindem capturi pe hardware.

## Freeze: exact 3 excepții controlate, fără bypass

`test/vision_hardening_freeze_test.py` continuă să verifice hash SHA-256 pentru toate fișierele sale. **Doar cele trei hashuri ale fișierelor intenționat modificate** au fost actualizate, cu comparație de sursă înainte/după. Nu există dezactivare globală sau exceptarea vreunei alte funcții.

| Modul | SHA-256 anterior | SHA-256 fix |
| --- | --- | --- |
| `lib/home/home_page.dart` | `377c30d302bf1d8352f8d14edff1fb424808603859ff1853ba1385bfd3f4adcf` | `6188a3b7ef72e4ca3cf9d903d9a33173fd2d0f37b33c7e28abae3ff6eaea00a6` |
| `lib/home/home_live_location.dart` | `47124a8f8b03ffd9cd05063bc7c7807d0f0365f17a70151052efc50ccc474595` | `5c19d853c71cf6eb07c2d3e02e279faa631d728c0a8fcc9ae7e983fc6a9c9695` |
| `lib/home/home_push_notifications.dart` | `7468d0dd5b5e2ae15a18a79f4d41f74829095a31636261a95a2fd6ddefa3851f` | `1b76637e9e11110eaeb1f5b7d64dc8bec53fa0799c4d1bc3db08d08586d91566` |

Contractul istoric `test/vision_operational_diagnostics_contract_test.py` care **pretindea explicit un mesaj GPS cu `$e`** a fost schimbat punctual să pretindă noul cod constant. Celelalte assertions despre hooks, securitate, Vision, OCR și diurnă sunt neschimbate. Testele de source RED din #49 sunt păstrate cu aceleași aserțiuni și sunt cerute **GREEN** în workflowul ramurii fix; normal-discovery baseline guard refuză creșterea numărului de loguri brute.

## Verificări și limite

- Inspectarea lexicală directă după fix: **0** apeluri `debugPrint` cu UID brut și **0** apeluri `debugPrint/debugPrintStack` cu `$e/$error` sau stack brut în cele trei module vizate (față de 1+9 pe baza #46).
- Testele PR #49 sunt caracterizare read-only; aici source contract este conceput să devină o acceptanță GREEN reală.
- Rezultatul CI standard/identity/Android trebuie citit pe **ultimul HEAD** înainte de orice verdict. Dacă un job rămâne Pending/Skipped, raportați explicit. Hardware, consola OS în release, Firebase live și autentificarea reală sunt **NEEXECUTATE**.
- Nu există încă dovadă de absență totală a datelor sensibile în alte fișiere Flutter sau în logurile SDK/OS: scope este limitat la cele trei module inspectate.

**Fără merge/deploy/publicare APK/web, date/chei/finanțe/rules, billing sau AI plătit.** Acesta este un PR tehnic pentru review, nu release.
