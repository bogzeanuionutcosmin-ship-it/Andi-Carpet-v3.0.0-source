# AndiCarpet — audit tehnic al sursei (11 octombrie 2026)

## Metodă și limitări
- Inventar automat al **tuturor celor 301 fișiere urmărite de Git** (45.692.608 octeți), dintre care 173 text citibile; raportul complet este artefactul `repository-audit` al rulării GitHub Actions 38140412575.
- Teste executate: Flutter, contracte Python (29), JavaScript, verificare Firebase Functions și build web. Toate cele patru joburi au trecut la commitul `805973b`.
- Inventarul verifică semnături binare, hash-uri, JSON, importuri relative Dart și referințe explicite către resurse. **Nu dovedește utilizarea reală a fiecărei funcții** și nu include analiză de comportament pe telefon.
- Fără ștergeri, migrații, modificări ale datelor Firestore sau publicare.

## Clasificarea celor 12 avertismente de conținut identic
Toate cele 12 sunt **candidate false-positive**, nu fișiere de șters fără teste de platformă:
1. `android/app/src/debug/AndroidManifest.xml` / `profile/AndroidManifest.xml`: variante pentru build-uri distincte.
2. `android/.../mipmap-mdpi/ic_launcher.png` / `web/favicon.png`: același bitmap, referințe diferite.
3. `android/.../mipmap-xxxhdpi/ic_launcher.png` / `web/icons/Icon-192.png` / `Icon-maskable-192.png`: același conținut, ținte diferite.
4. `ios/Flutter/Debug.xcconfig` / `Release.xcconfig`: configurații pentru moduri de compilare distincte.
5. Patru fișiere `IDEWorkspaceChecks.plist` în iOS/macOS: fișiere de proiect în locații distincte.
6. Două `WorkspaceSettings.xcsettings` iOS: proiect/workspace distinct.
7. `ios/Runner.xcworkspace/contents.xcworkspacedata` / `macos/Runner.xcworkspace/contents.xcworkspacedata`: platforme distincte.
8–9. Iconițe iOS cu rezoluții egale, dar nume/sloturi diferite.
10. Cele trei `LaunchImage*.png` iOS: sloturi de densitate distincte.
11. `macos/Flutter/Flutter-Debug.xcconfig` / `Flutter-Release.xcconfig`: moduri distincte.
12. `web/icons/Icon-512.png` / `Icon-maskable-512.png`: sloturi PWA distincte.

**Decizie:** nu se șterg aceste fișiere. Identitatea octeților nu implică inutilitate.

## Constatări concrete
- `lib/main.dart`: ~798 KB; combină navigație, mesagerie, sticker-e, OCR, cheltuieli, hartă și alte funcții. Riscul de regresie la editare este mare; extragere în module doar incremental, cu teste.
- `assets/stickers/`: 32 fișiere PNG (~5,38 MB), toate referite explicit în `main.dart`. `_andiReactionWidget` folosește `Image.asset`; selectorul și mesajele îl invocă. **Nu sunt fișiere abandonate**. Dacă utilizatorul vede text, trebuie verificată versiunea instalată și încărcarea efectivă a asseturilor.
- `_expenseAmountBani`: expresia regex respingea sume valide din cauza unui dolar literal; corectată în sursă și acoperită de contractul de igienă.
- `test/per_diem_payment_plan_test.dart`: testul confunda avansul contabilizat cu dreptul viitor încă neînregistrat; așteptare corectată, fără modificarea contabilității.
- `test/widget_test.dart`: testul presupunea `worker` implicit, dar `defaultFunctionDefinitions()` definește implicit `admin`; testul aliniat la comportamentul curent.
- `pubspec.yaml` are încă `version: 3.0.1+33`. Versiunea APK trebuie tratată separat de compilările web; nu se modifică arbitrar.
- `.github/workflows/import-v3.0.1.yml` și `setup-source.yml` sunt mecanisme istorice de import, pornite manual; sunt candidate la arhivare/dezactivare, **nu la ștergere automată**.
- `.github/workflows/publish-authorized-release.yml` publică automat doar când se modifică **acel fișier workflow**, sau la declanșare manuală. Modificarea `lib/main.dart` nu publică web automat. `firebase-oidc-deploy.yml` cere `workflow_dispatch` și confirmare `DEPLOY`. Astfel, build verde ≠ web publicat.
- `firebase.json` definește Hosting din `build/web`, reguli Firestore și Functions; sunt componente active, nu resturi.
- `test-firestore-diurna.yml` rulează emulatorul Firestore separat, la modificări ale regulilor/testelor sau manual; **nu este inclus în fiecare rulare** a validării generale.

