# AndiCarpet — proiectare randament adaptiv al echipei (DRAFT, 13.10.2026)

> **STATUT: METODA C APROBATĂ; DETALIILE MATEMATICE ȘI IMPLEMENTAREA SUNT ÎNCĂ ÎN PROIECTARE.**  
> Baza aprobată: `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md`, secțiunea 28. Scopul este să pregătim alegerea algoritmului cu exemple verificabile. În această etapă **nu modificăm cod, colecții Firebase, reguli, date de producție, APK ori deploy**.

> **DECIZIE ACTUALIZATĂ — 13.10.2026:** utilizatorul a confirmat expres varianta **C**, ca metodă de calcul adaptiv mixt (m² + timp real + istoric comparabil + Learning). Alegerea **familiei de algoritm este aprobată**. Ponderile, etalonul concret, tratamentul m² istorici și formula numerică exactă necesită încă proiectare, simulări și validare înainte de implementare.

## 1. Scop și restricții deja aprobate

- Două procente **ale fiecărei echipe**: «Luna în curs» și «General». Niciun randament procentual pe sală, niciun scor salarial, bonus, sancțiune ori clasificare individuală.
- Indicator **strict informativ**, sensibil la intervențiile noi, la rectificări verificate și la învățarea din istoricul nou. Maxim afișat **100%**, chiar când echipa depășește referința.
- Măsurăm **eficiența curățării mochetei**, nu timpul total în trafic, cazare, diurnă sau lucrări de fațadă; minutele de așteptare a accesului înainte de START nu penalizează. START–STOP este continuu, fără pauză de intervenție.
- Maximum doi membri per echipă, ambii participă la curățarea normală. Nu înmulțim minutele cu 2, nu transferăm istoricul când se schimbă membrii.
- Nu inventăm suprafețe, timpi, intervenții sau informații de participare. Refuzurile/nerealizările nu devin automat curățări încheiate.
- Algoritmul Learning actual poate fi folosit ca sursă; **nu presupunem** că oricare lucrare nouă are deja trei execuții istorice ale aceleiași locații.

## 2. Inventar read-only din codul actual (nu este audit al Firestore live)

| Resursă | Localizare în repository | Constatare |
|---|---|---|
| Suprafață mochetă | `lib/models/app_data_models.dart`: `Location.surfaceM2` | Editabilă, valoare implicită 0; lipsește la unele locații |
| Tip locație | `Location.type` / categorii | Disponibil, dar tipul comercial nu garantează dificultate identică a curățării |
| Suprafață fațadă | `Location.facadeM2` | Distinctă; nu este m² de mochetă și nu intră automat în acest scor |
| Intervenții | `CentralizerRecord` | `teamId`, `locationId`, `startedAt`, `finishedAt`, `status`, `keptForLearning`, așteptare acces, fațadă DA/NU; **nu are suprafața aferentă execuției** |
| Learning durată | `lib/learning/duration_estimates.dart` | Folosește execuții valide ale **aceleiași locații**, minimum trei exemple când este activ; medie istorico-sezonieră și indicator `confidence` |
| Alimentare UI | `lib/home/home_page.dart` | Există deja streamuri Firestore `locations` și `records`; agregarea read-only se poate reutiliza fără noi scrieri Firestore la fiecare actualizare |
| Creare/editare execuție | `lib/dashboard/dashboard_page.dart`, `lib/centralizer/centralizer_page.dart` | START/STOP și corecții posibile; nu există în prezent snapshot m² în înregistrare |
| Date inițiale de locații | `_seedLocations()` din `lib/home/home_page.dart` | 103 locații inițiale: 36 MAGIC (16 cu `surfaceM2`), 67 MILLION (35 cu `surfaceM2`), **51/103 cu suprafață setată**; NU reprezintă acoperirea datelor live |

**Risc suplimentar concret:** o execuție cu `facadeDone=true` poate avea START–STOP comun cu mocheta, fără timp de fațadă separat. Nu deducem minutele fațadei prin procente arbitrare. În modelul viitor se marchează calitatea comparației sau se exclude din *antrenarea etalonului* dacă timpul este amestecat, fără a ascunde executarea din Centralizator.

## 3. Variante analizate

**A. Numai media timpilor din Learning pe sală:** utilizabilă la săli cunoscute, dar exclude multe săli noi și depinde excesiv de cele trei execuții istorice locale. NU recomandată ca metodă exclusivă.

**B. Un etalon fix m²/oră pentru orice sală:** ușor de explicat, dar poate favoriza săli ușoare, penaliza săli atipice și nu folosește Learning suficient. Utilă doar ca *simulare pedagogică* sau reper temporar demonstrativ, nu ca regulă fixă ascunsă.

