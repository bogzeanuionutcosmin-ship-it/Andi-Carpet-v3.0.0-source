# Rutare 05 – poziționare GPS pe hartă

- Verifică validitatea coordonatelor înainte de alegerea sau salvarea markerului (inclusiv punctul 0,0).
- Restricționează salvarea markerelor la Admin și blochează operațiile concurente în interfață.
- La mutarea unui marker existent arată atât coordonatele vechi, cât și pe cele noi.
- Salvează în Firestore prin funcția existentă `saveLocation`, fără schimbarea altor câmpuri.
- Nu adaugă coordonate ghicite sau modifică datele live.

Testare necesară: flutter analyze/test, verificare interactivă hartă și reguli Firestore.
