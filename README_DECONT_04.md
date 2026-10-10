# Decont 04 — Calcule generale / sume primite

- Anii disponibili pentru diurne se bazează pe data confirmării, atunci când există.
- Tranșele cu același ID sunt contorizate o singură dată între deconturile de deplasare și finanțele echipei.
- Datele legacy fără dată continuă să fie incluse doar în totalul general.

**Limitare cunoscută:** agregatele legacy fără ID-uri nu pot fi deduplicate în siguranță fără o migrare/reconciliere cu datele reale. Nu s-au modificat date Firebase.

**Verificare:** verificare statică a modificărilor și integritate ZIP; Flutter SDK nu este instalat aici, deci compilarea nu a fost efectuată.