## Pași următori, în ordine sigură
1. Testare pe telefon/web a stickerelor, OCR, traseelor și meniului lateral, după o publicare controlată a unui commit verde.
2. Integrarea testelor de reguli Firestore în poarta de lansare, fără a porni migrări sau backfill-uri.
3. Verificarea referințelor către fiecare script/workflow istoric și arhivarea lor documentată.
4. Extragerea selectorului de stickere și a parserului financiar din `main.dart`, fiecare schimbare cu teste înainte și după.
5. Verificarea diferențelor dintre versiunea publicată pe Firebase Hosting și sursa din `main`.

**Nu considerați un avertisment de hash duplicat drept aprobare pentru ștergere.**

## Investigație suplimentară: traseul real al diurnei și cele două modele de date
- Auditul importurilor directe arată că `lib/main.dart` **nu importă** niciun fișier din `lib/finance/`. Modulele financiare sunt totuși folosite între ele și de teste Flutter; **nu trebuie șterse**.
- Aplicația principală folosește colecția Firestore `perDiems` (43 apariții ale termenului în `main.dart`). În schimb, `PerDiemFirestoreRepository` din `lib/finance/per_diem_firestore_repository.dart` folosește colecția `per_diem_settlements_v2`, care nu apare deloc în `main.dart`.
- `firestore.rules` conține reguli pentru **ambele** colecții (`perDiems` și `per_diem_settlements_v2`). Prin urmare, există două modele de diurnă în sursă, dar numai primul este legat direct de ecranul principal. Al doilea poate reprezenta un flux în dezvoltare sau unul accesat din alt punct; nu presupunem că este activ în producție.
- `PerDiemConfirmationCard` importă `PerDiemFirestoreRepository`, care importă `per_diem_settlement.dart`. `per_diem_operations.dart`, `per_diem_legacy_adapter.dart` și alte modele sunt acoperite de teste. Acest graf de dependențe justifică păstrarea lor până la o decizie de migrare.
- **Risc de produs:** un test verde pentru `per_diem_settlements_v2` nu dovedește că ecranul real al diurnei, bazat pe `perDiems`, folosește același flux de confirmare. Testele trebuie etichetate după modelul de date.
- Verificarea completă a commitului `4eef412` a trecut: **5/5 joburi**, inclusiv emulatorul Firestore și compilarea Flutter web.
- **Decizie:** fără migrare sau ștergere automată; înainte de unificare sunt necesare inventarierea datelor reale, compatibilitatea regulilor și verificarea fluxurilor de utilizator.

## Regulă de business confirmată de beneficiar — avans diurnă
Utilizatorul a confirmat explicit că **acordarea diurnei în avans este permisă**. În consecință:
- Nu se introduce o regulă care interzice automat `actualReceivedAmount > amount` în fluxul activ `perDiems`.
- Se păstrează separat suma cuvenită, suma efectiv confirmată și avansul rezultat; regularizarea ulterioară nu trebuie să șteargă sau să rescrie confirmările anterioare.
- Testul emulatorului pentru confirmarea unei sume peste cea declarată este o **regresie de business acceptată**, nu o vulnerabilitate de corectat prin plafonare.
- Modelul `per_diem_settlements_v2` are în continuare plafon `receivedBani <= declaredBani`. Dacă acest model va fi conectat în viitor la UI, trebuie clarificată semantica lui (plată punctuală versus soldul total cu avans) înainte de migrare; nu se modifică automat.
