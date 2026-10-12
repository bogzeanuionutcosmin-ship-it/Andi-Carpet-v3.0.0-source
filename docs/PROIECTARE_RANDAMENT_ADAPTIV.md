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

## 11. Prototip matematic robust pentru etalonul adaptiv (analiză și simulare, 2026-10-13)

> **PROPUNERE MATEMATICĂ, NU FORMULĂ APROBATĂ DE PROPRIETAR.** Metoda mixtă C și istoricul configurațiilor sunt aprobate ca direcție; această secțiune detaliază o posibilă realizare și scenariile simulate, fără modificări Flutter/Firebase. Coeficienții din exemplu sunt exclusiv fictivi.

### 11.1 De ce numai m²/oră poate fi înșelător

O intervenție presupune adesea un timp de pregătire/configurare a echipamentului indiferent de m²; raportul simplu `durata / m²` poate penaliza nejustificat sălile mici. Propunem ca, **atunci când există date suficiente și comparabile**, durata de referință să fie modelată ca:

```text
T_ref(m², cohortă, versiune_model) = a_cohortă + b_cohortă × m²
```

- `a` = timp tipic de pregătire/durată de bază (minute), învățat din istoric; nu îl presupunem universal.
- `b` = minute suplimentare estimate per m²; învățat din același istoric.
- Impunem `a >= 0`, `b > 0`, `T_ref > 0`, cu verificări pentru extrapolări excesive și calitatea modelului. Dacă datele nu susțin această relație, **nu pretindem că regresia este adevărată**.
- O «cohortă» este un grup de lucrări comparabile stabilit numai pe baza caracteristicilor **efectiv înregistrate** (tip/categorie, interval de suprafață, configurații relevante unde există), fără inventarea unui nivel de murdărie sau a unei dificultăți neînregistrate. Segmentarea excesivă poate lăsa grupurile fără date; alegerea grupurilor/pragurilor este încă de calibrat.
- Pentru date atipice se studiază estimatori robuști (de exemplu mediane de pante și intercepte, regresie robustă ori medii trunchiate, după volum). Nu fixăm metoda finală înainte de probe de stabilitate și teste de performanță.

**Atenție la comparație circulară:** execuția evaluată **nu intră** în setul cu care își produce propria referință. Preferăm un reper din intervenții comparabile independente de echipa evaluată, dacă există suficiente. Când nu există, se poate lua istoric **anterior** al aceleiași echipe sau configurații, marcat explicit «raportat la istoricul propriu / încredere redusă»; nu se consideră automat randament 100% doar fiindcă media curentă se auto-compară. Schimbările ulterioare ale modelului pot recalcula scorul informativ, păstrând referințe verificabile/excluderea țintei. Scopul este evoluția orientativă, nu un clasament.

### 11.2 Algoritm de selectare a referinței, propunere fără ponderi inventate

Pentru fiecare execuție eligibilă a unei echipe într-o perioadă:

1. Verificăm identificatorul unic, echipa reală, `Finalizată`, START–STOP valid, data operațională, interval fizic, `locationId` și **configurația valabilă efectiv la data lucrării**. Nu introducem așteptarea pre-START, refuzuri ori fațade ca mochetă finalizată.
2. Dacă există suprafață validă la execuție și un model comparabil verificabil, calculăm `T_ref` din modelul m² + bază. Dacă există istoricul Learning al **aceleiași versiuni de configurație**, acesta poate ajuta prin calibrare, alegerea unei alternative sau un nivel de încredere; nu îl adunăm arbitrar cu modelul m² și nu îl dublăm. Detaliile statistice se decid ulterior.
3. Dacă m² lipsește, dar Learning pe configurație are dovezi suficiente, putem folosi **exclusiv referința temporală Learning** pentru această lucrare. Absența suprafeței nu implică `0 m²`.
4. Dacă nu există Learning local, dar sunt lucrări comparabile și m² valid, **nu excludem** lucrarea doar pentru că n-a avut trei vizite la aceeași sală; modelul comparabil poate furniza referința, cu etichetă de calitate.
5. Dacă lipsesc ambele tipuri de referință credibilă, lucrarea rămâne în Centralizator și în contorul de execuții, dar **nu intră nici în numărător, nici în numitor** pentru randament; se afișează «Date insuficiente» dacă perioada nu conține lucrări evaluabile. Nici 0%, nici 100% fictiv.
6. Când se confirmă o **schimbare fizică** a formatului, Learning pentru noua configurație pornește cu încredere potențial redusă, folosind cât se poate din reperele comparabile. Istoricul vechi al aceleiași locații rămâne păstrat, dar nu este introdus direct ca durată-etalon a noului format. Nu există obligativitatea unei pauze de lucru.
7. Agregăm **numai după selecția perechilor valide** pentru echipă și perioadă, fără percent per sală:

```text
E(P) = SUMA T_ref ale execuțiilor comparabile din P
R(P) = SUMA T_real ale ACELORAȘI execuții din P
RANDAMENT(P) = dacă E>0 și R>0: MIN(100%, 100×E/R); altfel Date insuficiente
```

Această formă numerică agregată, propusă pentru metoda C, ar putea fi calibrată în continuare. Procentul **nu** se calculează din media simplă a procentelor pe săli și nu se înmulțește cu numărul membrilor.

### 11.3 Simulare cu regresie robustă pe date 100% fictive

**Date de antrenare independente de echipa evaluată:** (100 m², 70 min), (150 m², 90 min), (200 m², 110 min), (300 m², 150 min) și o observație atipică (400 m², 600 min).

Folosind **mediana pantelor dintre perechi de observații** și **mediana interceptelor** (numai ca demonstrație a robusteții la un caz atipic), rezultă:

```text
a = 30 minute
b = 0,4 minute/m²
T_ref = 30 + 0,4 × m²
```

Acești **30 min și 0,4 min/m² nu sunt norme ale firmei**. Faptul că modelul exemplului rămâne stabil față de un singur caz atipic **nu garantează** același lucru pentru date reale; regresia trebuie verificată pentru raportul între mărimi, metode și configurații.

**Echipă evaluată:** septembrie — sala A avea 150 m², executată în 100 min, iar sala B 200 m² în 120 min. Sala A este **reamenajată fizic** cu efect de la 1 octombrie și are apoi 100 m², curățată în 60 min. În octombrie, echipa mai finalizează sala C de 150 m² în 105 min.

| Lucrare echipă | Lună | m² corespunzători configurației | START–STOP real | Referință fictivă |
|---|---|---:|---:|---:|
| A, înainte de reamenajare | Septembrie | 150 | 100 min | 90 min |
| B | Septembrie | 200 | 120 min | 110 min |
| A, după reamenajare | Octombrie | 100 | 60 min | 70 min |
| C | Octombrie | 150 | 105 min | 90 min |

Rezultate verificate aritmetic cu un script separat, fără acces la datele reale:

- **Luna în curs (octombrie):** (70 + 90) / (60 + 105) × 100 = **96,97%**.
- **General (septembrie + octombrie):** (90 + 110 + 70 + 90) / (100 + 120 + 60 + 105) × 100 = **93,51%**.
- **Greșeala de evitat:** dacă atribuim retroactiv noii suprafețe de 100 m² și intervenției vechi A, referința totală scade fictiv de la 360 la 340 min, iar scorul general devine **88,31%**, deși munca istorică a rămas aceeași.
- **Lucrare nouă în octombrie:** încă 100 m² în 90 min, cu reper 70 min → **Luna în curs = 90,20%**, **General = 90,53%**. Asta demonstrează actualizarea progresivă în ambele ferestre, fără procent pe sală.
- **Plafon:** o curățare fictivă de 150 m² în numai 20 min, cu referință 90 min, se afișează **100%**, nu 450%.

### 11.4 Ce nu poate spune modelul, chiar dacă produce un procent

- Fără un istoric de suprafețe versiunate, datele legacy nu garantează ce m² existau la fiecare START. Nu folosim o completare retrospectivă mascată.
- O sală reamenajată poate fi mult mai complicată sau mai simplă **fără schimbarea m²**. Când acest lucru este cunoscut, marcăm noua configurație, scădem încrederea în reperul transferat și învățăm din curățări noi. Nu pretindem că formula liniară a surprins toate cauzele.
- Dacă fațada a fost făcută în același interval cu mocheta, durata reală a mochetei nu este separată demonstrabil din timestampurile actuale. Acele înregistrări nu sunt antrenare curată a modelului de mochetă; tratamentul eligibilității și al prezentării lor trebuie aprobat separat, fără minute inventate.
- Un model din istoricul aceleiași echipe poate fi util pentru tendință, **dar nu pentru a compara absolut echipele** fără o referință comună. Raportul și sursa reperului trebuie explicate în Info.
- Estimatorul din codul actual `learnedDurationEstimate` nu diferențiază configurațiile și necesită modificare sau un strat nou înainte de utilizarea directă în formula C. Nu reinterpretăm automat estimările vechi ca asociate unei versiuni valide de suprafață.

### 11.5 Propunere de contract pentru noua configurație, minimizând Firestore

