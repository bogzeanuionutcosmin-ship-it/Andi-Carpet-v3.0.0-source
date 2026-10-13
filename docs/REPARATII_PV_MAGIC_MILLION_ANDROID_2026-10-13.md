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
