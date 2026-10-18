# AndiCarpet — preview Vision pe Android (CI compile-only)

**15 octombrie 2026 · lot Shiva independent · fără integrare sau producție**

## Context verificat
- PR #56 are corpul vectorial static Vision, deja validat prin 440 teste Flutter, 185 teste Python, Identity, web și Android **pentru entrypoint-ul aplicației normale**.
- PR #57 extinde cu ecranul offline de previzualizare a dimensiunii/temei, HEAD `4ebb32002a1aae454fab67f704a6adf0de98c397`, standard 5/5 cu 446 Flutter și 189 Python, Identity și **web preview** PASS.
- **Lacună explicită:** PR #57 nu a executat un Android build pentru `lib/vision/vision_avatar_preview_main.dart`. Nu presupunem din Android-ul #56 că acest entrypoint alternativ compilează pe Android.
- Luna lucrează în PR #55 la Misiunea VIII financiară Spark. Acest lot **nu schimbă absolut nimic din PR #55**.

## Modificări livrate
1. `.github/workflows/vision-avatar-android-preview.yml` — job condiționat strict de branchul de audit, `flutter test` pentru body și preview, `flutter build apk --debug --target lib/vision/vision_avatar_preview_main.dart`, verificare existență APK și inventar metadate/permisiuni prin `aapt` fără a exporta/aplica/instala artefactul.
2. `test/vision_avatar_android_preview_contract_test.py` — patru contracte statice: target alternativ exact, izolare pe branch, fără publicare/secrete/deploy și inspecție Android fără upload.
3. Acest raport și checkpoint în `ChatGpt`.

## Limite păstrate intenționat
- APK-ul compilat include în continuare configurația și permisiunile native ale proiectului AndiCarpet; **nu îl numim aplicație Android complet lipsită de permisiuni sau de pluginuri**. Doar entrypoint-ul Flutter și interfața preview sunt independente de autentificare/rețea/Firebase, lucru certificat prin testele de sursă din #57.
- Nu există testare pe hardware sau verificare a trafic-ului nativ; `aapt` inventariază doar permisiunile declarate.
- Fără modificări în `lib/`, `main.dart`, App AuthGate, `firestore.rules`, pinii SHA, directorul protejat Grafic/Learning, finanțe, Vision telemetry, assets, `pubspec.yaml` sau configurația de producție.
- `main` este bază exclusiv pentru trigger CI; Draft PR nu se comasează / distribuie / publică. No billing, Blaze, Functions noi, Firestore live, deploy ori Android install.
- Validare finală obligatorie: standard CI 5/5 (inclusiv cele 4 Python noi), Identity, și **workflowul dedicat pentru Android preview** pe același HEAD. Nu reutiliza SUCCESS de pe un SHA anterior și nu raporta Android PASS înainte de rezultat.

## Handoff
După CI GREEN, etapa următoare este verificarea vizuală a aspectului pe telefon și decizia de UX privind amplasarea, fără activarea jurnalului Vision cross-UID. Fișierul pentru testarea locală rămâne `lib/vision/vision_avatar_preview_main.dart`, iar build-ul CI nu creează o versiune instalabilă distribuită.