- În documentul locației rămâne suprafața curentă; o revizie mică și versionată indică `validFrom`, m², versiune configurație și eventual o notă, doar **la schimbare reală**. Alegerea între revizii în același document și subcolecție/dosar separat depinde de volum, regulile Firestore și compatibilitate.
- O intervenție nouă poate referi versiunea configurației și, dacă este justificat, include un snapshot **minimal** de m², nu întreaga locație. Se verifică înainte costurile, limitele de dimensiune/document, schimbarea între START și STOP, accesul server-side și offline/retry.
- **La calcul:** rezolvăm `surfaceM2AsOf(executionEventTime)` pe versiunea fizică valabilă; `operationalWorkDate` decide **luna**, nu configurația fizică. Dacă versiunea este incertă, nu prezentăm suprafața ca fapt istoric precis.
- Scorurile se calculează read-only în memorie/memoizate din streamurile existente `locations` și `records`; nu adăugăm scrieri de procent la fiecare refresh, fără măsurarea volumului de date. Corecții aprobate și schimbări fizice valide declanșează recalcularea necesară, cu trasabilitate.

### 11.6 Verificări făcute acum și teste care rămân

**Executate doar pe simulare:** ajustarea robustă pe cinci observații (inclusiv una atipică), randamentul lunar 96,97%, general 93,51%, greșeala retroactivă 88,31%, recalcularea după intervenție (90,20% / 90,53%) și plafonul 100% — **7 aserțiuni aritmetice au trecut**. Acestea sunt verificări ale raționamentului matematic în JavaScript, **nu** teste Flutter/Firestore ori CI și nu folosesc date reale.

**Încă de testat ulterior:** estimator robust pe observații dispersate, lipsă referință/zonă validă, numeroase outliere, comparabilitate pe categorii și dimensiuni, config nouă cu m² identici, alegerea reperului fără scurgere din execuția evaluată, tranziții temporale, ora României/DST, cazuri mixte fațadă/mochetă, erori de rețea, concurență, compatibilitate cu datele legacy și consum Firestore. Calibrarea modelului, pragurile, politica de fallback și schema Firestore rămân de aprobat. **Nu se modifică aplicația** pe baza prototipului.

## 12. Aprobarea structurii a + b × m² și reguli de fallback propuse (2026-10-13)

### 12.1 Confirmare explicită a proprietarului — structură APROBATĂ

După prezentarea prototipului matematic din secțiunea 11, proprietarul a răspuns **«Confirm»** la întrebarea: «Confirmi această structură de calcul, cu coeficienți învățați automat, fără norme fixe introduse manual?». Se aprobă **structura** de calcul:

```text
T_referință = a + b × suprafața_m²
```

- `a` reprezintă componenta tipică de bază a duratei de curățare a unei săli, iar `b` componenta per m²; ambele se estimează automat **din istoric real, suficient și comparabil**, nu din norme manuale de firmă.
- Aceasta reprezintă **o estimare a duratei totale START–STOP**, nu inventarea/adăugarea unor minute suplimentare după înregistrarea lucrării.
- În randamentul final al echipei se folosesc două totaluri separate ca ferestre («Luna în curs», «General»), fără procent pe fiecare sală și cu plafon de 100%. Indicatorii sunt exclusiv informativi și nu influențează remunerația ori sancțiunile.
- Modelul trebuie să se adapteze la reamenajările reale, la suprafețele istorice corecte și la Learning, fără a șterge lucrări vechi ori a supraînvăța din aceeași execuție evaluată.
- **Nu au fost aprobate numeric** valorile lui `a` și `b`, estimatorul statistic concret (inclusiv alegerea medianelor din secțiunea 11, care rămâne o demonstrație), comparabilitatea exactă a cohortelor, pragurile de calitate, ponderile Learning, politica de eligibilitate pentru fațade și formatul noilor câmpuri Firestore. Nu se substituie exemplul fictiv `30 + 0,4 × m²` drept normă.

### 12.2 Politică de fallback — PROPUNERE pentru decizia următoare

Pentru fiecare lucrare efectiv Finalizată cu timp START–STOP pozitiv valid, identificator unic și echipă istorică:

| Date disponibile pentru referință | Comportament propus |
|---|---|
| m² verificabili la momentul lucrării + model comparabil robust | Referință `a+b×m²`, ajustabilă contextual cu Learning verificabil pentru **aceeași configurație**; fără adunarea arbitrară a două estimări |
| m² lipsă, dar Learning cu suficiente execuții valide **din aceeași configurație** | Referință temporală Learning ca rezervă; lucrarea poate contribui în procent, marcată «fără m²» / încredere conform sursei |
| m² există, dar istoricul Learning local este insuficient | Modelul din alte săli comparabile poate oferi referință fără obligativitatea celor trei lucrări locale |
| Nu există nici m² verificabili + model, nici Learning credibil | Lucrarea rămâne în Centralizator și numărul total de execuții; **exclusă din ambii termeni** ai randamentului, fără a fabrica 0% ori 100% |
| Întreaga perioadă nu are perechi de date comparabile | Dashboard arată «Date insuficiente» pentru perioada respectivă, independent de celălalt procent |

**Propus pentru transparență:** la Info pentru fiecare perioadă arătăm numărul total/inclus/exclus al intervențiilor, suprafețe și ore cunoscute, sursa aproximării și motivul lipsei reperului. Se poate afișa o etichetă neutră «Estimare orientativă — date limitate»; pragurile exacte nu se inventează. `keptForLearning` și posibilitatea estimării pentru randament au scopuri diferite și trebuie auditate explicit: excluderea unei execuții din antrenarea Learning nu poate fi ignorată în mod arbitrar pentru construirea etalonului.

### 12.3 După o reamenajare fizică — comportament propus

1. **Reamenajarea creează o nouă perioadă/configurație fizică**, inclusiv când suprafața numerică rămâne neschimbată, dacă formatul relevant curățării s-a schimbat. Se păstrează data efectivă, care poate fi diferită de data editării în aplicație.
2. Intervențiile vechi rămân legate de configurația veche și de timpii reali; nu li se atribuie m² noi. Datele legacy fără dovadă temporală nu primesc snapshot imaginar.
3. La prima curățare în noua configurație, în lipsa istoricului local nou, folosim modelul **comparabil între locații** dacă există m² verificabili și date statistice credibile. Nu impunem trei execuții noi ale sălii înainte de orice indicator orientativ.
4. După alte intervenții în noua configurație, Learning se poate adapta progresiv. Istoricul vechi este păstrat pentru analiză, dar estimarea directă a duratei vechii configurații nu se transferă automat ca referință nouă, mai ales când suprafața ori compartimentarea s-au schimbat.
5. Dacă modelul comun nu este încă justificat și nu există Learning relevant noii configurații, contribuția numerică a acelei execuții poate lipsi temporar din scor; nu se deduce că echipa a avut randament zero.
6. Scorurile lunare și generale se actualizează după confirmarea și sincronizarea evenimentelor noi/revizuirilor, fără scrieri repetate în Firestore la fiecare afișare sau la fiecare secundă. Pentru o curățare în curs nu se inventează finalizarea.
7. Separat de revizia fizică, o **greșeală de introducere** corectată ulterior poate impune ajustarea unor referințe istorice verificabile, cu audit; nu folosim automat același comportament ca la reamenajare.

### 12.4 Riscuri/întrebări tehnice încă deschise

- Alegerea și validarea metodei robuste de ajustare a lui `a,b`, pozitivitatea, loturi mici, estimări în afara intervalului de m² din eșantion, gruparea fără separare excesivă după categorie și evitarea auto-comparației circulare.
- Combinarea cu Learning fără «dublarea» aceluiași istoric, fără scurgere de informație din lucrarea evaluată și cu recalcularea explicabilă a istoricului general.
- Politica pentru START–STOP ce cuprinde și fațadă, fără a inventa timp de fațadă sau a denatura antrenarea modelului de mochetă.
- Cum se marchează eficient schimbarea fizică: revizie temporală mică, snapshot de m²/configurație la intervenții noi, tratarea editării întârziate și a conflictelor offline; fără migrare retrospectivă fictivă.
- Stabilirea datei lunii după ziua operațională românească și alegerea versiunii fizice după momentul real al curățării (nu după ziua operațională).
- Teste Flutter/unitare/Firestore ce trebuie scrise **după** finalizarea politicii și autorizarea implementării; simulările anterioare nu sunt dovadă de funcționare a aplicației.

**Statut final al secțiunii:** numai structura `a+b×m²` cu coeficienți învățați, împreună cu metoda mixtă C și cele două randamente informative, este **aprobată**. Fallback-ul și comportamentul detaliat după reamenajare de mai sus sunt **propuneri de confirmat**, nu decizii deja aprobate, deși respectă principiile istorice confirmate. **Fără modificări de cod, Firebase, reguli Firestore, date reale ori deploy.**

## 13. Confirmarea regulilor de fallback și de reamenajare (aprobare explicită 2026-10-13)

**Decizie explicită a proprietarului:** a răspuns **«Confirm»** la întrebarea «Confirmi și această regulă pentru datele insuficiente?» după prezentarea celor patru ramuri de fallback și a utilizării modelului comun pentru o sală nouă/reamenajată. Prin urmare, **politica funcțională de fallback din secțiunea 12.2 ESTE APROBATĂ**; nu mai este doar o propunere și nu trebuie reconfirmată. La aceeași prezentare s-a precizat că, după reamenajare, modelul comun din alte săli comparabile poate fi folosit inițial, urmat de adaptarea Learning din intervențiile noii configurații, fără pierderea istoricului vechi; **acest principiu funcțional este confirmat**. Detaliile tehnice ale versiunilor/configurațiilor rămân de proiectat.

