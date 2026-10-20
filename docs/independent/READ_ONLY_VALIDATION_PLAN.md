# Independent verification plan (no production actions)

## Deterministic inputs
- Pin main and candidate PR head SHAs before each check.
- Compare source file blobs and changed-file lists; skip duplicate checks already covered by Luna's PR tests.
- Verify documentary claims against source, workflow definitions and run logs. Never infer release readiness from a passing unrelated job.

## Track A: release workflow
1. Enumerate all GitHub Actions workflows and detect any production-capable `firebase deploy`, `gcloud`, `backfill`, or service-account authentication.
2. Compare main and #101 workflow triggers; distinguish current hazard from proposed mitigation.
3. Review environment protection and approval requirements through authorized GitHub configuration before merging. No workflow dispatch or deployment.
4. Confirm rollback and restore procedure with immutable backup evidence.

## Track B: privacy and migration
1. Review projection allowlist against expected privacy policy, especially `phone`, `photoBase64`, `city`, `county`, `contractFunction`.
2. Use synthetic staging data to check hidden/admin/inactive/deleted profiles.
3. Reconcile directory IDs after interrupted and repeated backfill; verify counters count committed operations, not transaction attempts.
4. Do not execute `functions/backfill_member_directory.js` without explicit isolated project protection; the current script hardcodes the production project.

## Track C: Android
1. Validate release signing config and certificate identity; reject debug signing for distribution.
2. Verify immutable APK SHA-256, versionCode and signing lineage.
3. Confirm approved HTTPS host and redirect chain; do not equate URL validation with artifact integrity.
4. Run physical-device upgrade and permission scenarios only with a staging build.

## Track D: E2E evidence
1. Validate combined tree in isolated checkout and pin its SHA.
2. Run real Flutter app with staging Auth/Firestore through START/FINAL, Centralizator and PDF.
3. Cover offline replay, duplicate prevention, overnight days, long history and multi-user concurrent edits.
4. Record logs/artifacts and explicit limitations. Unknown remains blocked.

## Completion policy
A track can be marked PASS only after source SHA, execution command, environment, actual result and artifact link are recorded. All other outcomes are NOT RUN / PARTIAL / BLOCKED. No merge/deploy authorization implied.
