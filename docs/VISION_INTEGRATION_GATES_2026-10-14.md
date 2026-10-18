# Vision → AndiCarpet: praguri de integrare, fără producție

**Data:** 2026-10-14. **Stadiu:** checklist tehnic, nu autorizație de merge, deploy sau distribuire a APK-ului de lucru.

## Baze verificate în GitHub
- PR #28 modularizare: HEAD `b8ad0f87acb241000bba310948564aba8de1c01e`, CI 5/5 și identity verde; AuthGate P1 nu este remediat în această ramură. 195 fișiere Dart; 59 part rămase (nu forțați conversii).
- PR #33 AuthGate P1: HEAD `a5f43ef9ce0bfedaf59766aafe18732fef7f8f47`; Draft, remediu încă neintegrat în #28.
- PR #29 OCR/contracte: HEAD `545e0202755a8ee86a7b3406adccd469aac84f9e`; autorizațiile financiare Issue #32 rămân de evaluat.
- PR #34 Vision: HEAD de început `390686510e35273712e20d07cdc6af435b46cd4f`; este derivat din integrarea de probă PR #21, NU un patch exclusiv față de main. Jurnal bounded/local, raport opt-in, recomandări deterministe, inventar de acoperire și comparator pur OCR. APK-ul offline nu autentifică și nu accesează Firestore.
- Test manual Vision Build #22: persistența unui singur eveniment sintetic la repornire PASS raportat de proprietar; nu validează OCR real ori AuthGate.

## Faza 0 — conservare și inventar
1. Înghețați și notați commiturile exacte ale ramurilor de intrare; verificați dirty checkout și divergențe. Nu copiați fișiere peste alte ramuri.
2. Calculați diferențele reale pe căile suprapuse. La analiza precedentă: #28×#34 — `lib/main.dart`, `lib/home/home_page.dart`, `lib/expenses/expense_page.dart`, `ChatGpt`, `test/repository_hygiene_test.py`, workflow de validare; #33×#34 — `lib/home/home_page.dart` și `ChatGpt`; #29×#34 — `lib/ocr_parser.dart` și testele OCR. Sunt suprapuneri de fișier, NU conflicte Git dovedite.
3. Folosiți o ramură/PR NOUĂ, cu ordinea explicită a bazelor și integrare prin cherry-pick selectiv sau reconciliere manuală; nu refaceți schimbările deja validate, nu atingeți ramurile sursă.

## Faza 1 — bariere obligatorii înaintea APK-ului autentificat
- **P1 identitate:** cazul A→B, ecrane Home/profile, Navigator, subscripții întârziate, GPS și FCM trebuie să respecte UID și generația sesiunii. Teste de login/logout/switch și evenimente asincrone întârziate pe dispozitivul emulator.
- **Financiar:** analiza Issue #32 trebuie să închidă contractul server-side al rolurilor, vizibilității, confirmărilor și verificărilor. Nu schimbați reguli live fără aprobare. Nicio recomandare Vision nu mută bani/diurne.
- **Vision local:** montare la bootstrap doar cu handlerii de error reporting care păstrează handlerele existente; neintroducere de loguri brute, FCM token, GPS, text bon sau UIDs; retenție 7 zile, limite 150/48 KiB implementate la nivelul jurnalului de producție.
- **OCR silențios:** `VisionExpenseSaveVerifier` este deocamdată doar helper pur. Nu îl conectați până când există citire server autoritativă a documentului exact, cu UID/team validat și `pendingWrites=false`. Rezultat `awaitingServerEvidence` nu este eroare. Comparați în bani întregi și evitați retry-uri ne-idempotente.
- **Offline/cache:** datele de diagnostic local pot fi curățate, dar nu jurnalul financiar operațional și nici coada de scrieri offline.
- **Costuri:** niciun LLM extern, Firebase listener nou, polling cloud sau trafic diagnostic automat în varianta implicită; măsurați costurile dacă apare propunerea unui transport opt-in.

## Faza 2 — probe de acceptanță
1. Teste Flutter/widget, Python, Node, Functions și Firestore emulator complet 5/5 pe SHA de integrare, plus identity suite și build web.
2. Teste Android în aplicația REALĂ autentificată pe mediu de test, nu doar APK-ul offline. Login A→B, refresh rapid, GPS/FCM tardiv, ecrane financiare și erori OCR fără excepții.
3. Pentru teste de telemetrie: un incident de test nu devine eroare reală; copie opt-in; absența erorilor nu este certificare de sănătate. Confirmare persistență după repornire și curățare TTL, inclusiv cache corupt.
4. Confirmați că aplicația veche și noul build au identity/package/version corecte; distribuiți un singur APK de test autentificat numai după acceptanță explicită, fără merge/deploy implicit.

## Stop conditions
Orice failing CI, scurgere între UID-uri, modificare financiară neautorizată, dublarea bonurilor, apariția permisiunilor Android neașteptate, regresie GPS/FCM sau conflict nerezolvat => opriți integrarea, salvați checkpoint, nu distribuiți APK-ul.

**Avatarul Vision rămâne amânat până după nucleul funcțional și testarea lui.**