**Ordine de selecție a unei referințe valide pentru fiecare execuție finalizată, cu timp real pozitiv:**
1. **Suprafață m² verificabilă la execuție + model comparabil învățat și suficient de credibil** ⇒ referința este durata `T_ref = a + b × m²`, cu coeficienți învățați automat din istoric relevant, fără normă manuală. Learning local poate îmbunătăți aprecierea când este verificabil și compatibil cu configurația, dar nu se adună două estimări fără justificare și nu se numără aceleași mostre de două ori.
2. **Lipsă m² verificabili, dar există Learning credibil pentru aceeași configurație fizică** ⇒ se poate utiliza estimarea de durată Learning ca **referință alternativă**. Nu se atribuie fictiv o suprafață necunoscută.
3. **Suprafață m² verificabilă, dar Learning local insuficient sau inexistent** ⇒ modelul învățat din **alte lucrări comparabile** poate furniza referința; nu cerem obligatoriu trei execuții proprii ale sălii noi înainte de prima contribuție informativă.
4. **Nici model comparabil fundamentat pe m², nici Learning credibil** ⇒ execuția rămâne integral în Centralizator, dar **nu intră nici cu durata estimată, nici cu durata reală în procentul perioadei**; nu se inventează `T_ref`, 0% sau 100%. Poate contribui legitim la istoricul viitor al metodei de învățare, în condițiile filtrelor specifice Learning. Se poate afișa motivul de neeligibilitate.
5. **Fără nicio pereche referință-real validă în perioada evaluată** ⇒ exact acea perioadă afișează **«Date insuficiente»**. «Luna în curs» și «General» se tratează independent; unul poate avea date suficiente, celălalt nu.

**Configurații fizice schimbate:** o reamenajare are dată reală de intrare în vigoare, iar intervențiile vechi se păstrează cu configurația și suprafața valabilă atunci; nu se suprascriu cu noul m². Imediat după reamenajare, noua configurație poate beneficia de referința din lucrări **comparabile independente** când există m² și suport statistic; Learning pentru noul format crește progresiv încrederea pe măsură ce se adună execuții. Lipsa acestui suport nu este eșec și nu devine procent fictiv. Istoricul vechii configurații rămâne disponibil ca istoric, dar durata absolută veche nu se copiază ca normă a noului format.

**Agregarea indicatorilor aprobați:** două procente **pe echipă**, «Luna în curs» și «General», cu maxim 100%, strict informative; includem numai perechi `T_ref` și `T_real` provenite din aceleași execuții valide și agregăm totalurile înainte de plafon. Nu mediem procente pe săli, nu înmulțim durata cu numărul membrilor și nu includem așteptarea pre-START, refuzurile, fațadele sau deplasarea ca și cum ar fi curățare de mochetă.

**Important — ce NU este încă aprobat:** metoda matematică precisă de învățare a lui `a,b` (mediana pantelor a fost doar demonstrativă), mărimea loturilor minime, pragurile de încredere, exact ce categorii/cohorte sunt comparabile, formula de integrare contextuală a Learning cu modelul m², snapshoturile și reviziile Firestore, versiunea minimă compatibilă și eligibilitatea execuțiilor cu fațadă inclusă în același START–STOP. Acestea trebuie analizate, apoi aprobate înainte de cod; **nu fixăm numeric etalonul de 30 min + 0,4 min/m²** din simulare.

**Consecințe pentru proiect:** recalculare informativă la date noi/correcții și sincronizare, fără scrieri Firebase la simpla afișare a Dashboard-ului; istoricul operațional/financiar rămâne intact și scorul nu influențează salarii/bonusuri/sancțiuni. Nicio modificare de cod, Firebase, configurație de producție, APK sau deploy în etapa curentă. **Nu au fost rulate teste de implementare.**

**Următorul pas:** proiectarea metodologiei robuste a coeficienților `a,b` și a unui indicator de acoperire/încredere, inclusiv cazuri de loturi mici, reamenajări și timp comun mochetă/fațadă, înainte de autorizarea implementării.

## 14. Metoda statistică aleasă prin delegare și afișare în profilurile membrilor (2026-10-13)

### 14.1 Autoritatea și domeniul deciziei

Proprietarul a cerut explicit: **«Stabilește tu metoda logică și corectă»**, după aprobarea metodei C, a formulei structurale `T_ref = a + b × m²`, a fallback-ului și a istoricului configurațiilor fizice. Prin această solicitare **delegă alegerea statistică detaliată**. Soluția de mai jos este **DECIZIE TEHNICĂ DE PROIECTARE ALESĂ PRIN DELEGARE**, nu cod executat sau un rezultat validat pe istoricul real. Valorile minime pentru calibrare sunt **parametri tehnici de siguranță**, nu „norme de productivitate” ori ponderi salariale; pot fi revizuite dacă datele reale demonstrează că sunt nepotrivite, cu documentare și teste.

Proprietarul a solicitat separat: **«Vreau să fie afișat și în profilul membrilor și când ajungem la acea categorie cu deciziile clarificăm mai multe».** Cerința **afișării** este aprobată; **comportamentul detaliat și permisiunile profilurilor sunt rezervate pentru categoria Profiluri/Membri**, nu stabilite acum de algoritmul statistic.

### 14.2 Metoda aleasă: Theil–Sen robust, cu control pe locație și verificare externă

**Alegere:** estimarea robustă de tip **Theil–Sen (mediana pantelor)** pentru relația `durata = a + b × m²`. Am preferat-o unei medii simple/regresii obișnuite deoarece o execuție excepțională nu ar trebui să domine randamentul orientativ. Funcționează bine cu seturi relativ mici, cu doar doi coeficienți, dar nu este magică: o populație majoritar atipică sau fără variație de m² nu produce un etalon credibil.

**Flux tehnic propus pentru implementare:**

1. **Eligibilitate pentru antrenare:** execuție unică, efectiv Finalizată, durată START–STOP strict pozitivă și plauzibilă (pentru început filtrul de 24 ore maxim deja folosit de Learning, de revizuit dacă datele reale cer), `keptForLearning` valid, m² de mochetă **verificabili la data fizică a curățării**, echipă/locație identificate. Excludem din **antrenarea curată a modelului de mochetă** intervențiile cu durată de fațadă nedistinctă; nu atribuim fațadei minute inventate. Refuzuri, așteptare pre-START, nerealizări și duplicări de retry nu sunt observații de antrenare.
2. **Configurații fizice:** data operațională definește luna, dar configurația și m² provin din versiunea fizică valabilă la momentul real al lucrării, păstrată minimal și versionată (schema concretă rămâne de proiectat). O reamenajare nu rescrie m² vechi. Dacă datele istorice nu permit asocierea certă a versiunii, acestea pot alimenta istoricul temporal, însă **nu** antrenează cu m² presupus.
3. **Nu lăsăm o sală frecvent curățată să domine:** agregăm la nivel de **locație × versiune de configurație**, cu **mediana** duratelor valide pentru acea configurație. În modelul comun, greutatea totală a unei locații fizice se limitează la o singură contribuție echivalentă; configurațiile vechi pot ajuta analiza istorică, dar nu primesc greutate suplimentară doar pentru că aceeași locație a fost reamenajată repetat. O variantă simplă implementabilă este o observație reprezentativă a configurației recente comparabile per locație; selecția exactă se testează și se documentează.
4. **Cohortă comparabilă:** pornim de la lucrări de **curățare mochetă** cu suprafețe/durate reale valabile și tip/categorie disponibilă. Dacă o categorie are suficiente locații independente și precizia o susține, folosim modelul ei; **nu comasăm automat categorii incompatibile** doar pentru a obține un procent. Un model mai larg este permis numai după testarea erorii sale pe lucrări din categoria țintă.
5. **Pragul tehnic conservator ales pentru a încerca estimarea completă a lui a și b:** cel puțin **6 locații fizice distincte**, **3 suprafețe distincte** și o variație între minimul și maximul suprafețelor de minimum **25% din mediana m²**. Acestea sunt bariere împotriva calculării unei pante arbitrare dintr-un set prea îngust; nu reprezintă promisiunea că 6 observații garantează precizie. Dacă pragurile nu trec, se folosește fallback-ul aprobat. Numărul de execuții repetate la o singură locație nu poate înlocui cele 6 locații independente.
6. **Calcul robust:** pe punctele independente rămase calculăm toate pantele `(t_j-t_i)/(m²_j-m²_i)` pentru suprafețe diferite, apoi `b=mediană(pante)`; `a=mediană(t_i-b*m²_i)`. Acceptăm modelul numai dacă `a >= 0`, `b > 0`, timpii rezultați sunt pozitivi în domeniul observat și verificările de calitate trec; **nu forțăm artificial** coeficienții negativi la valori pozitive care ar produce o normă fictivă.
7. **Validare pe date neutilizate la potrivire:** verificare de tip *leave-one-location-out* (excludem din potrivire întreaga locație evaluată, inclusiv toate versiunile ei), cu eroare relativă absolută **mediană cel mult 30%** în setul de verificare, plus revizuirea erorilor extreme și a diferențelor dintre categorii. 30% este un **prag de proiectare provizoriu**, nu un obiectiv sau o garanție; dacă puținele observații fac testul instabil, afișăm „date insuficiente / încredere redusă” și nu fabricăm un etalon.
8. **Fără auto-referință:** pentru estimarea unei echipe preferăm un set de comparație de la **alte echipe**, fără lucrarea, locația evaluată sau informații nepermise temporal. Dacă nu există suficiente locații independente în alte echipe, utilizăm doar **istoricul verificabil anterior** al propriei echipe ca reper orientativ *față de istoricul propriu*, excluzând execuția țintă și fără să permită mediei lunii curente să se auto-normalizeze automat la 100%. Dacă nici această referință nu este credibilă, se aplică fallback-ul Learning sau „Date insuficiente”. Modelul recalculat nu își antrenează referința cu propriul rezultat.
9. **Learning fără numărare dublă:** `learnedDurationEstimate` existent este contextual/local și necesită versiunea corectă de configurație. Dacă modelul comun verificabil există, acesta este **referința principală**; Learning local poate explica încrederea și semnala abaterea unei locații, dar **nu adunăm sau mediem arbitrar** două estimări provenite parțial din aceleași execuții. Când modelul comun lipsește, se aplică fallback-ul Learning aprobat, doar dacă acesta e verificabil. O ajustare combinată viitoare cere demonstrată o îmbunătățire independentă de precizie; nu este necesară pentru prima versiune.
10. **Robustețe și cost:** sortare și preagregare deterministe; calcul fără noi scrieri Firestore, cu cache/memoizare pe versiunea datelor. Estimatorul perechilor este O(k²), deci la istoric mare se folosesc **grupuri reprezentative determinate reproductibil** pe intervale de suprafață și perioade, ori o variantă optimizată echivalentă, fără eșantionare aleatoare la fiecare afișare; maximul și politica exactă de eşantionare se calibrează la implementare. Nu refacem complet toate cohortele la fiecare secundă de cronometru sau pe fiecare reconstruire de widget.
11. **Referință temporală:** evităm referințele din viitor pentru a pretinde că o estimare exista la START. Pentru scorul actual informativ se pot folosi **modele independente actualizate** la recalculare, explicând versiunea lor, dar nu inventăm m² istorici sau eligibilități noi doar din retrospectiva Learning; distincția dintre recalcularea unui reper valid și crearea retroactivă a unuia inexistent trebuie testată. Timestampurile și identitatea echipei nu sunt rescrise.

