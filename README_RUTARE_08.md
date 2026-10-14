# Rutare 08/08 — Geofencing

- Filtrare poziții GPS invalide, mai vechi de 2 minute sau cu precizie peste 80 m.
- Nu se propune sosirea în timpul deplasării rapide (>8 m/s).
- Promptul se declanșează numai dacă distanța + eroarea GPS este în interiorul razei de 250 m.
- Confirmarea umană, timpul de așteptare, amânarea și limitele anti-spam existente rămân intacte.
- Limitare: pe web/PWA, detectarea nu funcționează dacă browserul suspendă aplicația.
- Nu a fost executată compilarea Flutter sau testarea pe dispozitiv.
- Nu s-au modificat GitHub sau APK.
