# AndiCarpet — PV Magic / Million: descărcare Android și biblioteca Documente

**Data:** 2026-10-13  
**Stadiu:** cod pe ramură separată `fix/documents-pv-download-20261013`, fără merge, deploy ori schimbarea datelor existente.  
**Probleme raportate:** Android deschidea doar meniul Partajează la exportul PV Magic; fișa PV Million apărea la „Alte documente permanente” fără buton de descărcare; PV Magic nu putea fi șters.

## Audit tehnic (confirmat în cod)

1. `lib/download_file_stub.dart` intercepta **toate PDF-urile native** prin `Printing.sharePdf`, nu printr-o salvare pe dispozitiv. Pe web `download_file_web.dart` utiliza descărcarea browserului. Afectarea nu era limitată la PV Magic — și rapoartele care folosesc `downloadFile` puteau ajunge la partajare în loc de salvare.
2. `lib/documents/documents_page.dart` avea `PV_MAGIC.pdf` încărcat direct din `assets/pv_magic.pdf`, livrat împreună cu fiecare APK. Nu există un document Firestore reprezentând acest fișier, deci **nu poate fi șters din Firebase** și nici eliminat definitiv dintr-un APK deja instalat. Pentru a-l scoate definitiv din pachet este nevoie de o versiune nouă.
3. Formularul `Adaugă document permanent` colecta doar `title/category/date/notes` și făcea `documents/{id}.set(...)`. **Nu prelua și nu salva conținutul PDF**, astfel încât fișa Million înregistrată prin el nu reprezintă un fișier real partajabil între dispozitive.
4. Categoriile cu numele documentului nu erau grupate separat. Categoria implicită `Alte documente` putea păstra la secțiunea nepotrivită fișele PV.

## Corecții incluse în ramură

- Pe Android/iOS/desktop, `downloadFile` folosește `FilePicker.saveFile`, deja disponibil în `file_picker 13.1.0`, cu `bytes`, `mimeType` și dialogul sistemului „Salvează ca...”; rezultatul `false` înseamnă anulare, deci nu afișăm succes fictiv. Pe web continuă descărcarea prin browser. Rapoartele PDF care cheamă `downloadFile` folosesc de acum aceeași semantică de salvare, intenționat.
- Cardul Magic are **„Descarcă PDF”** și, pe platformele native, separat **„Partajează PDF”** (Prin `Printing.sharePdf`); păstrăm posibilitatea de partajare fără a substitui descărcarea.
- Un admin poate **ascunde și reafișa** cardul fix Magic global, cu dialog de confirmare. Se folosește documentul de configurare special `documents/__pv_magic_visibility__` în **colecția Firestore existentă**, pe care numai admin îl poate scrie conform regulilor prezente. Nu alterăm asset-ul, nu mutăm documente și nu schimbăm `firestore.rules`. Aceasta este o opțiune, nu ștergerea fizică a PDF-ului.
- Fișele cu categoria `Proces verbal` sau cu titlul clar `PV ...`/`Proces verbal ...` și categorie generică sunt afișate sub **„Alte procese verbale”**, nu sub „Alte documente permanente”. Nu migrează automat categoria salvată în Firestore, iar contractele Million rămân în categoriile lor.
- Formularul explică expres că este **doar fișă document, PDF neatașat**; sugerăm categoria Proces verbal după titlu, cu posibilitate de alegere manuală. Administratorul poate modifica ulterior categoria; ștergerea unei fișe obișnuite cere confirmare și nu se confundă cu PDF-ul Magic.
- Nu se adaugă fișiere PDF mari în Firestore și nu se activează Firebase Storage, servicii plătite, permisiuni noi sau deploy. Nu transformăm retroactiv metadata Million într-un fișier PDF fictiv.

## Teste / limitări de aprobat separat

- `test/document_categories_test.dart`: PV Million vechi, categoria explicită, contract Million, evitare false pozitive.
- `test/documents_download_contract_test.py`: contracte de salvare nativă, partajare distinctă, afișare fișă fără PDF și confirmare ștergere/ascundere.
- `.github/workflows/verify-documents-android-pr.yml`: teste de mai sus și compilare APK debug pe PR, fără deploy. Separat rulează CI standard de 5 joburi. Confirmarea finală se face **pe SHA-ul final**, nu pe o rulare veche.
- Salvarea efectivă prin Storage Access Framework și partajarea trebuie validate pe telefon Android; un simplu build verde nu demonstrează salvarea în `Downloads`.
- Încă nu există încărcare persistentă PDF Million către toți utilizatorii. Pentru a include **PV Million ca document fix în APK** fără costuri cloud, proprietarul trebuie să furnizeze PDF-ul original; alternativ, proiectăm o stocare comună securizată cu reguli/limite/costuri aprobate în prealabil. Fișa existentă rămâne intactă până la o decizie explicită.
- PR-ul nu șterge date Firestore din producție și nu schimbă securitatea. Butoanele admin din viitoarea versiune execută acțiuni doar după confirmarea manuală; ele trebuie testate cu regulile Firestore existente.

