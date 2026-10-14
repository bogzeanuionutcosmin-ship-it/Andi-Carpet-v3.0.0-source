# Admin 02 — Permisiunea de vizualizare Membri

- Butonul Membrii apare numai când utilizatorul are permisiunea `viewMembers` (Admin o are implicit).
- Navigarea către director este verificată și în handler, nu doar prin ascunderea butonului.
- Chatul rămâne separat; nu conferă drept de acces la director.
- Nu modifică schema Firebase sau datele existente.

**Atenție:** acestea sunt verificări în interfață, nu înlocuiesc autorizarea pe server. Regula Firestore actuală permite utilizatorilor activi să citească documentele altor utilizatori, inclusiv conturi marcate ascunse. Pentru confidențialitate reală este necesară reproiectarea interogărilor și a regulilor Firestore.

Nu s-au executat `flutter analyze`, teste Flutter sau emulator Firebase.
