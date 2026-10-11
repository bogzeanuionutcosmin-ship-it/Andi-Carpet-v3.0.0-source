# AndiCarpet OCR Learning – bonuri sintetice

Aceste exemple sunt **fictive**, construite exclusiv pentru teste automate.
Nu sunt fotografii de bonuri reale și nu demonstrează formatul fiscal al vreunei rețele.
Nu se folosesc pentru contabilitate și nu se importă drept cheltuieli reale.

## Contractul datelor

- `bf`: identificatorul bonului fiscal (șir, păstrează zerourile inițiale)
- `date`: data calendaristică YYYY-MM-DD
- `fuelAmountBani`: **numai suma combustibilului**, în bani (integer)
- `containsFuel`: boolean
- `needsReview`: adevărat când OCR nu poate determina sigur suma
- `source`: `synthetic`, obligatoriu pentru exemplele de mai jos

## Reguli

1. Pentru bon exclusiv de combustibil, valoarea combustibilului poate coincide cu totalul.
2. Pentru bon mixt, nu includem produsele non-combustibil.
3. Pentru combustibil cu sumă ilizibilă, valoarea este `null` și se cere verificare.
4. Pentru bon fără combustibil, suma combustibilului este 0.
5. Nu presupunem că un bon este combustibil doar pentru că furnizorul este o benzinărie.
6. Nu inferăm BF sau data dacă OCR nu le poate identifica.

Exemplele sunt în `test/fixtures/fuel_receipts_synthetic.json`.