**C. Referință adaptivă de durată din suprafețe + istoric comparabil + Learning (recomandată pentru proiectare):**
1. Se selectează o singură dată fiecare execuție efectiv **finalizată**, cu echipă, perioadă operațională și durată START–STOP pozitivă validă. Refuzurile și intrările fără START–STOP valid nu intră ca finalizări; nu se dublează după offline/retry.
2. Se obține pentru fiecare lucrare un **timp de referință orientativ** din informațiile relevante disponibile:
   - dacă se cunoaște m² al mochetei, se poate estima o durată folosind **ritmul de referință învățat din alte lucrări comparabile**;
   - dacă Learning pe locație are un istoric adecvat, estimarea poate ajusta reperul bazat pe m²;
   - dacă unul dintre semnale lipsește, celălalt poate fi suficient *numai dacă este fundamentat*; dacă lipsesc ambele, execuția rămâne în Centralizator și în indicatorul de acoperire, dar fără contribuție fictivă la procent;
   - cât de mult cântărește un semnal depinde de **calitatea și numărul observațiilor**, nu de o pondere impusă acum. Nu există încă coeficienți aprobați.
3. Se calculează numai **raportul sumelor globale**, fără procent pe sală:
   ```text
   Randament echipă(P) = MIN(100%, 100 × SUM(timpi de referință fundamentați în P) / SUM(timpi reali ai ACELORAȘI execuții din P))
   ```
   Formula de agregare este o **propunere de implementare**, nu reintroducerea automată a vechii formule. Noutatea esențială este construirea **adaptivă și multiplu-fundamentată a timpului de referință**, nu media simplă a unor procente locale.
4. `Luna în curs` este definită după **ziua operațională din România**; `General` folosește toate intervențiile istorice comparabile ale aceleiași echipe. Recalcularea se face când se schimbă intrările relevante și la trecerea lunii, nu la fiecare secundă. În intervenție în desfășurare poate exista un cronometru/progres separat, fără a marca lucrarea automat drept finalizată.
5. Nu antrenăm un etalon cu chiar execuția pe care o evaluăm; evităm ciclul «mă compar cu media mea actuală», care ar împinge artificial scorul spre 100%. Analizăm referințe comune din lucrări comparabile, istoric anterior sau validare fără auto-includere. Încrederea și perioada de antrenare sunt de calibrat din date, nu de ghicit.
6. O eventuală schimbare a referinței prin Learning poate recalcula și procentul general, fiind un **indicator curent**, nu o dovadă contractuală a productivității trecute. Timpul fizic și istoricul intervențiilor rămân neschimbate. Versiunea algoritmului și sursa datelor trebuie explicabile.

### Ce înseamnă «mixăm» fără dublarea informației

M² + durata reală sunt măsurători distincte; `learningEvents` sau durata estimată derivată din aceleași execuții nu se adună ca muncă suplimentară. Learning este un **model de referință**, nu încă o intervenție în sumă. GPS, trafic, cazare, cheltuieli și așteptarea accesului pot explica variații, însă nu le transformăm în bonusuri/penalizări numerice fără legătură cu mocheta.

## 4. Simulări reproductibile pe date COMPLET FICTIVE

Pentru a izola efectul intervențiilor, folosim DOAR în simulare un etalon constant de **120 m²/oră**. **Nu este o normă propusă firmei** și nu include deocamdată ajustarea Learning. Formula numerică pentru această demonstrație: `MIN(100%, 100 × (Σm² / Σore) / 120)`.

Presupunem că echipa avea înaintea lunii curente **900 m² în 10 ore** de curățare. În luna curentă avea inițial **300 m² în 3 ore**.

| Eveniment | Luna curentă: m² / ore | Randament lunar | General: m² / ore | Randament general |
|---|---|---:|---|---:|
| Situație inițială | 300 / 3 | **83,33%** | 1.200 / 13 | **76,92%** |
| Încă o curățare finalizată: +100 m², +1,5 h | 400 / 4,5 | **74,07%** | 1.300 / 14,5 | **74,71%** |
| Corecție justificată: suprafața ultimei curățări era 120, nu 100 m² | 420 / 4,5 | **77,78%** | 1.320 / 14,5 | **75,86%** |

