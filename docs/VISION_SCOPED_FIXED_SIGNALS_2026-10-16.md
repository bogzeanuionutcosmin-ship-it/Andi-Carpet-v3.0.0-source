# Vision — semnale anonime tipizate și închise la revocarea sesiunii

**16 octombrie 2026 / Shiva / Draft independent.** Bază: PR #71, HEAD `ff13d20bb5879ab106fe19c9923edc9bb47f7533`, standard 5/5, Identity și Android compile-only SUCCESS. Luna lucrează separat în PR #73 / Issue #72; acest lot nu atinge finanțele.

## Problemă rezolvată la interfața nouă

Modelul existent `VisionErrorLog` acceptă și normalizează coduri de forma `[a-z][a-z0-9_]*`, dar acest regex **nu dovedește** că un șir nu conține un identificator sensibil (ex. un UID sau o sumă transformată în șir compatibil). Producătorii viitori nu trebuie să trimită `exception.toString()`, date din GPS/OCR, tokenuri sau valori financiare nici dacă trec filtrul sintactic.

`lib/vision/vision_scoped_signal_sink.dart` adaugă un port pur Dart, strict opt-in:
- `VisionDiagnosticSignal`: catalog finit cu **arie, cod și severitate constante** pentru auth, gps, ocr, fcm, map, sync, finance și storage Vision. Un signal `financeOperationUncertain` este doar diagnostic, **nu** confirmare, respingere sau retry financiar.
- `VisionSignalPlatform`: platforme codificate ca enum, fără user-agent, model telefon sau alte metadate.
- `VisionScopedSignalSink(lease).emit(signal, platform: ...)`: emite exclusiv prin `VisionSessionJournalLease`, verifică dreptul epocii înaintea înregistrării și refuză după logout/revocare/throw. Nu salvează lease-uri global și nu importă `VisionErrorTelemetry.log`.
- Nu există parametru `String message`/`error`/`rawData`, serviciu Firebase, tranzacție, transport, timer, cache persistent sau mecanism AI. Gruparea, limita de intrări/bytes și retenția folosesc numai `VisionErrorLog` existent.

Acest port nu face automat toate produsele callerilor sigure: un producător poate încă utiliza API-ul legacy `lease.record` direct. La conectarea fiecărui modul operațional, codul său trebuie auditat și să treacă exclusiv prin noua interfață pentru evenimentele aprobate; nu conecta handlerii globali ai jurnalului de instalare. Această modificare **NU colectează încă erori de pe dispozitive reale** și **NU expune Vision în Home implicit**.

## Probe, rezultate și limitări

- `test/vision_scoped_signal_sink_test.dart`: verifică toate codurile și platformele, agregarea a 10.000 de semnale identice fără 10.000 intrări, maxEntries/maxBytes, A→B→A2, predicat care aruncă, revocare monotonă, retenție 7 zile fără timer, plus widget integrat cu bridge-ul AuthGate PR #71.
- `test/vision_scoped_signal_sink_contract_test.py`: cinci controale statice, strict suplimentare testelor executabile, pentru lipsa transportului/storage, importuri permise, API de tip enum și proprietatea sesiunii.
- Android compile-only este activat pe ramura nouă; workflowurile legacy condiționale SKIPPED nu sunt considerate PASS.
- **Gates:** Standard CI 5/5, Identity, Flutter/widget, Android debug compile-only, manifest 21 pini / 116 fișiere protejate. Confirmați numai pe HEAD-ul publicat.
- Lipsesc intenționat: integrarea efectivă cu producerii GPS/FCM/OCR, AuthGate real în Home implicit, monitorizarea background pe hardware, raportare multi-dispozitiv, persistență de sesiune, securitatea server pentru consola Developer și validarea arborelui combinat Luna+Vision. Issue #63 rămâne deschis.

**Cost incremental al acestui port:** zero Firestore reads/writes, AI API, polling, cloud sau billing. **production_ready=false.** Fără merge, deploy, Firebase live, modificări hashurilor protejate, date reale sau APK distribuit.
