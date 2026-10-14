# Decont 03 — documente scanate, validare și PDF

- Sumele documentelor sunt validate ca bani întregi (maximum două zecimale, fără notație exponențială).
- Nu se acceptă documente cu dată viitoare.
- La schimbarea tipului Factură în Bon fiscal se elimină clasificarea implicită „Facturi” dacă era selectată.
- Fotografiile OCR rămân temporare; nu se salvează în Firebase.
- PDF-ul și calculele corectate în pachetul anterior sunt păstrate.

## Verificări
ZIP testat pentru integritate și modificări confirmate static. Flutter/Dart și emulatorul Firebase nu sunt instalate aici; funcționarea pe dispozitiv nu este certificată.
Nu publicați până la compilare și testare.
