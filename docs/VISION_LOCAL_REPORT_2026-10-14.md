# Vision — raport local de diagnostic opt-in (14.10.2026)

**Stadiu:** ramură de probă pentru Vision V0/V0.5, derivată din PR #21 la SHA `d18b2523a31ead7eb65a04fe92a21276a4155c97`. Nu este merge, deploy, release sau aplicație complet integrată cu AuthGate #33/modularizare #28.

## De ce
Vision V0 din PR #19/#21 înregistrează deja sumarizat erori Flutter/async și incidente GPS, FCM, OCR, diurne. Până acum diagnosticul putea fi consultat doar pe telefon. Pentru a putea analiza incidentele din testele manuale fără acces la Firebase și fără cost AI, am adăugat **copiere explicită a unui raport tehnic local**.

## Codul adăugat
- `lib/vision/vision_diagnostic_report.dart`: formatează numai zona/codul/platforma/severitatea/timpul/numărul de repetări/starea, cu verificarea din nou a identificatorilor, limită de **100 intrări** și **16.000 caractere**.
- `lib/vision/vision_diagnostic_advisor.dart`: **primul mecanism determinist read-only din nucleul Vision**. Prioritizează incidentele deschise după severitate și recență, prezintă explicații fixe pentru codurile deja instrumentate OCR/GPS/FCM/finanțe/diurne și recomandă doar verificări manuale, fără mutarea datelor sau presupunerea cauzei exacte.
- `lib/vision/vision_diagnostics_page.dart`: afișează recomandarea cu cea mai mare prioritate într-un card discret, fără animații sau notificări noi; rămâne UI local.
- `lib/vision/vision_diagnostics_page.dart`: buton `Copiază raport tehnic anonimizat` cu Clipboard **numai la gestul utilizatorului** și mesaj de confirmare/eroare; fără upload, SDK extern, permisiuni, costuri sau Firestore.
- Teste noi de interpretare: incidente deschise/rezolvate, priorități, OCR salvat/eșuat, fallback pentru coduri necunoscute, limite maxime și lipsa efectelor secundare. Testul widget verifică recomandarea și absența acesteia când incidentele sunt rezolvate.
- Teste Dart/unitate și widget pentru jurnal gol, 10.000 evenimente identice, câmpuri neacceptate, limitare de raport, absența copierii automate și Clipboard la apăsare.
- Workflow-ul offline existent verifică și testele raportului, pe o ramură izolată, fără Google Services/INTERNET/GPS/cameră, cu identificator de pachet distinct. Nu este un build al aplicației autentificate.

**Nu au fost modificate** `VisionErrorLog`/serializarea/TTL, PDF-urile, modelul financiar, Android release config, `main`, codul AuthGate #33, #28, #29, rules/config/date Firebase producție, billing ori versiunea.

## Atenționări importante
- Clipboard este gestionat de sistemul de operare și poate rămâne accesibil în istoricul său. Raportul nu trebuie copiat sau trimis pe un dispozitiv nesigur; utilizatorul verifică datele înainte de distribuire.
- Codurile tehnice sunt limitate lexical, însă **un jurnal nu poate detecta automat orice bug silențios**. La OCR, salvarea unei sume greșite dar fără eroare necesită verificarea rezultatului final, nu doar `catch`.
- Raportul reflectă doar **acest dispozitiv** și intervalul de retenție al jurnalului. Nu există centralizare multi-dispozitiv, ChatGPT online 24/7, self-healing financiar sau monitorizare cât aplicația este oprită.
- APK-ul rezultat din workflow este numai pentru testul offline Vision/PDF, **nu** este APK-ul actualizat al aplicației de lucru; testarea reală a integrării va fi un pas separat după remedierea AuthGate și contractele financiare.
- PR #21, #19 și munca Lunăi (#33) rămân nemodificate.

## Acceptanță
1. CI standard toate cele 5 joburi verde pe SHA al PR de probă.
2. Workflow-ul `Offline smoke APK - separate install, no Firebase` verde, identificator unic și permisiuni interzise absente.
3. La test pe telefon: `Vision → Test local → Copiază raport`; raportul trebuie să conțină `vision_test/persistence_probe`, număr apariții și timestamps, fără date personale. După repornire, evenimentul test rămâne în jurnal.
4. Butonul de copiere nu declanșează transmitere către server. Niciun APK nu este distribuit ca release.
5. După rezultatele CI se actualizează concluzia, fără a declara fals misiunea completă.

## Etapa ulterioară
După PR #33 RED→GREEN și evaluarea #28/#29, creare ramură **distinctă de integrare** a Vision V0.5 cu codul modularizat, OCR, documente și securitatea UID, teste Android/web reale, fără merge/deploy înainte de aprobare. Vision avansat — motor de reguli, Learning GPS, START idempotent, DND, diagnostic centralizat opt-in — rămâne separat.

## Lot suplimentar — explicații Vision înainte de avatar

Proprietarul a confirmat că avatarul (salut, dans, gesturi amuzante) se decide și implementează **după nucleul funcțional**. Decizia completă este salvată în Issue #30. Acest lot dezvoltă exclusiv logica read-only, fără elemente grafice noi în afară de cardul de explicație; niciun LLM/cloud/cost API.

**Limită esențială:** un incident din jurnal poate declanșa o recomandare de verificare, dar nu confirmă că respectiva operațiune a eșuat definitiv sau că lipsesc alte buguri. Nu se efectuează reîncercări automate financiare, START/STOP, modificări de permisiuni sau sincronizare suplimentară. Observațiile silențioase fără excepții necesită integrare explicită ulterioară cu fluxurile reale.

**CI pentru lotul nou:** rezultatele se vor trece în PR după validare. Nu confundați validarea precedentă pentru SHA `2995637e` (5/5 standard + Android offline SUCCESS) cu verificarea commiturilor suplimentare.

## Lot nou — clasificarea repetițiilor fără estimări false

Vision tratează o singură înregistrare ca **observație izolată** și două sau mai multe observații cu același cod/platformă ca **repetate**. În panoul de diagnostic afișează numărul exact din sumarul local; la severitate egală, incidentele repetate sunt prioritizate înaintea celor izolate, iar un incident critic singular are totuși prioritate față de o avertizare repetată. Incidentele marcate rezolvate nu produc recomandări active.

**Limitare tehnică importantă:** contorul este agregat pe durata rezumatului păstrat local, nu o rată pe minut/oră și nu dovedește că defectul s-a repetat într-un interval calendaristic fix. Nu sunt generate notificări, alerte server, cereri de rețea, retry-uri sau scrieri operaționale. Teste unitare/widget pentru prag 1→2, sortare, severitate, resolved și lipsa efectelor secundare; rezultatele ultimului SHA se validează separat în CI.