**Agregarea rămâne globală per echipă:**

```text
Randament(P) = dacă există perechi valide:
    min(100%, 100 × ΣT_ref(e) / ΣT_real(e)), numai pentru aceleași e în perioada P
altfel: „Date insuficiente”
P ∈ {luna operațională curentă, întregul istoric eligibil al echipei}
```

**Nici un randament procentual pe sală, nici minute-om ×2, nici indicator care decide venituri, prime sau sancțiuni.** Pentru fiecare procent se explică sursa etalonului (comun / istoricul propriu / fallback Learning), acoperirea și motivul excluderilor, fără false precizii statistice.

### 14.3 Rezultatele verificărilor numerice independente din această sesiune

Au fost rulate **8 verificări JavaScript, toate trecute (8/8)** pe seturi strict fictive, fără date reale:
- Regresie pe 6 locații independente cu durate `30+0,4×m²` a recuperat `a=30`, `b=0,4`.
- Un outlier sever (400 m²/600 min) adăugat la lot **nu** a modificat coeficienții în acest exemplu.
- Repetarea de **45 ori** a unei singure locații nu a dominat modelul, fiind agregată per configurație.
- Modelul a respins lipsa numărului minim de locații.
- A respins loturile unde toate suprafețele erau identice.
- A respins distribuția cu variație insuficientă a suprafețelor.
- A ignorat timpul negativ din antrenare.
- A tratat versiunea fizică nouă a unei locații ca observație distinctă înainte de limitarea pe locație în modelul comun.

**Nu înseamnă validarea calității pe date reale**, nu reprezintă teste Flutter/Firestore/CI și nu trebuie prezentate astfel. În special trebuie testate ulterior validarea leave-one-location-out, schimbările de echipă, outlier-e multiple și efectele în istoricul mare.

### 14.4 Cerință nouă pentru categoria Profiluri/Membri — AFIȘARE APROBATĂ, detalii AMÂNATE

- **Cerință explicită:** randamentele «Luna în curs» și «General» vor apărea **și în profilurile membrilor**, nu numai în Dashboard. Se reutilizează aceeași logică și aceeași versiune a valorilor, fără a implementa un calculator separat pe profil și fără scrieri duplicate.
- **Sensul valorilor:** indicatorul aprobat rămâne **al echipei**, nu performanța personală a membrului. Pe profil se va eticheta clar «Randamentul echipei». Un membru nou care vede randamentul general al **echipei sale actuale** nu trebuie să fie prezentat ca autor al tuturor intervențiilor istorice; un membru nu primește retroactiv un scor personal din lucrări vechi.
- **Cod read-only verificat:** `lib/profile/profile_page.dart` (profil propriu) primește deja `teams`, `records` și `widget.user.teamId`, și are secțiunea «Statistici angajat», ale cărei ore/zile sunt deja calculate din intervențiile echipei curente. `lib/members/member_profile_page.dart` (profilurile altor membri) folosește un stream separat din `users` sau `memberDirectory` și nu primește azi `teams`/`records`. Va necesita proiectată furnizarea **controlată** a acelorași două valori, cu permisiuni, date vizibile pentru vizitator, membru mutat/nehotărât, fără acces neautorizat la colecția `records` și fără listeneri costisitori per profil.
- **De stabilit ulterior în categoria Profiluri/Membri:** poziția și designul cardurilor, vizibilitatea pentru roluri și membri ascunși, prezentarea în profilul propriu vs al altuia, echipa curentă vs perioade de apartenență istorică, membrul fără echipă, explicațiile de încredere și versiunea mobil/web. **Nu se aprobă azi calcul statistic individual și nu modificăm acum ecranele**.
- **Atenție la eticheta existentă:** «Statistici angajat» prezintă acum ore și zile ale echipei curente; la faza de profiluri trebuie clarificată această semantică, fără să presupunem participare personală la fiecare intervenție istorică.

### 14.5 Statut și pași următori

- **Ales acum prin delegare:** familia estimatorului robust Theil–Sen, verificările minimale pentru suficiența datelor, referința comună când există și fallback fără auto-referință, integrarea Learning ca sursă de rezervă, plus cerința explicită de afișare în profilurile membrilor.
- **De validat tehnic înainte de implementare:** verificarea reală a pragurilor de 6 locații / 3 suprafețe / 25% interval / eroare mediană de 30%, alegerea cohortelor, precizia pe date reale, timpii mixt-fațadă, versiunile fizice, snapshotul de la START, securitatea/permisiunile profilurilor, volumul Firestore și testarea pe un mediu de test/staging. Dacă pragurile se dovedesc prea restrictive, le ajustăm **documentat**, nu inventăm rezultate.
- **Doar documentație în acest pas.** Niciun cod Flutter, Firebase, date reale, reguli de securitate, producție, APK ori deploy modificate. Cele 8 verificări sunt aritmetice pe seturi fictive; nu au fost rulate teste Flutter ori CI.

## 15. Durate mixte mochetă-fațadă: audit și alegere propusă, în așteptarea clarificării operaționale (2026-10-13)

> **STATUT:** analiză de cod și **PROPUNERE pentru aprobare**, NU decizie funcțională nouă confirmată. Utilizatorul a spus «Continuăm», după stabilirea statisticii și a profilurilor; asta autorizează analiza/documentarea, **nu** aprobarea automată a unei noi întrebări sau a unui nou buton.

### 15.1 Constatare read-only, verificată din surse

- `lib/dashboard/dashboard_page.dart::_startLocation` setează un singur `startedAt` când începe lucrarea, iar `_finishLocation` păstrează același START și salvează un singur `finishedAt`; la STOP, în implementarea **actuală**, întreabă necondiționat despre fațadă și salvează `facadeDone` DA/NU. Necondiționarea este deja un **defect cunoscut**, deoarece regula anterioară cere întrebarea **numai pentru fațadă planificată**.
- `lib/models/app_data_models.dart::CentralizerRecord` conține `facadePlanned` și `facadeDone`, dar **NU** are timp propriu de fațadă, delimitare a intervalului de mochetă versus fațadă, timestamp al fațadei efectuate ori flag verificat «aceeași durată conține fațadă». `duration` este strict `finishedAt-startedAt` pentru o intervenție `completed`.
- `lib/centralizer/centralizer_page.dart` permite creare manuală și corectarea orelor, dar nu atribuie minute separate fațadei. `lib/home/home_page.dart::_recordMap` scrie doar `facadePlanned/facadeDone` și START/STOP; nu există despărțire temporală.
- Prin urmare, **`facadeDone=true` NU dovedește singur că fațada a fost în interiorul START–STOP de mochetă**: poate să fi fost lucrată după STOP, mai târziu sau poate reprezenta o editare. La fel, `facadePlanned=true` NU dovedește că timpul de fațadă a fost efectiv inclus. Timpul mixt nu se poate reconstrui din boolean.
- Reguli deja aprobate: fațada este serviciu **adițional** cu status binar Realizată/Nerealizată, fără m² parțiali sau timp/procent de progres; un rezultat Nerealizată nu împiedică statusul de mochetă Finalizată ori STOP grafic; fațadele confirmate intră în Centralizator pentru facturare, iar revenirea ulterioară nu rescrie timpul mochetei; fără «pauză intervenție» pe START–STOP.

