# Modularizare identitate și servicii — PR #28 / Issue #30

## Contract de lucru

Continuare din HEAD validat, fără comportament nou. Regulile aprobate sunt registrul de referință, nu o listă de votat din nou. Nu se implementează Vision în acest PR și nu se integrează ramurile #19/#20/#21/#29. După modularizare urmează auditul diferențial cod/reguli, apoi Error Log și observabilitate reutilizând #19/#21.

## Limite inspectate

| Componentă | Dependențe și efecte | Separare sigură / limită |
|---|---|---|
| FirebaseUserProfile | User, DocumentSnapshot, UserFunction; fără I/O | Bibliotecă explicită. Factory și precedențe păstrate; lookup public partajat cu directory adapter. |
| QuickAccounts | SecureStorage const, cheie v1, JSON; parole locale | Următorul lot: storage injectat, format și opțiuni implicite neschimbate. Erorile read din plugin se propagă; JSON invalid revine la listă goală. |
| AuthGate | Auth/user/profile/settings streams, currentUser, lifecycle, UID guard | Adaptere numai după teste pentru ordinea streamurilor, reconectare, profil absent și dispose; nu modifica selecția paginii. |
| Firebase bootstrap | opțiuni platformă, fallback iOS nativ, background FCM entrypoint | Păstrează pragma, top-level handler și inițializarea lazy. Nu schimba config ori platform checks. |

## Lot 1 — FirebaseUserProfile

Clasa a devenit bibliotecă SDK independentă, re-exportată de main. Body equivalence verificată după `_functionFrom` → `functionFrom`; în directory sync se schimbă numai numele apelului. Nu se transformă datele aprobate în altă schemă și nu se schimbă drepturile. Teste directe cu User/DocumentSnapshot fake, fără app Firebase ori date live. Local 155 Python + 3 Node PASS, syntax/diff/inventar PASS. CI de cod urmează după commit.

Inventar: 161 Dart, 62 parts, 99 biblioteci. Acesta este inventar lexical; nu dovedește cod mort și nu înlocuiește teste de dispozitiv.
