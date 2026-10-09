# iOS Firebase / APNs – activare finală

Codul Flutter este pregătit pentru iOS, inclusiv Firebase Auth, Firestore, FCM, OCR ML Kit și locație în background.
Bundle ID-ul actual al targetului Runner este `com.example.andiCarpeta` și trebuie folosit identic când se înregistrează aplicația iOS în Firebase.

## Varianta A – recomandată pe Mac
1. În Firebase Console → Project settings → Your apps → Add app → iOS, înregistrează `com.example.andiCarpeta`.
2. Descarcă `GoogleService-Info.plist` și configurează-l în Runner prin FlutterFire CLI/Xcode.
3. În Apple Developer / Xcode activează Push Notifications și Background Modes → Location updates + Remote notifications.
4. În Firebase Console → Cloud Messaging încarcă cheia APNs a contului Apple Developer.
5. Rulează `flutter build ios --release` pe un Mac cu Xcode.

`main.dart` detectează automat iOS fără dart-defines și lasă Firebase SDK să citească `GoogleService-Info.plist`.

## Varianta B – FirebaseOptions prin dart-define
După ce aplicația iOS este creată în Firebase, se poate construi fără modificarea fișierului Dart:

flutter build ios --release \\
  --dart-define=FIREBASE_IOS_API_KEY=CHEIA_IOS \\
  --dart-define=FIREBASE_IOS_APP_ID=APP_ID_IOS \\
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.example.andiCarpeta

Project ID, sender ID și storage bucket sunt deja în `firebase_options.dart`.

## Observație Apple
Push-ul real pe iPhone necesită obligatoriu configurarea APNs/semnarea Apple. Aceste credențiale sunt emise de Apple/Firebase pentru contul proprietarului și nu pot fi generate din sursa aplicației.