### 15.2 Algoritm de eligibilitate propus — conservator fără timp fictiv

Un interval de lucru de mochetă se clasifică în preprocesarea **randamentului**, diferit de statusul operațional și de facturare:

| Informația demonstrabilă pentru intervalul START–STOP | Antrenare Theil–Sen pentru mochetă | Randament mochetă |
|---|---|---|
| Doar mochetă finalizată, fără fațadă/alt serviciu în același interval, timp valid | Da, dacă și m²/configurația sunt verificate și alte condiții statistice trec | Da, dacă există `T_ref` valid |
| Fațadă planificată, răspuns NU, niciun alt serviciu în același interval | Da, după celelalte verificări | Da, după fallback-ul aprobat |
| Fațadă efectuată ulterior într-o vizită distinctă, **dovedită în afara intervalului mochetă** | Da pentru intervenția de mochetă curată | Da; niciun efect retroactiv al fațadei |
| Fațadă efectuată **în interiorul** aceluiași interval START–STOP, fără timp separat credibil | **Nu** | **Nu** — exclusă **atât durata reală cât și referința** din procent; rămâne muncă operațională Finalizată |
| Moment fațadă incert la o execuție veche cu `facadeDone=true`, fără audit temporal | **Nu** până când există o separare verificabilă | **Nu** dacă durata nu poate fi demonstrată ca exclusiv de mochetă; motiv «timp mixt/neclar» |
| Lucrare numai de fațadă la revenire | Nu este observație de mochetă | Nu afectează scorul mochetei, dar intră în evidența fațadei realizate |

**Important:** A exclude o pereche din etalon/scor pentru lipsă de separare temporală **NU** anulează statusul lucrării, nu micșorează suprafața totală facturabilă a fațadei, nu șterge istoricul și nu penalizează echipa cu 0%. Pentru afișaj se arată acoperirea și motivul, separat de procent. Dacă datele neclare domină, este posibil «Date insuficiente»; fiind indicator informativ, **integritatea e preferabilă unui procent arbitrar**.

### 15.3 Simulare matematică (date strict fictive)

O curățare de mochetă are `T_ref=60 minute` și `T_mochetă=50 minute`. O fațadă adițională a durat **30 minute**, dar timpul său **NU** este disponibil în schema actuală; valoarea este exclusiv cunoscută în scenariul fictiv pentru a demonstra eroarea.

- Dacă înregistrăm greșit totul ca o singură execuție de mochetă, `T_real=80` și scorul devine **75%** (`60/80`).
- Dacă am avea durată reală demonstrabilă a mochetei, aceasta ar fi 50 minute, scor **100%** după plafonare (`60/50=120%` plafonat). Însă **schema actuală nu ne permite să scădem cele 30 minute în mod legitim**, deci **nu aplicăm niciun scăzământ inventat**.
- Dacă fațada a fost efectuată ulterior, separat de cele 50 minute de mochetă, scorul mochetei rămâne **100%**; fațada apare numai în evidența sa.
- În algoritmul propus, o execuție mixtă nedelimitată **nu intră în niciuna dintre sumele** `ΣT_ref` și `ΣT_real`. Nu se face medie de procente pe săli.

Au trecut **5/5 verificări JS** pe aceste scenarii: interval curat, eroarea 75% din mixt, excluderea mixtului, păstrarea scorului la revenire separată și excluderea simultană a ambilor termeni. **Acestea sunt exemple aritmetice, nu teste Flutter/Firestore/CI.**

### 15.4 Posibile interfețe viitoare, de decis doar după răspunsul operațional al utilizatorului

- **Varianta fără butoane suplimentare:** dacă fațada este planificată, STOP cere DA/NU numai conform regulilor existente. În caz DA, dacă nu se poate stabili în mod cert când a fost făcută, execuția este marcată «mixt/neclar» și neeligibilă pentru randament. Simplă, dar poate reduce acoperirea.
- **Variantă cu o singură clarificare contextuală (recomandată dacă situația apare des):** numai când fațada planificată este confirmată DA se solicită minimal «Fațada a fost executată în timpul intervalului START–STOP al mochetei?» cu opțiuni DA/NU/NU ȘTIU; NU ȘTIU este tratat conservator, nu ca NU. Aceasta nu adaugă buton de pauză, contor pentru fațadă ori executare parțială. Opțiunile și momentul întrebării **nu sunt aprobate**; înainte de design se întreabă operatorul cum se desfășoară fizic munca.
- **Alternativă după observație operațională:** dacă echipele execută mereu fațada după STOP mochetă, se poate modela un eveniment separat binar al fațadei, cu data reală, fără cronometru suplimentar; dar această premisă **nu este cunoscută și nu trebuie impusă**.

### 15.5 Întrebare funcțională încă deschisă

**Când echipa efectuează fațada în aceeași vizită, o curăță de regulă înainte de STOP-ul mochetei sau după STOP?** Răspunsul stabilește dacă se poate păstra intervalul curat fără verificări suplimentare ori dacă avem nevoie de marcaj explicit al timpului mixt, fără timpi inventați.

**Până la răspuns:** acesta este un **proiect de regulă**, nu o condiție aprobată de utilizator și nu cod de implementat. Modul în care confirmăm fațada, câmpurile noi, permisiunile de editare, revenirea ulterioară și afișarea în profiluri rămân conforme cu deciziile deja luate și etapele proiectului. Fără modificări cod, Firebase, reguli, producție sau deploy.

## 16. Clarificare reală: cele două activități se desfășoară în paralel (2026-10-13)

> **ACTUALIZARE ULTERIOARĂ (2026-10-13), vezi secțiunea 17:** proprietarul a CONFIRMAT varianta recomandată de includere a intervențiilor mixte simultane în **aceleași două randamente**, numai când există referință mixtă credibilă. Formulările din această secțiune care așteptau aprobarea includerii sunt istoricul propunerii și sunt depășite de secțiunea 17. Tot ulterior s-a cerut **evidența separată pe fiecare componență istorică de echipă în profiluri**, cu suprafața de mochetă cumulată.


> **FAPT OPERAȚIONAL CONFIRMAT, CU EFECT ASUPRA PROIECTĂRII:** răspunsul proprietarului la întrebarea din secțiunea 15 a fost: **«De obicei fațadele sunt făcute în același timp cu mocheta, cei 2 membrii își împart atribuțiile».** Aceasta descrie o intervenție cu muncă **concurentă**, nu două lucrări făcute succesiv. «De obicei» înseamnă că **nu toate** intervențiile trebuie presupuse automat mixte/concurente.

### 16.1 Efectul asupra regulilor anterioare (precizare nouă obligatorie)

1. Echipă operațională de **maximum doi membri**. Când este **numai mochetă**, participarea ambilor la curățarea normală rămâne regula deja stabilită. Când există **mochetă + fațadă simultan**, cei doi membri participă la **aceeași intervenție a echipei**, însă **își împart atribuțiile**: un membru poate curăța mocheta în timp ce celălalt fațada, eventual alternând sarcinile. **Nu presupunem că ambii curăță mocheta în același moment**. Această clarificare de utilizare reală **completează și limitează explicit** formularea prea absolută «ambii membri curăță mocheta la fiecare locație» din regulile anterioare, pentru vizitele mixte; nu presupune permiterea unei echipe operaționale de un singur om.
2. Cronometrul unic `startedAt → finishedAt` măsoară **timpul calendaristic al intervenției echipei**, nu suma minutelor de muncă ale membrilor. Pentru două activități paralele, `durata_totală ≠ durata_mochetă + durata_fațadă`. Într-un exemplu teoretic perfect sincronizat, 80 min mochetă + 60 min fațadă paralele duc la ~80 min calendaristice, **nu** 140 min. În practică pot exista pregătiri, schimburi de sarcini sau etape, deci nici formula `MAX` nu este adevăr general / date măsurate.
3. **Fără minute fictive** alocate mochetei/fațadei, fără înmulțirea intervalului cu doi, fără „pauză” a intervenției, fără cronometru obligatoriu pe membru, fără procent personal și fără transformarea fațadei într-o lucrare parțială. Fațada rămâne serviciu **adițional cu DA/NU**, evidențiat pentru facturare când a fost efectiv realizat.
4. **Nu mai este potrivită ca soluție implicită respingerea tuturor intervențiilor mixte**, deoarece proprietarul a clarificat că sunt frecvente și ar duce la pierderea unei părți importante din istoric. **Totuși** includerea lor într-un randament declarat anterior «exclusiv pentru curățarea mochetei» reprezintă o **extindere semantică** și **necesită validarea proprietarului** înainte de implementare. Nu interpretăm faptul operațional drept aprobare pentru includerea procentuală a muncii de fațadă.

### 16.2 Algoritmul recomandat, PROPUNERE pentru decizia următoare

**Modele interne pentru două moduri distincte de intervenție, dar în continuare DOAR două procente afișate ale echipei**:

