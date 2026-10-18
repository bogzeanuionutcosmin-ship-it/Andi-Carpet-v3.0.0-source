# Production deployment hazard — verified 2026-10-18

**BLOCKER on main**: The current main branch's `.github/workflows/restore-member-directory.yml` contains a `push` trigger on `main` for modifications to `firestore.rules`, `functions/index.js`, member-directory scripts and the workflow itself. The job authenticates as the production deploy service account, deploys Firestore rules, deploys `syncMemberDirectory`, then runs a member backfill.

This means **merging a candidate that changes `firestore.rules` can trigger a production deployment/backfill on main**, subject to the environment's actual protections. We did not inspect environment approval settings, so they are UNKNOWN. This is not merely a theoretical future risk; it is the exact workflow configuration in main at review time.

#101 SHA `98c40ae394941ddfc185f028fc04ad6809d6de3b` replaces the automatic push trigger with manual `workflow_dispatch`, checks the exact approved SHA, confirmation text, and main ref. This change is still in an open Draft PR and **not present in main** as of this review.

## Non-destructive safe sequencing

1. Do **not** merge or deploy any candidate containing `firestore.rules` while the automatic production workflow remains on main, unless production deployment is explicitly approved and independently controlled.
2. First review and integrate a minimal workflow-only protection change (or #101's equivalent), verifying it is the sole relevant file in that release operation. **Caution:** the workflow itself is among the main push path filters, so even changing it can trigger the *old* workflow definition on that push; confirm environment-level approval/disablement before any merge. Do not assume a same-commit trigger change prevents a run.
3. Inspect all other production-capable workflows and repository/environment protections before changing main. This document does not certify the entire workflow inventory.
4. Require a separate production approval, backup, recovery plan and staging rehearsal for any Firestore rules or function deployment.
5. Verify that production workflow run history and deployed rules/function versions match the approved release SHA.

## Source anchors
- `main:.github/workflows/restore-member-directory.yml` retrieved 2026-10-18: `on.push.branches: [main]`; paths include `firestore.rules`; commands include `firebase deploy --only firestore:rules`, `firebase deploy --only functions:syncMemberDirectory`, `node functions/backfill_member_directory.js`.
- `#101@98c40ae394941ddfc185f028fc04ad6809d6de3b:.github/workflows/restore-member-directory.yml`: `workflow_dispatch`, `approved_sha`, `DEPLOY_MEMBER_DIRECTORY`, environment `firebase-production`.

## Independent-lane boundary
No workflow, environment, rule, function, branch owned by Luna, production credential or data has been modified. This is documentary evidence only.
