# Staging, privacy and migration acceptance — independent track

Review date: 2026-10-18. Documentation only; no Firestore, Firebase Auth, Cloud Functions, migration or production action executed.

## Verified main source facts
- `functions/member_directory_projection.js` publishes selected profile fields including `phone`, `photoBase64`, `city`, `county`, `contractFunction` for eligible non-admin, non-hidden users.
- `firestore.rules` grants active users `get, list` on `memberDirectory/{userId}` and denies client writes. This is an exposure requiring explicit privacy approval, not proof of a privacy violation.
- `functions/index.js` uses current private profile reads inside a transaction in `syncMemberDirectory`, reducing out-of-order event republishing risk.
- `functions/backfill_member_directory.js` hardcodes `andicarpet-e777e`, iterates users and writes/deletes projected directory documents. It increments `written`/`deleted` within transaction callbacks, which may retry; those counters are not guaranteed committed counts.
- `main:.github/workflows/restore-member-directory.yml` automatically triggers on relevant pushes to main, authenticates to production and runs deploy/backfill. #101 proposes a manual gate but remains Draft.

## Staging acceptance criteria
1. Use a separate Firebase project, Auth identities, Firestore, Functions, service account and app configuration. Fail closed on any script pointing to production project ID.
2. Synthetic profiles cover active, inactive, hidden, admin, deleted, legacy and concurrent-update cases.
3. Compare private eligible user IDs to public directory IDs, field-by-field allowlist and unexpected stale entries. Redact personal data in logs.
4. Test interrupted backfill, repeated backfill, delayed triggers and concurrent source profile edits; verify eventual convergence and safe rerun.
5. Obtain explicit product/privacy decision on publishing phone and photo data to all active accounts.
6. Verify role-based access for anonymous, inactive, active and admin identities using staging SDK tests.

## Deployment transition hazard
The old workflow also listens for changes to its own YAML file. Do not assume that merging a new manual trigger necessarily prevents an old-definition push run during transition. Require verified environment-level hold/approval or approved disablement before any merge touching this workflow or `firestore.rules`.

## Evidence record
For each test: exact tree SHA, staging project ID, command, fixture hash, timestamp, expected/actual, redacted logs and reviewer. UNKNOWN is not PASS.

## Non-overlap
This PR does not touch Luna's implementation, rules, workflows, tests or #101.