- **Mochetă simplă:** `T_ref_carpet = a_carpet + b_carpet × m²_mochetă`, coeficienți estimați robust prin metoda Theil–Sen aleasă, cu Learning compatibil cu versiunea fizică și fallback-ul deja aprobat.
- **Mochetă + fațadă în paralel (mixt):** `T_ref_mixed` este **durata de referință pentru intervenția simultană ca întreg**, învățată **numai din alte intervenții mixte comparabile**, fără a deduce direct minute de fațadă sau a presupune că două durate se adună. Dacă există suficiente cazuri independente, o primă aproximație poate fi un model Theil–Sen distinct `a_mixed + b_mixed × m²_mochetă`, **comparabilitatea fiind condiționată și de tipul/configurația lucrării de fațadă**. `Location.facadeM2`, **numai dacă este măsurat fiabil**, poate ajuta la grupare/modelare ca **suprafață distinctă**; nu se însumează cu `surfaceM2`. Lipsa m² de fațadă nu primește 0 fictiv și nu justifică extrapolări arbitrare.
- **Alegerea modelului:** numai dintr-un marcaj/istoric verificabil **«doar mochetă / mixte simultane / fațadă ulterior»**, fără a deduce automat concomitența din `facadePlanned=true` sau `facadeDone=true`. Evenimentul ulterior de fațadă trebuie păstrat distinct, iar corecțiile statusului nu schimbă implicit intervalul curățării mochetei. Cum captăm aceasta **rămâne de decis**, cu efort UI minim și fără butoane care să dubleze START/STOP.
- **Calitate:** modelele sunt antrenate independent pe date istorice certe și clase similare. Fără suficiente cazuri mixte pentru o referință comparabilă, **nu aplicăm modelul de mochetă pură unui START–STOP mixt**; contribuția mixtă rămâne neeligibilă pentru procent până când apare etalon credibil, fără a elimina evenimentul din Centralizator. Istoricul și Learning pot să crească treptat gradul de acoperire. Nu inventăm coeficienții și nu tratăm refuzuri ca finalizări.
- **Agregare propusă:** dacă utilizatorul aprobă includerea lucrărilor mixte în indicatorul informativ, perechile `T_ref_carpet/T_real_carpet_only` și `T_ref_mixed/T_real_mixed` se pot **însuma împreună**, înaintea plafonării la 100%, separat pentru «Luna în curs» și «General», fără procent pe sală și fără un al treilea procent pentru fațadă. Eticheta indicatorului trebuie să reflecte onest faptul că măsoară **eficiența curățării efectuate de echipă în locație**, inclusiv vizitele în care fațada și mocheta sunt simultane — **nu** un cronometru izolat al mochetei. **Această extindere NU este aprobată acum.**

**Alternativa compatibilă strict cu „numai mochetă”:** intervalele mixte nelimitate temporal rămân în evidența operațională și în Learning al regimului mixt (nu în modelul pur), dar **nu intră în randamentul exclusiv al mochetei**; pe UI se arată acoperirea. Această variantă evită amestecarea serviciilor, însă poate pierde multe lucrări din scor. Alegerea între cele două **necesită proprietarul**, fiind o diferență de sens al procentului.

### 16.3 Simulare simplă (numai numere fictive)

- Lucrare **numai mochetă**: timp de referință 80 min, timp real 90 min ⇒ dacă este singura eligibilă: **88,89%**.
- Lucrare **mixtă simultană**: timp de referință comparabil învățat **din alte lucrări mixte** 110 min, timp real comun 100 min ⇒ raport brut 110%, plafonat 100% în cazul separat de test. **Nu reprezintă două durate individuale însumate.**
- Dacă este **aprobată** includerea tipului mixt și ambele referințe sunt valide, agregarea celor două perechi este `min(100%, 100×(80+110)/(90+100)) = 100%`, **un singur procent per perioadă**.
- **Greșeală:** aplicarea directă unui interval mixt a unui etalon de **mochetă pură** de 80 minute ar da `100×(80+80)/(90+100) = 84,21%` și ar putea penaliza artificial o echipă care a executat simultan și fațada.
- Dacă rămânem la regula **strict numai mochetă**, se evaluează exclusiv lucrarea de mochetă pură, adică 88,89%; intervenția mixtă este evidențiată separat, nu «refuzată».

**Verificări matematice JavaScript independente (4/4) pe aceste exemple fictive:** interval paralel nu este suma duratelor, agregare plafonată, comparație greșită pur-versus-mixt penalizantă și excluderea perechii mixte dintr-un etalon pur. **Nu s-au testat date reale, Dart/Flutter ori CI.**

### 16.4 Decizie de produs solicitată în continuare

**Întrebarea necesară este despre sensul procentului, nu despre cum lucrează echipa:** preferă proprietarul să includem și intervențiile mixte în **aceleași două randamente ale echipei, dar numai dacă au etalon mixt comparabil și fără minute inventate** (recomandat pentru acoperire), **sau** să păstrăm randamentul strict numai al mochetei, excluzând perioadele mixte fără interval de mochetă distinct?

**În această sesiune s-a decis DOAR faptul operațional al lucrului simultan și împărțirii atribuțiilor.** Alegerea includerii mixte, modalitatea de înregistrare și cohortele statistice rămân de aprobat. Fără Dart/Firebase/reguli de securitate/backup/deploy.

## 17. Confirmare intervenții mixte și indicatori pe componențe istorice de echipă (2026-10-13)

### 17.1 Intervenții mixte simultane — VARIANTA RECOMANDATĂ, CONFIRMATĂ

După recomandarea de a include curățările de mochetă și fațadă făcute **în paralel** în cele **două procente informaționale** ale echipei, numai cu **etalon mixt comparabil** și fără minute fictive, proprietarul a răspuns: **«Confirm varianta de mai sus dată de tine»**. Confirmarea privește varianta recomandată, nu ordinea din exemple, un model numeric concret sau un buton suplimentar.

**Regula de calcul funcțională aprobată:**
- Pentru **numai mochetă**, reperul este `a_pur + b_pur × m²_mochetă`, învățat robust din lucrări de mochetă comparabile.
- Pentru **mochetă + fațadă simultan** în același START–STOP, reperul este **durata totală de referință a intervenției mixte** învățată din **alte intervenții mixte comparabile**, fără a deduce minute individuale, fără a aduna durate sau metri pătrați ai două servicii și fără a folosi automat norma de mochetă pură. Antrenarea și validarea statistică a cohortelor mixte rămân de calibrat cu date reale; Theil–Sen este metoda robustă aleasă ca punct de plecare. Mărimea fațadei, dacă există și este verificată, este o caracteristică SEPARATĂ a comparabilității, nu un adaos la m² de mochetă.
- Dacă o vizită mixtă **nu are un etalon mixt verificabil**, se aplică regula aprobată pentru informații insuficiente: rămâne în Centralizator și evidența pentru facturarea fațadei, dar perechea `T_ref / T_real` **nu intră** în randament până când sursele admise pot fundamenta etalonul. Nu se fabricate 0%, 100% sau minute de fațadă.
- Dacă există perechi eligibile în ambele moduri, ele pot contribui la **aceleași două totaluri agregate** și la **exact două procente** per domeniu istoric evaluat: «Luna în curs» și «General», cu plafon 100%. Indicatorul măsoară **eficiența curățării echipei la locații**, incluzând vizite în care cei doi împart atribuțiile între mochetă și fațadă; nu pretinde că fiecare minut al unei vizite mixte a fost exclusiv de mochetă.
- Nu se adaugă procent separat pentru fațade, durată pe persoană, cronometre individuale ori execuții parțiale de fațadă. Statusul fațadei este binar DA/NU, iar revenirea și facturarea rămân evidențe distincte.
- Nu se deduce automat «mixt simultan» pentru orice `facadeDone=true` ori `facadePlanned=true`, întrucât unele fațade se fac ulterior sau sunt doar planificate. Pentru viitor se va proiecta identificarea minimală și verificabilă a modului fizic de lucru; istoricul incomplet rămâne cu gradul său real de incertitudine.

### 17.2 CERINȚĂ NOUĂ CONFIRMATĂ: în profil, istoricul este separat PE FIECARE COMPONENȚĂ DE ECHIPĂ

**Exemplul proprietarului:** dacă a lucrat o lună cu **Daniel**, iar luna următoare cu **Andrei**, în profilul său se afișează **două secțiuni distincte**, una pentru componența cu Daniel și alta pentru cea cu Andrei. Pentru **fiecare componență realizată**, lângă randament se afișează **suprafața totală a mochetei curățate cu acea componență**. La schimbări viitoare de partener pot apărea alte secțiuni.

