# Securizare Admin — pachet integrat (NU deployat)

## Modificări implementate
- `users/{uid}`: citire individuală doar pentru proprietar/Admin; enumerare doar Admin.
- `memberDirectory/{uid}`: profil minimal pentru membrii activi, numai citire din client. Conturile Admin și cele ascunse nu sunt proiectate.
- Cloud Function `syncMemberDirectory`: sincronizează directorul la fiecare schimbare de profil; șterge documentul public la ascundere/ștergere.
- Flutter: lista de membri, sincronizarea utilizatorilor, profilul membrilor și chatul deschis din alertă folosesc directorul pentru utilizatorii non-Admin; Admin continuă să folosească profilurile complete.
- Flutter: sincronizare separată a setărilor private din profilul propriu.
- Script de migrare `scripts/backfill_member_directory.js` cu mod implicit dry-run și `--apply` explicit.

## Condiții obligatorii înainte de producție
1. **Nu publica regulile singure**: versiunile vechi ale aplicației citesc `users` și ar pierde accesul. Trebuie actualizat clientul și verificat rollout-ul.
2. Rulează testele Flutter și Firebase Emulator pentru rolurile Admin, membru activ/inactiv, utilizator neautentificat și cont ascuns. Testele Python sunt numai contracte statice.
3. Deploy trigger backend, apoi rulează migrarea într-un mediu cu credentiale Admin, verifică directorul și actualizează clientul. Abia apoi activează regulile restrictive; un rollout cu utilizatori pe versiunea veche necesită o fereastră de mentenanță sau migrare compatibilă.
4. Verifică accesul la chat, profiluri, apel direct, echipe, notificări, setări personale și conturile noi.
5. Directorul include `phone`, `photoBase64`, `profileFields` pentru compatibilitate cu directorul de membri. Revizuiește confidențialitatea acestor câmpuri înainte de deploy dacă unele sunt considerate private. `email`, `effectivePermissions`, setările și tokenurile nu sunt copiate.
6. Nu a fost executată nicio operație asupra Firebase/GitHub și nu a fost generat APK.

## Limitări de testare
`node --check` și testele statice nu demonstrează că Firebase Rules, Dart sau aplicația Android funcționează în producție. Nu este inclusă o migrare executată asupra datelor reale.
