# Home console privacy — caracterizare izolată (15.10.2026)

**Status:** TEST ONLY / KNOWN RED / DO NOT MERGE. Proveniență: PR #46 HEAD `736ef9ea66bec5ff0c431d05808e43423c1f3ba9`; Issue #47. Fără modificări runtime. Acest document descrie *sursa* verificată și nu pretinde capturi de loguri live sau exfiltrare cloud.

## Ce verifică

- `test/home_console_privacy.red.py::test_no_uid_in_push_console` cere absența unui UID interpolat în `debugPrint` din `lib/home/home_push_notifications.dart`. Există un apel cu `$currentUserId` după salvarea tokenului; nici tokenul nu este imprimat explicit de acel apel.
- `test/home_console_privacy.red.py::test_no_raw_sdk_errors_or_stack_in_home_console` cere absența mesajelor brute `$e/$error` și `debugPrintStack` în cele trei surse Home/GPS/FCM/Learning. Nu afirmă că fiecare excepție conține date confidențiale; acest lucru depinde de mesajul SDK.
- Controlul pozitiv `test_positive_vision_reports_still_use_constant_area_and_code` verifică faptul că `VisionErrorTelemetry.report` rămâne bazat pe coduri constante, fără interpolare. **Aceasta nu validează consola Flutter a frameworkului.**

## De ce separate

Jurnalul local Vision nu este egal cu consola Flutter. Handlerul Flutter/SDK poate afișa informații diferite. Prin urmare, un test verde pentru Vision nu demonstrează sanitizarea tuturor logurilor; și o probă statică RED nu demonstrează un incident real în producție.

## CI

Workflow `.github/workflows/home-console-privacy-characterization.yml` rulează explicit controlul pozitiv (trebuie PASS) și **fiecare probă RED în proces separat**, acceptând doar exit 1 și markerul `HOME_CONSOLE_RAW_UID`, respectiv `HOME_CONSOLE_RAW_SDK_EXCEPTION`. Un workflow SUCCESS ar însemna exclusiv că riscurile sunt *reproduse în sursă*, nu reparate. Dacă sursa este corectată, workflowul expected-red trebuie schimbat într-o poartă reală GREEN în PR-ul de fix, fără slăbirea aserțiunilor.

## Fix tehnic propus pentru PR viitor, fără schimbare de comportament operațional

1. Înlocuire minimă, deterministă, a mesajelor Home controlate de aplicație cu coduri fără date brute; fără duplicarea `VisionErrorTelemetry.report` sau eliminarea informațiilor utile pentru depanare autorizată.
2. Păstrarea completă a condițiilor `_sessionActive`, autorizării, retry/FCM subscriptions, GPS, Learning și callbacks. Nu adăugați rețea, upload automat, secret, nor/API plătit.
3. Este obligatoriu review al protecțiilor: `test/vision_hardening_freeze_test.py` conține SHA-256 frozen pentru cele trei module; `test/vision_operational_diagnostics_contract_test.py` verifică explicit un mesaj raw GPS în cadrul contractului istoric. **Nu ștergeți sau dezactivați global freeze/checkurile** doar pentru a trece CI. Într-un PR de fix, actualizați strict contractele afectate, cu comparație old/new, probele RED→GREEN și audit al impactului.
4. Standard 5/5, identity, integrare Android+Chrome și teste fake (captură `debugPrint` cu evenimente SDK sintetice) înainte de aprobarea eventualului merge. Nu revendicați hardware sau producție neexecutate.

**Separare:** Misiunea VII (Issue #48) / Luna schimbă doar dialoguri financiare, nu logging Home. PR-ul de față nu este integrare cu Luna. Niciun fișier existent nu a fost schimbat pe ramură; fără merge, deploy, APK/web release, Firestore, migrări sau billing.