**Reguli de încredere și calcul care decurg din cerință:**
1. **Identitatea componenței se bazează pe membrii REALI prezenți la lucrare**, identificați prin ID-uri stabile, nu pe denumirea echipei, ordinea numelor, `Team.members` curent ori `AppUser.teamId` curent. Pentru perechi, cheia logică este perechea NEORDONATĂ de ID-uri verificate: {membru A, membru B}. Dacă aceeași pereche se reface ulterior, **propunere de prezentare**: în dreptul aceleiași componențe se pot cumula intervalele sale neconsecutive, cu perioadele afișate distinct la detalii. Această opțiune exactă de grupare rămâne de clarificat în categoria Profiluri dacă proprietarul preferă câte o intrare pe episod separat.
2. **Un membru + Daniel** și **același membru + Andrei** nu amestecă nici timpii, nici lucrările, nici m². Indicatorii din profil pentru fiecare componență reutilizează același motor de referințe C (inclusiv mixed); se agregă **numai perechile valid atribuite componenței**. Nu se inventează un scor personal al membrului separat de partenerul real.
3. **Pentru fiecare componență:** se păstrează cele două ferestre aprobate, **«Luna în curs»** (doar execuțiile acelei perechi din luna operațională prezentă) și **«General»** (întreg istoricul verificabil al aceleiași perechi), maximum 100%, cu «Date insuficiente» când nu există perechi de durate de referință și reale valide. Pentru foste componențe care n-au lucrat luna aceasta, procentul lunar rămâne «Date insuficiente» / fără activitate actuală, iar General rămâne vizibil când există referințe.
4. **m² total de mochetă** este alt indicator decât scorul și se poate însuma pentru **toate intervențiile efectiv Finalizată, cu suprafață cunoscută și corectă la acea dată** sub acea pereche — inclusiv o vizită mixtă cu mochetă finalizată, chiar dacă nu are încă etalon pentru randament. **Fiecare intervenție unică se numără o singură dată**; dacă aceeași sală a fost curățată în două vizite distincte, suprafața ei se însumează de două ori, ca **volum de muncă prestat**, nu ca suprafață fizică unică a portofoliului.
5. **Suprafața istorică NECUNOSCUTĂ** nu se interpretează ca `0` real și nu este completată retroactiv cu `Location.surfaceM2` de azi; afișăm «m² documentați cunoscuți» plus câte intervenții au m² neidentificabili / «total incomplet», fără a pretinde că subtotalul este exact întregul volum.
6. **Participare și mutări istorice:** modificările de componență nu redistribuie retroactiv lucrările. Nu atribuim unui nou partener intervenții efectuate de echipa anterioară. Pentru vechile `CentralizerRecord` fără participanți identificați istoric nu inventăm perechi; acestea rămân în Centralizator, dar în rapoarte pe parteneriat vor fi «participanți istorici neconfirmați» până există dovezi autorizate independente.
7. **Dashboard pe echipă rămâne distinct** de profilul pe parteneriate: două procente pentru identitatea operațională a echipei; în profil sunt afișate **două procente pentru fiecare componență istorică**, cu aceleași reguli de eligibilitate și de încredere, dar filtrate după componența efectivă. Nu pretindem că sunt numeric egale dacă echipa și-a schimbat membrii.

**Limită verificată în cod:** `Team.members` conține doar componența curentă; `AppUser.teamId` descrie apartenența curentă; `CentralizerRecord` conține `teamId/locationId/START/STOP/facadeDone`, dar **nu** conține lista participanților sau snapshot-ul suprafeței mochetei și al versiunii configurației. De aceea, **nu se poate implementa corect statistica istorică a perechilor din datele actuale singure**. Necesită proiectare pentru evidența istorică a participării/schimbărilor și m² la momentul intervenției, cu compatibilitate legacy, permisiuni și audit. Nu se reconstituie istoria prin asocierea tuturor recordurilor unui `teamId` cu cei doi membri de azi.

### 17.3 Ce se stabilește în categoria PROFILURI/MEMBRI

**Regulă funcțională cerută de proprietar:** informațiile din profilul personal al fiecărui membru sunt vizibile și celorlalți membri autentificați ai aplicației, iar **fiecare membru poate alege individual ce elemente își ascunde față de colegi**. **Administratorul autorizat poate vedea și informațiile ascunse celorlalți**, fără ca alegerea unui membru să elimine datele din propria evidență sau din administrare. Nu interpretăm «vizibil colegilor» drept vizibil pe internet/public neautentificat.

**Principii de implementare obligatorii pentru proiectare:**
- Control de vizibilitate **pe câmp/element/indicator**, nu doar un comutator pentru întreg profilul. Exemplu: telefon vizibil, data angajării ascunsă, link Instagram vizibil, link Facebook ascuns, randament pentru o anumită componență vizibil/ascuns conform granularității ce urmează a fi aprobată. Administratorul poate vizualiza integral datele permise rolului său. Se păstrează separată posibilitatea de a edita un câmp de dreptul de a-l citi.
- **Ascunderea trebuie aplicată în sursa autorizată / proiecția serverului și regulile de acces**, nu doar prin eliminarea widgetului din profil; altfel un coleg ar putea citi câmpul ascuns din `memberDirectory`, cache, listări sau link direct. Nu expunem neintenționat date individuale, diurne, identificatori sau alte câmpuri private prin proiecții/publicări. Pentru date financiare, contacte și alte date personale pot fi necesare opțiuni implicite de confidențialitate / restricții legale, de stabilit în categoria Profiluri, înainte de a publica orice câmp nou.
- Se aplică identic **profilului propriu** și **profilului altui membru**, pe Android/web și celelalte platforme, cu testele administrării rolului, limitele vizibilității proprii și stările offline. De verificat expunerea în lista membrilor, căutare, exporturi, PDF, cache și notificări, nu doar în ecranul profil.
- Necesare din perspectivă UX: setările personale de ascundere pe elemente (cu explicație clară), previzualizare «cum văd colegii» vs «cum vede administratorul» dacă se justifică, și protecția împotriva accesului la date de profil când utilizatorul nu are drept.
- **Nu presupunem acum că toate datele din Firebase `users` sunt în prezent publice ori că actuala colecție `memberDirectory` are filtrare per câmp**. Este o cerință viitoare, nu un comportament implementat.

**Linkuri și iconuri sociale — CERINȚĂ CONFIRMATĂ:**
- La un câmp de tip link, **platforma cunoscută trebuie să aibă iconul/logo-ul corespunzător** în locul pictogramei generice/linkului textual lung: Facebook, Instagram, TikTok, YouTube, LinkedIn, X/Twitter, WhatsApp, Telegram, GitHub etc., în funcție de domeniul real al linkului.
- **Dacă linkul nu este recunoscut**, alegem un **icon neutru de glob/link extern**, nu logo Google, deoarece un site necunoscut nu este neapărat un site Google. Aceasta este alegerea tehnică delegată implicit prin «sau ce consideri relevant».
- Identificarea pe `Uri.host` normalizat + domeniu/subdomeniu efectiv, **nu după text arbitrar** din eticheta introdusă de utilizator sau după simpla prezență a textului «facebook» în alt domeniu (antiphishing). Click/tap deschide linkul original valid în siguranță (scheme HTTP(S) acceptate), cu semantică accesibilă (tooltip «Deschide Instagram» etc.); pentru URL invalid arătăm eroare/nu îl deschidem.
- Folosim resurse vizuale legal reutilizabile, proporționate, cu suport offline/fallback; **nu descărcăm logo-uri de pe site-uri necunoscute la fiecare afișare**. Nu transmitem date sensibile către terți numai pentru a decide iconul. Aceeași prezentare în profilul propriu și în profilul altui membru.

**Cod verificat:** `lib/profile/profile_page.dart` permite câmpuri `profileFields` cu `label/value/type` și le prezintă ca `Icons.link`; `lib/members/member_profile_page.dart` folosește aceleași valori în `memberDirectory` / `users` și arată generic `Icons.link`. Profilul propriu calculează statistici din echipa **curentă**, nu din istoria membrilor. Nu există în aceste pagini filtrarea per element sau recunoașterea platformei sociale. `hiddenFromMembers` actual ascunde un profil în unele situații, **nu** oferă opțiuni de vizibilitate pentru fiecare câmp. Securitatea serverului/proiecției trebuie auditată, nu dedusă doar din widgeturi.

### 17.4 Exercițiu reproductibil pe date fictive, fără Firebase

Într-o simulare JavaScript fără acces la date reale: o pereche de membri cu Daniel curăță 100 m², apoi 120 m² și, **după un interval cu alt partener**, încă 80 m² ⇒ **300 m² cunoscuți** pentru aceeași pereche. O pereche cu Andrei curăță 75 m² și 50 m² ⇒ **125 m² cunoscuți**, într-o secțiune separată. O intervenție Daniel fără suprafață cunoscută marchează subtotalul ca incomplet, un refuz nu este volum executat, iar o intervenție veche fără lista verificată de participanți nu este atribuită automat niciunei perechi. **6/6 aserțiuni JS au trecut**, fără teste Flutter/Firestore/CI. Sunt numai exemple de algoritm, nu rezultatele echipelor reale.

### 17.5 Stare și decizii de amânat

**Confirmate acum:** includerea condiționată a intervențiilor mixte simultane în cele două procente, afișare în profil pe fiecare componență efectivă cu suprafață cumulată de mochetă curățată, câmpuri vizibile colegilor cu ascundere selectivă aleasă de titular (dar vizibile adminului autorizat), iconuri de platforme recunoscute și fallback neutru pentru linkuri necunoscute. Nu se pierde istoricul la schimbarea partenerului.

**De clarificat când ajungem la categoria Profiluri/Membri:** câmpurile obligatoriu operaționale vs opționale de ascuns, politica de confidențialitate implicită pentru informații sensibile, cum prezentăm intervalele cu aceeași pereche reunită, ce facem cu membri fără partener sau vizibilitatea profilurilor ascunse, sursele/auditul pentru istoricul vechi, etichetele exacte și designul. Schema/permisunile, migrarea și testarea se proiectează înainte de implementare. **Numai documentație, fără modificări Flutter, Firebase, reguli sau deploy.**

## 18. Proiectarea evidenței temporale pentru parteneriate și m² curățați (analiză tehnică 2026-10-13, fără implementare)

### 18.1 Scop și statut

