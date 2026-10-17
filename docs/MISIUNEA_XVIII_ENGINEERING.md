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

## Executed RED → remediation cycles

- First SHA 42cfbe2 / Validate run 39072529665: 55 Flutter tests passed, one failed. Actual widget layout reproduced filter dropdown overflows (34/50px). Added expanded dropdown layouts; the next run confirms the widget test passes.
- First real PDFs were generated and downloaded from artifact 12115667914. Poppler validation failed because a missing location registry entry caused raw room IDs rather than saved snapshot labels. Snapshot name/address fallback fixed.
- Second SHA 456d950 / Validate run 39072694666: long-history generator test reproduced PdfTooBigPageException with 80 interventions for one location. The nested table could not split one location block. Replaced it with flat spanning rows and a repeated page header; verification pending on next SHA.
- Added a separately packaged, no-INTERNET Android synthetic UI harness. It does not test authentication, real synchronization or production configuration.

## Independent recovery/finance evidence

- Simulated main + new candidate + #95: merges clean; 120 Python tests and 3 Node tests pass. Nothing merged into main.
- #88 exact source 73f7075: Python 199/199. Standalone Dart AOT probe compiled and 28 real OS/SQLite adversarial tests passed (locks/crash/rollback/session revocation/capacity/corruption).
- #88 synthetic session Firestore suite: 18 passed, 1 explicitly skipped, 0 failed; signed claims and authority fixtures are test-only, not proof of trusted production issuance or hardware anti-rollback.
- #15 exact source 876f72d: 19/19 per-diem authorization emulator cases pass. merge-tree confirms conflicts with current main in workflow/main/payment-plan areas; do not merge the old branch or replace newer finance code indiscriminately.
- #91/#93 conflicts and #94 legacy correction are already addressed by #99 ancestry; no duplicate PR is opened for those fixes.

## Further validation

- Third SHA dc886000 / Validate 39072875409: Flutter tests and real-PDF Poppler checks passed before web compilation. Downloaded artifact 12116101317 confirms the 80-row history is six pages with 80 START and 80 FINAL times; first page rendered and visually inspected without clipping.
- The full native+Firestore session test was rerun with XIII_NATIVE_PROBE: 19/19, no skipped cases. Local Chromium journal test is unavailable because the Playwright browser archive download is invalid/truncated; not counted as a pass.
- Android SDK platform 36, build tools 36.0.0, platform-tools, emulator 37.2.12 and API36 x86_64 system image are installed in /tmp. KVM is unavailable; software-emulation boot is attempted separately. No physical Android validation.
- Further fixes: use exclusive next-day upper bounds so 23:59:59.999999 remains in the selected date; retain display-only execution snapshots when a registry location is deleted. Added projection and widget regressions.