**Interdicție:** nu face merge automat, nu publica web/APK, nu schimba Firebase Storage/Rules/billing și nu corecta/suprascrie retroactiv documentul Million fără fișierul-sursă și confirmare.

## Fișierul PV Million primit — integrare binară în așteptare (2026-10-13)

Proprietarul a furnizat explicit PDF-ul original `Proces_Verbal_Million_AndiCarpet.pdf` în conversația AndiCarpet. Fișierul a fost deschis și verificat local:
- **PDF 1.3**, **1 pagină A4**, necriptat, **1.399.921 octeți**;
- SHA-256: `3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`;
- formă tipărită de recepție a lucrărilor de curățare a mochetei MILLION, cu date locație/client, verificarea permisiunii, managerul informat, zone curățate, rezultat și semnături; **document scanat/imagine, fără strat text**, nu este formular interactiv;
- nu se modifică documentul, nu se înlocuiește cu un formular aproximat ori cu PDF reconstruit.

### Implementare pregătită

În `lib/documents/documents_page.dart` există acum cardul **PV Million** cu `Descarcă PV Million` și `Partajează PV Million`, care citesc `assets/pv_million.pdf`. Cardul are protecție de disponibilitate: până la adăugarea REALĂ a fișierului binar, butoanele rămân ascunse și este afișat doar avertismentul de integrare în curs. Niciun fișier fictiv nu se distribuie și fișa Million existentă în Firebase nu se șterge.

**Blocaj de transport:** conexiunea GitHub din conversația aceasta primește conținut de fișier doar ca text/base64 și nu poate transfera direct atașamentul binar local de 1,4 MB printr-o cale de fișier. Este necesară încărcarea **exact a octeților originali** în ramura `fix/documents-pv-download-20261013`, calea `assets/pv_million.pdf`, folosind ChatGPT Work cu fișierul atașat sau interfața GitHub Upload files. Nu se încarcă în `main`. După upload, verificați SHA-256, disponibilitatea în pachetul Flutter, teste, Android debug build și CI complet pe noul SHA.

**Atenție:** dacă fișierul nu este încă în repository, cardul este **doar pregătit**, nu implementat complet. Nu realizați merge, deploy sau anunțați descărcarea PV Million ca funcțională până când assetul este prezent și verificat.


## Original adăugat în ramura PR #20 — verificare Work (2026-10-13)

Această secțiune înlocuiește statusul istoric de blocaj upload de mai sus. Originalul atașat a fost copiat fără conversie la `assets/pv_million.pdf`: **1.399.921 octeți**, SHA-256 **`3bece2fa6f39d1bbba904ea45856d60215c8cfb3f0d23c80767662ffa4bdcd23`**. Comparația binară cu atașamentul (`cmp`) a trecut. `pubspec.yaml` include deja directorul `assets/`, deci nu necesită o intrare suplimentară.

Integrarea citită: disponibilitate verificată prin `rootBundle`, card afișat inclusiv când Firestore nu răspunde, download nativ prin `FilePicker.saveFile` cu tratarea anulării, share nativ separat prin `Printing.sharePdf`, download web prin Blob/Anchor. **Pe web butonul Partajează este ascuns explicit de `if (!kIsWeb)`** în implementarea pregătită; nu pretindem suport pentru partajare prin browser. Nu schimbăm acest comportament în lotul de adăugare a originalului.

Validări noi: test Python de integritate (dimensiune, hash, antet PDF), test Flutter de încărcare din bundle și egalitate a octeților; Android CI verifică hash-ul PDF-ului extras direct din APK debug, iar web CI verifică hash-ul assetului din buildul release. Triggerul Android include acum asseturile, pubspec și testul nou, pentru a evita lipsa verificării la actualizări exclusiv binare.

Rezultate locale înainte de push: **113 teste Python PASS**, **3 teste Node PASS**, syntax Functions PASS, `git diff --check` PASS. Flutter/Android SDK nu sunt instalate în acest mediu; testele Flutter, dependențele Functions, emulatorul Firestore și buildurile Android/web se execută prin cele două workflow-uri PR. Rezultatele pe SHA-ul final se vor înregistra în PR după terminarea CI.

Rămâne necesară verificarea manuală a salvării/partajării pe Android și a descărcării într-un browser real. Buildul și checksumul validează includerea originalului, nu dialogurile sistemului pe telefon. Fără merge, deploy, Firebase live sau publicare APK; artifactul debug CI este temporar, exclusiv pentru verificare.
