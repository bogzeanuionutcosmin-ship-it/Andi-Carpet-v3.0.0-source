# Three-lane documentation review checklist

## Scope
- #103: static release guard, evidence register and production workflow risks.
- #104: Android signing, APK provenance, device upgrade acceptance.
- #105: isolated Firebase staging, privacy and backfill reconciliation.

## Before marking any lane review-ready
- [ ] Refresh main and all candidate PR head SHAs.
- [ ] Confirm no overlapping edits with Luna's feature PRs or with another independent lane.
- [ ] Verify source claims against current file blobs.
- [ ] Distinguish observed evidence from proposed tests.
- [ ] Link actual run logs for every PASS claim.
- [ ] Record unknown environment protection and signing custody as UNKNOWN, not PASS.
- [ ] Keep production deployment, backfill and release distribution disabled.
- [ ] Obtain explicit owner review before any merge.

## Cross-lane dependencies
Android release is blocked by debug signing and missing trusted APK provenance. Staging privacy acceptance is blocked by absent observed tests and unresolved policy decisions. Production rollout is blocked by current main auto-deploy hazard and unknown environment-level protections.

## Existing source check
`main:.github/workflows/restore-member-directory.yml` runs on relevant pushes to main and includes `firebase deploy` and `node functions/backfill_member_directory.js`. Its production credentials and target must never be used for exploratory tests.

This checklist is documentation only and does not alter Luna's source, workflows or Firestore.