Observații:
- O intervenție mai lentă decât referința reduce **ambele procente**, fără să fie o penalizare salarială.
- Corectarea unei suprafețe schimbă **ambele procente**, dar **nu** orele efective. Corecția vizează aici **ultima intervenție identificabilă**, nu rescrierea automată a tuturor vizitelor istorice în aceeași sală.
- Cu un etalon adaptiv, Learning/alte observații comparabile pot produce o nouă referință chiar fără schimbarea orelor; interfața trebuie să explice asta.
- Dacă apare o curățare finalizată cu m² lipsă, dar Learning credibil, poate fi utilizată după validarea modelului; dacă nu există niciun reper verificabil, nu se inventează o contribuție numerică.
- Dacă există doar date necomparabile, UI spune **«Date insuficiente»** sau **«Estimare orientativă — încredere redusă»** când există un calcul real posibil; nu presupune 0%/100%.

## 5. Suprafața este variabilă: contract de date încă de stabilit

Trebuie distinse:
1. **Corecție de măsurătoare**: valoarea veche era greșită, deci poate fi recalculată referința aferentă intervenției afectate, cu evidențierea sursei corecției.
2. **Schimbare fizică în timp**: de la o anumită dată sala are altă suprafață; lucrările dinainte nu se recalculează automat cu m² noi.
3. **Istoric legacy fără suprafață la execuție**: `CentralizerRecord` nu stochează astăzi snapshot de m²; asocierea cu suprafața curentă este **o aproximație** doar dacă există dovada că este reprezentativă, altfel se folosesc alte surse sau se marchează indisponibilă.

**Opțiuni tehnice de comparat ulterior:** snapshot minimal al m² la finalizarea unei intervenții + corecții explicite; sau istoric versionat al suprafeței locației, valabil de la o dată. Alegerea trebuie testată pentru costul Firestore, compatibilitatea dispozitivelor vechi, backup/restore și audit minimal. **Nicio schemă nouă nu este încă autorizată.**

## 6. Actualizare, afișare și costuri

- Putem reutiliza streamurile deja existente pentru `locations` și `records` din `HomePage` și calcula un rezultat read-only la schimbări confirmate/sincronizate; **fără** scriere pentru fiecare vizualizare sau tick de cronometru.
- Cache/calcul incremental sau memoizare dacă volumul istoric devine semnificativ; un singur serviciu pur și testabil pentru Dashboard și rapoarte, evitând algoritmi separați.
- Pentru fiecare procent, butonul **Info** arată perioada, numărul execuțiilor total/incluse/neincluse, m² cunoscuți, ore de curățare, productivitate m²/h unde calculabilă, sursa referinței și o explicație simplă a calității datelor.
- Procentul se afișează cu **maximum 100%**. Dacă devine disponibilă o estimare mai bună, rezultatul se poate schimba inclusiv pentru «General»; nu confundăm acest lucru cu falsificarea istoriei.
- Se testează offline/retry, streamuri concurente, idempotență, lipsa GPS, venit al datelor târzii, intervenții peste miezul nopții/limita lunii și schimbările de echipă. Nu impunem confirmări noi la fiecare STOP doar pentru a alimenta scorul.

## 7. Ce trebuie validat înainte de implementare

**Decizii tehnice deschise — recomandate pentru simulare/confirmare:**
- Aprobarea variantei C ca **familie de algoritm**, nu a unei ponderi numerice.
- Ce înseamnă „lucrări comparabile”: în prima fază m² și categorii existente, cu verificarea faptului că aceste categorii chiar explică diferențele de ritm; fără inventarea unui câmp de «dificultate» necerut.
- Cum fixăm/calibrăm etalonul în lipsa altor echipe cu istoric valid și cum evităm auto-comparația circulară; poate fi necesară o perioadă inițială cu «încredere redusă».
- Cum tratăm suprafața corectată față de schimbarea fizică a sălii și datele legacy, fără reconstituiri speculative.
- Cum tratăm durata comună pentru mochetă și fațadă, fără a scădea timp de fațadă inventat.
- Dacă procentul general se **recalculează retrospectiv** după fiecare învățare/correcție sau se păstrează o comparație istorică versionată: cerința actuală favorizează recalcularea **informativă**, dar prezentarea transparentă trebuie validată.
- Ce politici de excludere a anomaliilor și de vizualizare a «încrederii» sunt proporționale pentru un indicator nesalarial.
- Simulare pe un set anonimizat de intervenții reale, obținut doar prin acces explicit autorizat; comparăm stabilitatea lunară/generală și costul înainte de a alege coeficienți.

## 8. Matrice minimă de teste viitoare

