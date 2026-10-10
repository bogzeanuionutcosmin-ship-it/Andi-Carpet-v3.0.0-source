# Diurnă — integrare cumulativă (candidat pentru verificare, NU DEPLOY)

Sursa completă este inclusă. Integrarea pe fluxul existent `perDiems` cuprinde confirmarea beneficiarului, refuzul 0 lei, audit tranzacțional, afișarea soldurilor per pereche, plata suplimentară legată de distribuirea inițială, acceptarea/contestarea diferențelor și rezolvarea contestațiilor de către Admin. Plata suplimentară este marcată cu `supplementaryFor` și NU creează o a doua obligație financiară. Încasările neconfirmate nu intră în sold. Contestația nu modifică suma confirmată.

Securitate: reguli Firestore pentru `perDiemDisputes`, restricții pe plăți suplimentare și pe auditul de confirmare. Registrul experimental `per_diem_settlements_v2` rămâne închis la scriere pentru a nu crea două surse de adevăr.

## Blocaje de lansare
- `flutter analyze`, `flutter test`, compilarea Android și testele Firebase Emulator NU au fost executate: Flutter/Firebase CLI nu sunt instalate în acest mediu.
- Reguli Firestore noi NU au fost validate în emulator; nu publicați în producție înainte de validare.
- UI-ul plăților suplimentare și al contestațiilor necesită testare cu două conturi reale și Admin, inclusiv concurență și deconturi închise.
- Niciun deploy GitHub/Firebase și niciun APK nou nu au fost făcute.

Acesta este un pachet de integrare reală, nu o versiune validată pentru producție.
