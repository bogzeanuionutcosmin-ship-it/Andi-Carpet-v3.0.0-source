# Misiunea XVIII — active engineering (Draft, no merge/deploy)

Base: PR #99 f5e3ebd078e02e14ee1e13114660f65a4cf10cd1; source branches untouched.

## Changes under validation

- Persisted schedule provenance is decoded from Firestore and copied by both editors. A deleted legacy day with missing updatedAt/writeToken can no longer be treated as a new schedule; a new ID cannot silently overwrite a legacy document. New SDK emulator regression includes atomic rollback of another day.
- A manual execution dialog is single-flight; cancellation releases the guard. Date picker callback checks dialog mounting.
- Real Centralizator PDF byte builder is shared by download and tests. Added real Craiova and overnight export fixtures, Poppler text/date/count/name validation, rendered PNG artifacts in CI.
- PDF fonts are bundled with their license instead of requiring Google Fonts network access on every export. Covers Romanian text offline.

## Local evidence

- Initial Python 118/118 and Node 3/3 passed.
- Original Firestore emulator suite 18/18 passed on demo-andi-carpet.
- Extended Firestore emulator suite 19/19 passed.
- Java 17 + extracted Java 21 available; Node 24.19, Python 3.12. Flutter tag 3.47.5 downloaded; Dart 3.13.4.
- Local Flutter bootstrap was blocked by automatic review because its Azure bot detector attempted 169.254.169.254/metadata/instance. No metadata access is authorized and no workaround is used. Flutter/build/PDF verification moves to authorized PR CI, where GITHUB_ACTIONS prevents that detection path.
- Android command-line SDK bootstrap initially failed to download the new Android CLI using its own networking. Command line tools v19 are downloaded as an alternative; no physical device or /dev/kvm is available.

No production Firebase access, deployment, merge, APK distribution or destructive data actions.
