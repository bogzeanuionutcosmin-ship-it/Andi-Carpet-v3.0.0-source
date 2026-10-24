# Andi Carpetă / Andi Carpet — v3.0.0 final

Historical internal build: `3.0.0+32`. This archived release note is not evidence for the current candidate.

Current source version metadata is `3.0.1+33` in both `pubspec.yaml` and the in-app version label in `lib/main.dart`. Android Gradle derives `versionName` and `versionCode` from Flutter metadata. A built APK must still be checked for its actual manifest values and digest.

## Ultima regulă funcțională

Mesajul SMS automat inițial către contactele locației nu mai este calculat cu 24 de ore înainte de ETA.
Se trimite în **ziua calendaristică precedentă intervenției**, la ora configurată de Admin în **Admin Panel → Setări sistem → Automatizări & financiar**.
Ora implicită este **10:00** (Europe/Bucharest).

Exemplu: intervenție pe 8 octombrie → mesaj pe 7 octombrie la 10:00.

Dacă data intervenției se schimbă înainte de trimitere, joburile SMS încă neexpediate pentru data veche sunt anulate. Dacă informarea fusese deja trimisă, mecanismul existent de reprogramare trimite mesajul pentru noua dată.

## Curățare efectuată

Au fost eliminate numai fișiere regenerabile sau locale: cache Gradle, `node_modules`, directoare Flutter `ephemeral`, fișiere `.iml`, `local.properties` și metadate/plugin caches generate. Codul sursă, configurările Firebase, regulile Firestore, platformele și asset-urile funcționale au fost păstrate.

Iconurile UI mari au fost redimensionate lossless pentru uzul lor real din interfață, iar un asset duplicat pentru Rapoarte a fost eliminat și reutilizează pictograma Centralizatorului. Badge-urile și stickerele validate au rămas în pachet.

## Android / Kotlin

Proiectul rămâne momentan pe fallback-ul Flutter pentru pluginurile care încă aplică legacy Kotlin Gradle Plugin:

- `android.builtInKotlin=false`
- `android.newDsl=false`

Acesta este setup-ul cu care build-ul release a fost confirmat pe Flutter 3.47.x / AGP 9.x. Nu a fost forțată migrarea Built-in Kotlin în această versiune finală pentru a nu introduce risc înainte de livrare.

## Comenzi după dezarhivare

Din rădăcina proiectului:

```bat
flutter clean
flutter pub get
flutter analyze
flutter build web --release
firebase deploy --only hosting
```

Dacă s-au modificat `functions/index.js` (în această versiune s-au modificat), rulează și:

```bat
cd functions
npm ci
cd ..
firebase deploy --only functions
```

Pentru Android:

```bat
flutter build apk --release
```

APK-ul rezultat va fi în:

`build\app\outputs\flutter-apk\app-release.apk`

Notă: configurația actuală semnează release-ul cu cheia debug, exact ca build-ul validat anterior. Pentru distribuție publică sau update-uri stabile pe termen lung este recomandată o cheie release proprie înainte de prima distribuire definitivă.
