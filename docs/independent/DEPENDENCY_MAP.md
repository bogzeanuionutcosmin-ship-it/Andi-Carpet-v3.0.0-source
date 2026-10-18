# Cross-PR dependency and collision map

Snapshot from GitHub on 2026-10-18; PR heads may move. Recheck before integration.

| PR | Focus | Shared areas requiring coordinated integration |
|---|---|---|
| #95 | Android APK download link validation | lib/ui/install_app_buttons.dart; overlaps historical application delivery |
| #99 | Grafic/Centralizator baseline integration | firestore.rules, schedule UI, CI workflows |
| #100 | Legacy schedule deletion guard, PDF regression, correction guard | firestore.rules, schedule UI, validate.yml, build-test-apk.yml |
| #101 | Narrow finance manager/team identity protection, manual deployment gate | firestore.rules, validate.yml; separate main-derived base |

## Safe integration order
1. Freeze exact SHA of each candidate in an isolated temporary checkout; never alter source branches.
2. Resolve overlaps using explicit semantic review, especially firestore.rules and validate.yml. Green tests on each PR alone do not establish combined correctness.
3. Re-run Firestore emulator tests for schedule + finance and all PDF projections on the *combined* tree.
4. Validate trusted signing/distribution independently, without replacing debug keys on Luna's branches.
5. Staging real-application E2E and device testing; only then consider release approval.

## Duplication guard
Existing finance tests in older PR #83 include finance_viii_acl.red.cjs and finance_ix_compatibility.test.cjs. #101 adds finance_identity.test.cjs. #100 includes program_schedule.test.cjs and centralizer_correction.test.cjs. Check these before authoring more tests. Prior independent characterization probes are not evidence of execution until emulator logs exist.

## Known static blockers, not new implementation tasks
- Release signing uses debug signing config in android/app/build.gradle.kts on #100 and #101.
- #95 URL validation is not equivalent to verified publisher certificate or artifact hash.
- #101 documents that amount-update policy is intentionally preserved; do not mislabel its narrow identity fix as comprehensive financial authorization.
