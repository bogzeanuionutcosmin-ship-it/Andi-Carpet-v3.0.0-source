# Evidence register — 2026-10-18

This is a point-in-time independent documentary review, not a live release certification. Source observations are pinned to exact SHAs. GitHub Actions outcomes from prior reports are not revalidated here.

| ID | Exact source | Observation | Evidence level | Consequence |
|---|---|---|---|---|
| E01 | #100 cfb00b9fea24e7e026019d81bac6ecfe3a294dd2; docs/MISIUNEA_XVIII_ENGINEERING.md | Schedule provenance, single-flight correction, offline font bundling and real PDF verification documented | Documented test evidence, not physical E2E | Do not duplicate Luna's fixes |
| E02 | #101 98c40ae394941ddfc185f028fc04ad6809d6de3b; docs/MISIUNEA_XVIII_FINANCE_IDENTITY.md | Manager/team identity protection explicitly narrow; amount-update policy retained | Documented emulator evidence | Separate monetary authorization acceptance gate |
| E03 | #101 same SHA; .github/workflows/xviii-integration.yml | Combines pinned #100 cfb00b9 and #95 3c372cc in temporary runner, with a specific validate.yml conflict resolution | Source inspection | Passing run does not automatically validate newer candidate SHAs |
| E04 | #101 same SHA; .github/workflows/xviii-android-runtime.yml | Android UI test downloads pinned synthetic offline APK from run 39073106128 | Source inspection | Not real authenticated app on device |
| E05 | #101 same SHA; .github/workflows/restore-member-directory.yml | workflow_dispatch with confirmation and approved_sha matching github.sha on main; firebase-production environment | Source inspection | Protects this workflow only; not evidence of all deploy paths |
| E06 | #100 cfb00b9; android/app/build.gradle.kts | Release build selects signingConfigs.getByName("debug") | Source inspection | Trusted release signing BLOCKED |
| E07 | #95 3c372cc; lib/ui/install_app_buttons.dart | HTTPS and obvious local host checks; administrator-controlled URL, no pinned signing fingerprint or artifact digest | Source inspection | Distribution provenance BLOCKED |
| E08 | #100 cfb00b9; android/app/src/main/AndroidManifest.xml | INTERNET, coarse/fine/background location, foreground service location, CAMERA, POST_NOTIFICATIONS and SEND_SMS declared | Source inspection | Device permission review and policy rationale required |
| E09 | #100 cfb00b9; .github/workflows/validate.yml | Firestore emulator, Flutter tests, real PDF synthetic fixture validation and web build | Source inspection | Not production Firebase/device acceptance |

## Provenance / freshness rule
Each entry must be refreshed against exact new PR head SHA before it is reused as release evidence. If a source path or SHA changes, mark previous evidence STALE until reevaluated. Do not infer an absence of other workflows from this limited inventory.

## Explicit unknowns
- Physical Android install and upgrade with real authenticated application.
- Production-like staging Firestore -> START/FINAL -> Centralizator -> PDF.
- Release keystore custody, certificate pinning, key rotation and signing lineage.
- Backup/restore rehearsal, deployment rollback and all production trigger paths.