**Cererea «Bun, mergem mai departe» autorizează continuarea analizei și a documentării, nu o migrare Firebase sau un nou format de profil impus.** În baza cerințelor funcționale aprobate în secțiunea 17 (profil separat pe fiecare componență reală de membri, total m² mochetă, randament luna curentă/general), alegem o **reprezentare istorică minimă și verificabilă** drept **propunere tehnică**, de validat la implementare. Nu schimbăm cele două procente și nu introducem performanță salarială ori un procent personal.

### 18.2 Auditul sursei actuale (citire doar, fără date Firestore reale)

- `lib/models/app_data_models.dart::Team.members` și `AppUser.teamId` descriu componența/apartenența **curentă**. `CentralizerRecord` păstrează `teamId`, `locationId`, `startedAt/finishedAt`, `facadePlanned/facadeDone`, dar **nu** cei doi participanți istorici, configurația fizică, suprafața mochetei la START sau modalitatea efectivă (numai mochetă versus mochetă+fațadă concomitent).
- `lib/admin/admin_team_actions.dart::_editTeam` salvează lista curentă `members` și poate elimina un utilizator din alte echipe, **fără revizii temporale de componență**. Aceasta este o deficiență deja documentată față de regulile de transfer. Nu presupunem că evenimentele de audit existente sunt suficiente să reconstruiască fiecare perioadă istorică.
- `lib/admin/admin_location_actions.dart::_editLocationAdmin` editează `surfaceM2` și `facadeM2` curente, fără revizii istorice. `lib/home/home_page.dart::_recordMap` nu scrie snapshoturi m² sau participanți, iar `_teamMap` persistă doar componența curentă.
- `lib/profile/profile_page.dart` numără acum lucrările echipei **curente** din `teamId`, nu intervențiile unui parteneriat istoric. `lib/members/member_profile_page.dart` nu primește în prezent istoricul de intervenții.
- `lib/utils/operational_dates.dart::operationalWorkDate` trece ziua **următoare** pentru START la/după 23:30, iar ziua operațională este sursa ferestrei lunare; un START la 23:40 pe 30 septembrie poate aparține **lunii octombrie**. Nu folosim pur și simplu luna civilă a lui `startedAt` în noile statistici.

### 18.3 Propunere de contract de date minimal, fără scrieri repetitive

**A. Istoricul componenței, schimbări doar la evenimente reale autorizate:** când un administrator creează/modifică/transferă/înlocuiește membri, salvăm un eveniment/revizie mică cu echipa, lista de ID-uri, `validFrom` efectiv, actorul, motivul dacă e necesar și ID-ul reviziei. Intervalul anterior se încheie logic, fără rescrierea intervențiilor și fără duplicarea documentelor de identitate. Mutările trebuie să respecte blocarea pe grafice deschise și excepțiile admin deja aprobate, cu tranzacție/serializare pentru două dispozitive.

**B. La START real al curățării:** intervenția capătă o **identitate stabilă** și un set minimal de fapte istorice, păstrate la orice STOP/retry:
- `teamId` (deja există) și `compositionRevisionId` / as-of al componenței;
- **ID-uri de membri din componența la START** (roster) și separat **ID-uri de participanți efectiv verificați** ori un marcaj `participantsEvidence`. **Lista echipei nu este dovadă automată că amândoi au lucrat**. În mod normal sunt maxim 2; împărțirea mochetă/fațadă simultană este validă.
- `carpetSurfaceM2AtStart` dacă este verificabilă, cu identificatorul versiunii fizice `locationConfigurationRevisionId` sau sursă echivalentă; starea «necunoscută» este distinctă de o suprafață fizică de 0 m²;
- `workMode`/clasificare credibilă a intervenției: doar mochetă, mochetă+fațadă concomitent, fațadă ulterior, respectiv «neconfirmat», păstrând separat rezultatul binar al fațadei; **nu** deducem simultaneitatea numai din `facadeDone=true`;
- momentul fizic de referință și proveniența/gradul de verificare, fără stocarea inutilă a întregii locații, profilurilor ori minutelor pe membru.

**C. La STOP:** se completează rezultatul real și intervalul final. **Nu recitim automat membrii actuali sau suprafața actuală pentru a suprascrie faptele de la START.** Dacă la START datele proveneau din cache vechi/offline și între timp a apărut un transfer ori o reamenajare cu dată efectivă anterioară, păstrăm sursele și marcăm **«necesită reconciliere verificabilă»**; corecția administrativă trebuie auditata, nu făcută tacit. Dacă înlocuirea a intervenit în timpul execuției, nu atribui intervenția unui partener doar pe baza apartenenței la STOP: participarea reală necesită clarificare. Nu cerem doi timpi START/STOP și nu schimbăm regula fără pauză.

**D. Legacy:** refacem componența/suprafața numai când un audit istoric verificabil, datat și univoc susține atribuirea. Lipsa acestei dovezi => intervenția rămâne în Centralizator și statistica generală de echipă, dar poate fi **neatribuibilă unui parteneriat concret** ori cu volum m² **incomplet**. Nu construim istoria perechilor cu `Team.members` de astăzi și nu aplicăm retroactiv m² actuali.

**E. Cost și securitate:** preferăm câteva valori scalare mici în documentele de intervenție viitoare și **revizii numai când componența/configurația se schimbă**, nu document separat pentru fiecare procent/refresh. Agregări în citire/cache; pentru accesul la istoricul altui membru folosim un rezultat autorizat și filtrat, nu deschidem colecția completă `records` pentru toți și nu expunem câmpurile ascunse din profil în `memberDirectory`. Alegerea exactă între câmpuri pe record și subcolecții se verifică la implementare cu limitele documentelor și compatibilitatea.

### 18.4 Cheile statistice și actualizarea lunară

- **Componență:** identificator logic al perechii = ID-urile **verificate** ale membrilor, ordonate canonic; schimbarea numelui, a numărului echipei sau a rolului nu alterează perechea. În prezentare, reunirea aceleiași perechi după un interval este **opțiune tehnică propusă**, cu episoadele distincte păstrate pentru detalii. Proprietarul poate alege ulterior afișări separate pentru episoade la categoria Profiluri/Membri.
- **Volumul de mochetă:** suma `carpetSurfaceM2AtStart` pentru fiecare **execuție unică Finalizată** atribuită acestei perechi, inclusiv cele mixte cu mochetă terminată, **indiferent dacă există etalon pentru procent**. O aceeași sală curățată la două date în două intervenții reale se numără de două ori în m² executați; `facadeM2` **nu** se adună. Afișăm câte execuții au m² necunoscuți și eticheta «suprafață documentată; total incomplet» când e cazul.
- **Randamentul profilului per parteneriat:** pentru aceeași pereche, «Luna în curs» selectează după **data operațională a lucrării** în România și «General» după toate perechile timp referință/timp real eligibile atribuite sigur acestei componențe. Rămâne `MIN(100%,100×ΣT_ref/ΣT_real)` pe aceleași intervenții, nu o medie de procente de sală ori de echipă; date insuficiente => «Date insuficiente». Randamentul `teamId` din Dashboard rămâne separat și nu se redistribuie retrospectiv către parteneri.
- **Partajarea informației:** datele aceleiași intervenții pot apărea în profilele **ambilor participanți** fără să devină două lucrări distincte în statisticile globale. Dacă unul își ascunde cardul față de colegi, nu presupunem că acesta poate controla automat ce este vizibil în profilul altui participant; **conflictul de vizibilitate a datelor comune se decide la categoria Profiluri**. Administratorul autorizat are acces conform drepturilor lui.

### 18.5 Teste de logică executate separat, pe date fictive

**11/11 aserțiuni JavaScript trecute** pentru un set de intervenții simulate: perechea «Ion + Daniel» acumulează 260 m² cunoscuți (100 + 100 + 60), deși schimbă `teamId` și sala de 100 m² devine ulterior 60 m², iar 160 m² dintre acestea aparțin lunii octombrie, deoarece lucrarea din 30 septembrie la **23:40** are dată operațională **1 octombrie**. Perechea «Ion + Andrei» are separat 170 m² de mochetă, incluzând o vizită mixtă cu fațadă de 220 m² ce **NU** intră în volum. S-a verificat și: suprafață necunoscută marcată, refuz necontabilizat, veche componență neidentificabilă rămasă neatribuită, retry offline cu același `recordId` nedublat, reîntâlnirea aceleiași perechi în alt `teamId`, plus tranziția 23:20 / 23:30 la limita lunii.

**Acestea sunt teste de logică într-o simulare, nu teste de cod Flutter, Firestore, regulile de securitate, CI sau date reale.** Nu este garantat că toate cazurile vor trece în aplicație înainte de implementare; vor fi obligatorii și teste de transfer concurent, offline, duble apăsări, snapshot întârziat, editări retroactive, forme mixte, excepții, profilurile ambilor membri și confidențialitate.

### 18.6 Etapa următoare

**Decizii funcționale existente rămân aprobate** (indicatori per parteneriat, m² curățați, lucrări mixte comparate cu mixte, transparență, posibilitatea de ascundere selectivă și acces admin). **Soluția de stocare temporală propusă în această secțiune nu a fost implementată și nu este schemă Firebase final aprobată.**

Următoarea problemă majoră de proiectare la categoria Profiluri/Membri este **cum arătăm aceleași date comune în profilurile ambilor parteneri atunci când unul alege să le ascundă** și **ce elemente au implicit caracter public intern versus privat**, cu control efectiv în backend, nu doar în UI. Fără modificări Dart, Firebase, security rules, date de producție ori deploy.
