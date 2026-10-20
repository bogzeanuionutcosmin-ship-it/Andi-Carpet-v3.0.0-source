# Independent PR coordination (2026-10-18)

| PR | Lane | Allowed paths | Prohibited scope |
|---|---|---|---|
| #103 | Release gates and static guard | `docs/independent/**`, `tools/independent_release/**` | Luna implementation, Firestore rules, CI and production |
| #104 | Android provenance acceptance | `docs/release/ANDROID_*.md` | APK build, signing keys, Android application files |
| #105 | Staging/privacy acceptance | `docs/release/STAGING_*.md`, `docs/release/DIRECTORY_*.md` | Functions, Firestore, migration scripts and data |

## Merge strategy
All remain Draft. They are not release approvals and should not be merged merely because they are documentation-only. Refresh exact PR heads and changed-file lists before integrating; #103 has an independent Python guard whose behavior must be tested in CI or an isolated checkout. Avoid overlapping files with Luna's #95/#99/#100/#101.

## Known guard status
The static checker in #103 returns exit code 2 for a matched blocker and 3 for unmatched-but-uncertified results. This prevents interpreting a clean pattern scan as production approval. Existing four Python test definitions were inspected, but no verified GitHub CI test result is asserted here. Earlier text suggesting they passed locally is not accepted as proof without command output.

## Current production hold
Main's member-directory restore workflow has an automatic push trigger covering `firestore.rules`. #101 proposes manual dispatch but is still Draft. Before any main merge touching that path, verify repository environment controls and transitional workflow trigger behavior.
