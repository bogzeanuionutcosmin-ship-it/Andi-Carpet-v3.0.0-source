# Decont 05–08 — revizie cumulativă

Bază: arhiva cumulativă Decont 04.

## 05 — PDF
- Deduplicare pe ID pentru documente, diurne confirmate și tranșe de bani primiți.
- Totalurile de bani primiți din PDF sunt calculate din aceleași tranșe unice afișate în desfășurător; pentru datele vechi fără tranșe se păstrează totalurile istorice.
- Sunt excluse din calcul înregistrările cu valori negative sau nefinite.
- Ordinea PDF: combustibil, facturi, diurne, alte cheltuieli, rezumat, desfășurător.

## 06 — Reconciliere
- Numai încasările de diurnă confirmate, cu sumă efectiv primită validă, intră în totalurile decontului.
- Intrările duplicate din aceeași colecție sunt numărate o singură dată după ID.
- Soldurile între distribuitori și compensările automate sunt funcții separate; acest patch nu certifică tranzacțiile financiare Firestore în producție.

## 07 — Calcule generale
- Deduplicare pe ID în calculele anuale și generale pentru documente și plăți de diurnă.
- Sunt filtrate valorile invalide.
- Se păstrează regula: sumele istorice agregate fără dată intră doar în totalul general.
- Atenție: înregistrările istorice agregate pot suprapune transferuri individuale dacă au fost migrate fără ID-uri. Necesită reconciliere pe date reale.

## 08 — Verificări
- Control static al prezenței modificărilor și verificare ZIP.
- NU au fost executate Flutter test, Flutter analyze sau teste Firebase Emulator (toolchain absent în mediu).
- Înainte de publicare: rulare `flutter analyze`, `flutter test`, teste Firebase Emulator cu roluri și date istorice, comparație manuală a PDF-urilor și a totalurilor.

Nu publicați acest pachet drept versiune validată de producție până la testele menționate.
