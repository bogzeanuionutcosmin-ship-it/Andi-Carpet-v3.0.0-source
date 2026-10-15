# Vision — previzualizare vizuală offline, numai pentru dezvoltare (15.10.2026)

## Obiectiv și bază

Proprietarul AndiCarpet a cerut să construim întâi **corpul mascotei Vision**, să îl putem testa și doar apoi să alegem mișcările. În [PR #56](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/56) HEAD `80571d79d5c9d3ff3d45ccb81d67bf337e4b59be`, corpul vectorial este static și validat: standard 5/5, Identity și Android compile-only SUCCESS.

Această etapă nouă, independentă de finanțele Lunei [PR #55](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/55), oferă **o aplicație de previzualizare opt-in, doar pentru dezvoltare**, din același cod al corpului. Nu deschide Vision Diagnostics sau datele altui cont și nu face parte din rutarea normală a utilizatorilor.

## Fișiere noi

- `lib/vision/vision_avatar_preview_app.dart`: ecran complet offline `VisionAvatarPreviewApp`, cu switch de temă light/dark și alegere de dimensiune 64/112/176 dp. Vizualul rămâne exclusiv `VisionAssistantAvatar`, nu o implementare separată duplicată.
- `lib/vision/vision_avatar_preview_main.dart`: **entrypoint separat**, pentru build explicit `--target` — `lib/main.dart` rămâne intact.
- `test/vision_avatar_preview_app_test.dart`: 5 teste widget pentru lansarea fără diagnostic, light/dark, dimensiuni, layout compact portrait/landscape și lipsă butoane/fluxuri de date.
- `test/vision_avatar_preview_boundary_test.py`: 4 contracte de sursă: importuri limitate, entrypoint opt-in, fără Firebase/telemetrie/rețea/timer/navigare și producție `main.dart` fără acest preview.
- `.github/workflows/vision-avatar-offline-preview.yml`: compile-only pentru Flutter web target separat, plus testele de avatar, **fără upload-artifact, deploy, signing sau billing**.

Nu există plugin nou, asset descărcat, Firebase query, VisionErrorLog, UID, date private, animație, gesturi de asistent, procese/timere în fundal. Butoanele de temă și dimensiune schimbă **exclusiv modul în care arată previzualizarea**, nu acțiunile aplicației.

## Cum se verifică local, în mod explicit

Dintr-un checkout Flutter autorizat pentru dezvoltare:

```sh
flutter pub get
flutter test test/vision_assistant_avatar_test.dart test/vision_avatar_preview_app_test.dart
flutter run -t lib/vision/vision_avatar_preview_main.dart
```

Pentru verificare statică web, fără publicare:

```sh
flutter build web --release --target lib/vision/vision_avatar_preview_main.dart
```

Aceste comenzi sunt **doar pentru medii de test**, nu instalare/publicare automată pe telefonul proprietarului. CI compilează și verifică existența `build/web/index.html`, fără să încarce artefactul pe server. Nu afirmăm vizualizarea reală pe hardware, precizia culorilor sau animații testate.

## Criterii de acceptare și limite

1. CI standard 5/5, Identity, noul workflow offline (test+build) și verificarea că `lib/main.dart` este nemodificat, toate pe **HEAD exact**.
2. Previzualizarea folosește numai corpul comun și nu poate vedea jurnalul de instalare care trebuie să rămână **fail-closed** până la proiecție UID/epoch.
3. Nu se actualizează `firestore.rules`, calcule financiare, permisiuni, surse protejate/hashuri sau PR-urile #50/#55/#56.
4. Cu răspunsul proprietarului despre aspect putem îmbunătăți corpul și apoi decide **unde este afișat** în aplicația autenticată și ce animații sunt justificate de UX/baterie. Nu activăm această componentă pentru toți utilizatorii implicit.

**Garanții neacoperite:** scannerul Python este lexical, nu un audit al pluginurilor/OS; build web în CI nu dovedește experiența unui dispozitiv real. Acest lot nu repară finanțe #53, ACL #32, sau cele 4 mesaje KNOWN UNSAFE din routing. Fără merge/deploy/APK/web publicat, date live ori servicii plătite.
