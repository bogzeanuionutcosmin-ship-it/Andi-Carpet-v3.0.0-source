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

Clasa a devenit bibliotecă SDK independentă, re-exportată de main. Body equivalence verificată după `_functionFrom` → `functionFrom`; în directory sync se schimbă numai numele apelului. Nu se transformă datele aprobate în altă schemă și nu se schimbă drepturile. Teste directe cu User/DocumentSnapshot fake, fără app Firebase ori date live. Local 155 Python + 3 Node PASS, syntax/diff/inventar PASS. CI de identitate: d4d90a7796bb6899f8d9fac36e44db480d2ba82c / run 38482963824, **5/5 SUCCESS**.

Inventar: 161 Dart, 62 parts, 99 biblioteci. Acesta este inventar lexical; nu dovedește cod mort și nu înlocuiește teste de dispozitiv.

## Lot 2 — QuickAccountStore

Algoritmii și modelul devin Dart pur, cu I/O injectat prin trei callbackuri. Main păstrează pluginul, cheia/opțiunile și wrapper-ele existente; Settings califică numai tipul. Deduplicarea, limita la save, absența limitei la load, JSON/erori și apelul forget sunt păstrate. Teste în memorie cu date sintetice, fără stocare reală. Local 155 Python + 3 Node, syntax/equivalence/inventory/diff PASS. CI QuickAccounts: 0be4bce7d5054dc641b92f48dc7e6c94247438ac / run 38483520307, **5/5 SUCCESS**. Inventar 162/61/101.

## Lot 3 — politica de inițializare Firebase

Helper Dart pur pentru selectarea/acțiunile de inițializare; main furnizează predicate/acțiuni SDK lazy. VAPID și handlerul FCM cu pragma/gating rămân text-identice în biblioteca main. Configurația și ordinea main sunt păstrate. Teste pentru selecție, laziness, await și excepții fără retry/fallback. Local 155 Python + 3 Node, syntax/equivalence/inventory/diff PASS. CI bootstrap: 75279637b52cf588a26a6ec2d0a6d1a0b044e898 / run 38484010280, **5/5 SUCCESS**. Inventar 163/60/103.

## Resurse Vision existente — numai audit read-only

PR #19 la d4da2872a566eba258e82b8597c023e03ceb9b56 și #21 la d18b2523a31ead7eb65a04fe92a21276a4155c97 au deja Error Log, telemetry, Diagnostics și teste. #21 mai conține integrarea documentelor/offline smoke. Nu le duplicăm ori importăm în #28; după modularizare audităm implementarea și contractele pe acele ramuri înaintea extinderii. Acest inventar nu reprezintă acceptare pe dispozitiv/în producție.

## Lot 4 — AuthGateSources

Port callback read-only independent de biblioteca main, cu tipuri SDK explicite. Adapter default lazy în main, query-uri originale și metadata păstrate. Constructorul AuthGate permite surse opționale; state-ul fixează furnizorul la initState. Întregul body al state machine/lifecycle rămâne text-identic după înlocuirea expresiilor sursă. Nu este un bus Vision și nu adaugă observabilitate funcțională.

Teste widget de reconectare/pending/absent, UID switching/cancel, UI settings/duplicat/dispose și recuperare după eroare, folosind streamuri locale. Nu exercită încă HomePage activ, login/logout SDK sau autorizarea server-side. Local 155 Python + 3 Node, syntax/equivalence/diff/inventory PASS. CI urmează. Inventar 165/60/105.

## Pași următori după validare

1. Auditarea surselor de login și abonărilor Home după grupurile existente, înainte de mutarea stării. Fixture-uri pentru ordinea evenimentelor, UID și cancel; numărul de citiri/scrieri nu crește.
2. Nu se repară implicit token ownership, START concurent, badge_v2 sau restore non-atomic: sunt schimbări funcționale/securitate documentate separat.
3. Auditul diferențial final va marca aprobat+implementat / aprobat+neimplementat / parțial / clarificare tehnică / decizie nouă. Referințe: registrul existent și Issue #30; nu se reiau aprobările.
4. Vision Error Log/telemetry/Diagnostics din #19/#21 se inspectează și reutilizează în etapa dedicată; în #28 nu apar module Vision noi.