1. Fără istoric local Learning, dar m²/durată valide și bază comparabilă: lucrarea **poate** contribui la procent.
2. m² necunoscut, Learning valid: fallback explicat; ambele lipsă: fără scor fictiv.
3. Trei luni de istoric, lună nouă goală: lunar «Date insuficiente» / general din istoric comparabil.
4. O intervenție nouă finalizată modifică lunar și general; o intervenție în curs NU intră ca finalizată.
5. Corecție m² aplicată unei intervenții identificabile modifică rezultatul, fără schimbarea minutelor în Centralizator.
6. Schimbare fizică a m² de la data X nu modifică automat m² pentru curățările anterioare.
7. Refuz, Nerealizată, așteptare pre-START, fațadă, condus și repetări offline nu umflă volumele/timpii.
8. Tura peste miezul nopții, trecere de lună, fus orar România, înlocuirea membrului și intervenții din aceeași locație în zile diferite.
9. Învățare cu excluderea țintei și comparații independente; scorul nu tinde automat la 100% prin auto-referință.
10. Lipsă rețea, actualizare întârziată, dataset mare, două dispozitive sincronizate, fără scrieri Firestore declanșate de simpla afișare.

**Următoarea etapă:** după aprobarea direcției variantei C și a politicilor principale, proiectăm formula numerică efectivă, simulăm cu date autorizate/anonimizate, pregătim teste unitare și de integrare; abia ulterior implementăm într-o ramură cu PR/CI, conform regulilor obligatorii.

## 9. Decizie explicită: varianta C aprobată (13.10.2026)

**Confirmare explicită a proprietarului:** «Da confirm» ca răspuns la întrebarea «Confirmăm varianta C, cu etalon adaptiv din suprafețe, istoric comparabil și Learning, în locul unui etalon fix m²/oră?». Varianta **C** este, în consecință, **metoda aleasă** pentru continuarea proiectării. Nu mai este de pus aceeași întrebare de aprobare în conversații viitoare.

**Aprobat acum:** combinarea datelor reale ale lucrărilor (m², START–STOP), istoriei comparabile și estimărilor Learning ca surse alternative/complementare ale unui **reper adaptiv**, agregat pe echipă pentru **Luna în curs** și **General**, actualizat după apariția sau rectificarea informațiilor. Rămân indicatori exclusiv informativi, plafonați la 100% și fără procente pe fiecare sală.

**Nu este încă aprobat:** cifra de referință m²/h, modelul concret (regresie/mediane/altul), coeficienți și ponderi, pragul de încredere, comparabilitatea dintre tipuri de sală, regulile retroactive exacte pentru schimbarea suprafeței, regula pentru execuții mixte mochetă/fațadă și schema de persistență/versionare. Exemplul 120 m²/h este DOAR o simulare și nu trebuie introdus ca setare fixă.

**Pașii următori de proiectare:**
1. Comparăm tipuri de etalon istoric adaptiv și alegem o metodă robustă pentru loturi mici, inclusiv fără m² ori Learning local; de evitat circularitatea auto-evaluării și introducerea datelor viitoare în etalonul care evaluează aceeași lucrare.
2. Proiectăm contractul pentru m² modificați: corecție de măsurare versus modificare reală de suprafață de la o dată; fallback transparent pentru înregistrări legacy.
3. Stabilim eligibilitatea intervențiilor, influența fațadelor combinate și politica de calitate, apoi simulăm pe cazuri-limită și istorii autorizate/anonimizate.
4. Abia după aprobarea numerelor și regulilor rămase, se scriu teste și cod pe ramură separată, cu PR/CI, fără modificări implicite de Firebase sau deploy.

**Stadiu la confirmare:** doar documentație; niciun cod, date Firestore, reguli de securitate sau deploy modificate prin această decizie.

## 10. Schimbarea reală a configurației fizice a sălii — clarificare explicită 13.10.2026

**Răspunsul proprietarului:** «Sala chiar își schimbă fizic formatul». Aceasta lămurește cauza operațională obișnuită a modificării suprafețelor: **nu trebuie tratată automat drept corectarea unei măsurători greșite**. Pot apărea reamenajări, compartimentări sau reorganizări ale spațiului; o schimbare de format poate modifica dificultatea chiar dacă m² nu se schimbă.

### Regulă funcțională rezultată (aprobată ca principiu, nu implementare tehnică)

