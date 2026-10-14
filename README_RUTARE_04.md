# Rutare 04 – Optimizarea ordinii cu Learning

- Optimizare locală 2-opt peste ordinea propusă de istoricul echipei; punctul final intră în funcția de cost.
- Bonus limitat pentru tranzițiile învățate, pentru a evita trasee foarte lungi.
- Nu reordonează intervenții începute/finalizate și nu propune ordine sub 3 execuții per locație.
- Lipsa GPS oprește optimizarea; nu sunt inventate coordonate.
- Distanțele folosite în acest pas sunt geometrice, NU kilometri rutieri; rezultatul trebuie testat în Flutter/Firebase.
- GitHub/APK nemodificate.
