# Audit compatibilitate PR #50 / PR #51 — fără integrare

Referință comună #46: `736ef9ea66bec5ff0c431d05808e43423c1f3ba9`.
Privacy #51: `926ed1e7474e22a73257291a0089b5efbd5fe925`.
Finanțe #50: HEAD-ul acestui checkpoint, verificat în descrierea PR după CI.
Nu s-au executat merge, cherry-pick, rebase, checkout pe #51 sau modificări ale lui.

## Rezultatul auditului read-only

Intersecția listelor de fișiere schimbate față de baza comună este exact:
`ChatGpt` și `test/vision_hardening_freeze_test.py`. Sursele runtime sunt disjuncte.

Auditorul `scripts/audit_finance_privacy_compatibility.py` citește numai obiecte
Git cu show/diff/rev-parse; nu creează un tree integrat și nu scrie cod de integrare.
El validează cele21 pinuri pe fiecare branch, cere aceeași mulțime de chei,
exact2 modificări financiare și exact3 privacy, verifică hashul real al fiecărei
surse și refuză o suprapunere a pinurilor. Confirmă că ambele note ChatGpt sunt
extensii ale istoricului comun. Patru teste Python verifică reuniunea pozitivă,
guard lipsă, guard nou care cere review și conflict de sursă.

| Sursă | Pin necesar la integrarea viitoare | Proveniență |
|---|---|---|
| lib/expenses/expense_page.dart | f6a3976dbe52fa81c1599d78207803c35362c2cba5ece9c68182cb68a8af511d | #50 |
| lib/expenses/expense_settlement_actions.dart | 0348242c2def81ac693ded3e3a64c96b9df701fff2b0895f4e6e2b1b09bc92b8 | #50, inclusiv guardul stale-close nou |
| lib/home/home_page.dart | 6188a3b7ef72e4ca3cf9d903d9a33173fd2d0f37b33c7e28abae3ff6eaea00a6 | #51 |
| lib/home/home_live_location.dart | 5c19d853c71cf6eb07c2d3e02e279faa631d728c0a8fcc9ae7e983fc6a9c9695 | #51 |
| lib/home/home_push_notifications.dart | 1b76637e9e11110eaeb1f5b7d64dc8bec53fa0799c4d1bc3db08d08586d91566 | #51 |

Nu copiați integral dicționarul FROZEN dintr-o singură ramură: astfel s-ar pierde
pinurile celeilalte. Păstrați celelalte16 intrări, toate metodele/assertions ale
freeze-ului, cele116 hashuri protejate și testele privacy de regresie. Actualul
#50 nu primește anticipat cele3 hashuri Home: sursele redacted nu sunt aici.

## ChatGpt și workflowuri

Păstrați o singură copie a prefixului istoric comun, apoi integral ambele
appendixuri/checkpointuri (privacy și financiar), cu HEAD/CI/proveniență distincte.
Nu eliminați un checkpoint pe motiv că este mai vechi: are domeniu diferit.
Auditorul verifică păstrarea prefixului, fără a fabrica documentul integrat.

Workflowul Android istoric este modificat numai în #51 față de baza comună;
workflowurile dedicate Mission VII sunt noi în #50. Nu există conflict textual
pe aceste căi, dar condițiile head_ref nu activează automat toate probele pe o
viitoare ramură de integrare. La autorizarea integrării trebuie pregătită o
poartă explicită care rulează finanțe+privacy+AuthGate/Vision și păstrează porțile
istorice. Acest audit nu schimbă condițiile CI sau testele #51.

## Limite și reluare

Compatibilitate de surse/pinuri/documente verificată local, NU build integrat.
CI verde pe fiecare PR separat nu certifică un rezultat combinat. Nu importăm
privacy source pentru a pretinde că #50 are logurile Home deja reparate.

Reluare audit (după fetch read-only al obiectelor exacte, fără merge):
`python3 scripts/audit_finance_privacy_compatibility.py --finance-ref HEAD --privacy-ref 926ed1e7474e22a73257291a0089b5efbd5fe925`

Dacă #51 avansează, comparați diferențele și actualizați auditul înainte de orice
integrare autorizată. Firebase live, native SDK logs/hardware și Learning după
write rămân limite independente; niciun pin nu oferă certificat ACL server.