1. **Versiuni temporale ale configurației:** noua suprafață/configurație a locației este valabilă **din momentul real al schimbării fizice**, nu automat din ziua când un administrator deschide formularul. Se păstrează separat istoricul anterior, fără rescrierea duratelor ori a intervențiilor efectuate.
2. **Lucrările se compară cu situația fizică relevantă din momentul execuției:** o curățare efectuată înainte de schimbare nu primește automat noua suprafață. O curățare de după schimbare folosește noua referință. Aceasta se aplică atât agregării lunare, cât și celei generale.
3. **Learning recunoaște schimbarea:** istoria veche rămâne utilă ca reper, în special după normalizarea la m² și compararea între lucrări, dar **durata absolută a vechii configurații nu este echivalentă automat cu durata noii configurații**. O versiune nouă poate primi inițial o estimare mai puțin sigură, îmbunătățită de execuțiile noi și alte lucrări comparabile; istoricul nu se șterge.
4. **Randamentul rămâne orientativ și global al echipei**, cu exact două procente «Luna în curs» și «General», actualizabile la informații noi, plafonate la 100%, fără consecințe salariale și fără scor pe sală.
5. **Distincție pentru excepții:** dacă totuși se corectează o valoare tastată greșit, aceasta reprezintă o rectificare de date și are alt efect decât schimbarea fizică. Nu presupunem că fiecare editare a suprafeței este o rectificare retroactivă.

### Exemplu fictiv

- Până la 30 septembrie: sala are 200 m²; intervențiile efectuate atunci se raportează la 200 m².
- De la 1 octombrie: spațiul este reamenajat și mocheta are 150 m²; lucrările următoare folosesc 150 m².
- Dacă editarea este introdusă în aplicație pe 4 octombrie, data relevantă a modificării **rămâne 1 octombrie** dacă aceasta este data efectivă cunoscută. Nu aplicăm 150 m² retrospectiv în septembrie.
- Dacă mobilierul sau compartimentarea se schimbă, dar mocheta rămâne 150 m², o schimbare de configurație poate fi încă relevantă pentru estimarea duratei.

### Soluție tehnică propusă, de validat înainte de implementare

- Pentru o **schimbare reală**, interfața poate solicita minimal noua suprafață, data intrării în vigoare și, opțional, o notă «reamenajare/configurație schimbată». Data editării și identitatea autorului se pot înregistra automat pentru audit minimal. Nu introducem formular complicat ori aprobări suplimentare doar pentru indicatorul informativ.
- Se recomandă o **revizie temporală minimă per locație** (identificator/configurație, `validFrom`, `surfaceM2` și eventual observație) sau un mecanism echivalent, împreună cu un **snapshot m²/configurație** al fiecărei **noi** intervenții fizice în momentul relevant. Comparați costul acestor opțiuni și eventual folosirea lor combinată înainte de a schimba schema; nu copiați toată locația la fiecare intervenție.
- Datele istorice legacy nu au în prezent snapshot al suprafeței. **Nu le atribuiți automat un m² istoric exact pornind de la valoarea curentă.** Dacă se cunoaște fără ambiguitate perioada unei configurații, asocierile pot fi verificate; altfel, aplicația folosește istoricul numai pe dimensiunile disponibile (de exemplu durate/estimări) și marchează incertitudinea.
- Dacă formatul se modifică în timpul unei intervenții active, situația este atipică și necesită validare/caz documentat; nu rescrieți automat START/STOP sau m² după ora editării.
- Modificarea unei locații poate duce la **recalcularea indicatorului curent** (și la scăderea temporară a încrederii estimării), dar nu rescrie munca trecută, echipele ori documentele financiare. Nu declanșați scrieri Firestore la fiecare actualizare a Dashboard-ului.

### Teste necesare la implementare

1. Configurația A până la data X, B după X; istoria folosește referința corespunzătoare și totalurile se calculează fără duble numărări.
2. Editarea introdusă ulterior datei reale nu propagă greșit m² noi la lucrări vechi.
3. Format nou cu aceiași m² poate schimba gradul de comparabilitate pentru Learning.
4. Trecere peste miezul nopții/în lună nouă: timpul fizic al execuției nu se confundă cu data operațională; regula temporală e deterministă.
5. Corecția tastării greșite este gestionată separat de schimbarea fizică; intervențiile vechi nu se modifică accidental.
6. Legacy fără snapshot rămâne utilizabil prudent, fără inventarea unei suprafețe.
7. Înlocuire membri, offline, două dispozitive, schimbări de configurație concurente și recalculare fără scrieri Firestore la fiecare refresh.

**Aprobat explicit acum:** faptul că sălile își pot schimba **real** formatul și că această schimbare nu este automat o eroare de măsurare. **Propus, dar încă de proiectat:** câmpurile exacte, UI-ul, snapshoturile, reviziile, data implicită de efect și algoritmul statistic de adaptare. Nu există modificări ale codului sau ale datelor de producție în această etapă.
