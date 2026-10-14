# Andi Carpet v3.0.1 — Grafic, Learning și notificări

Arhivă cumulativă bazată pe Decont 05–08 și Grafic 01.

- Estimări Learning doar din execuții finalizate valide, minimum trei mostre.
- Recalcularea traseului păstrează intervențiile începute/finalizate și folosește GPS și istoricul de tranziții.
- Alertele de plan se pot repeta pentru riscuri persistente, dar cu protecție la notificări duplicate (minimum o oră; patru ore pentru același motiv).
- Recalcularea automată are un interval minim de 30 de minute între aplicări.
- SMS: funcțiile existente trimit în ziua precedentă la ora configurată, anulează mesaje vechi la schimbarea datei, nu retrimit pentru modificări ETA fără schimbarea datei.
- Teste de contract pentru Learning, recalculare, alerte și SMS.

Limitări: Nu a fost executată compilarea Flutter și nici testarea Firebase Emulator sau SMS pe telefon. Testele de contract nu substituie testele de integrare. Nu a fost modificat GitHub sau APK-ul.
