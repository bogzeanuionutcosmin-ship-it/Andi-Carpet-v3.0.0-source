# Member directory: privacy and migration review (2026-10-18)

Independent source review of main; not a production audit or claim of exploitation.

## Verified data path
- `functions/member_directory_projection.js` exports `projectMember`. It excludes hidden profiles (`hiddenFromMembers === true`) and `role === 'admin'`, and copies these fields when present: `name`, `nickname`, `useNickname`, `function`, `functionIds`, `teamId`, `active`, `role`, `photoBase64`, `phone`, `city`, `county`, `contractFunction`. It forces `active` boolean and `role: 'member'`.
- `functions/index.js` uses `onDocumentWritten('users/{userId}')` and reads the current private user document inside a transaction before writing/deleting `memberDirectory/{userId}`, reducing out-of-order event republishing risk.
- `firestore.rules` allows `get, list` of `memberDirectory/{userId}` to `isActive()` and denies client writes.
- `functions/backfill_member_directory.js` reads the entire users collection, projects each record and runs one transaction per user. The script initializes Firebase Admin with the **production project ID** `andicarpet-e777e`.

## Release decisions still needed
1. **Privacy policy:** Is exposing `phone`, `photoBase64`, `city`, `county` and `contractFunction` to every active account intended? The source proves read access and field projection, not that this violates a requirement. Product owner must explicitly approve the exposure.
2. **Backfill dry-run:** No dry-run or project ID argument is present. A production-credential execution writes/deletes real directory records. Require isolated staging project, a reviewed sample diff and explicit approval before any production execution.
3. **Accounting accuracy:** `written++` and `deleted++` occur *inside* Firestore transaction callbacks. A transaction retried after contention can increment these counters more than once even if only one transaction commits. The counts are therefore attempt counters, not guaranteed committed-document counts. Move increments outside the successful `await db.runTransaction(...)` in a future code change owned by the appropriate implementation lane; do not alter Luna's files here.
4. **Projection versioning:** `tx.set(ref, projected)` overwrites directory documents. Verify old clients tolerate missing/removed fields and test hidden/deleted users with out-of-order events.
5. **Migration resilience:** An error exits the process after potentially committing a prefix of users. No checkpoint/resume summary or all-or-nothing guarantee exists; establish idempotent retry and reconciliation acceptance criteria.

## Minimum safe acceptance
- Dry-run against synthetic staging users including admin, hidden, inactive, deleted, and legacy missing fields.
- Reconciliation report: source eligible users vs directory IDs, extra entries and changed field hashes; avoid exposing private profile contents in logs.
- Concurrent source profile changes while backfill runs, with current-state convergence checked.
- Confirm read access matrix for anonymous, inactive, active member, admin and hidden users.
- Ensure production credentials cannot be used by default in test scripts.

## Source identity
Read-only inspection of `main` on 2026-10-18: `functions/member_directory_projection.js` blob `3204b3958a2c3b5f7efcaf33e3a217c77f511628`; `functions/backfill_member_directory.js` blob `488d745f3b05b573d6bf246eae778391bdc5ab8b`; `firestore.rules` blob `77a7eded67b5c62838e66e3b3cdc4512f63d46f0`.

No source code, Firestore data, production workflows or Luna PRs changed.
