# Main versus candidate deploy behavior — 2026-10-18

Read-only comparison of exact GitHub source files. No workflow was triggered and no production action was performed.

| Surface | Main | #101 @ 98c40ae394941ddfc185f028fc04ad6809d6de3b | Operational interpretation |
|---|---|---|---|
| `.github/workflows/restore-member-directory.yml` trigger | `push` to `main`, path filters include `firestore.rules` and the workflow itself | `workflow_dispatch` only | Candidate closes automatic trigger **after it is merged**, but main remains exposed until then |
| Job gate | No explicit `if` confirmation in job | Requires `main`, exact approved SHA and `DEPLOY_MEMBER_DIRECTORY` | Candidate reduces accidental execution |
| Environment | `firebase-production` | `firebase-production` | Actual approval configuration UNKNOWN |
| Production commands | Deploy Firestore rules, deploy `syncMemberDirectory`, run backfill | Same commands retained | Manual approval does not make commands harmless |
| `.github/workflows/validate.yml` | Main has push/PR/dispatch validation | #101 adds candidate tests and integration | Test-only CI cannot certify deployment controls |

## Important workflow migration caveat
Because the old workflow listens for changes to **its own YAML path**, a merge that replaces it can itself be eligible for an old-definition push run. Before any merge, review the GitHub Actions workflow version semantics and use an explicit environment-level hold/approval or temporarily disable the workflow via authorized repository administration. Do not rely on the new YAML alone to prevent a transitional production run.

## Evidence and limitations
Main workflow blob `0d8db4bf5c1e2c4e4fb3374b1aaf6312082dc404`, #101 workflow blob `611ea46031152734a32543c050ca1d0be92c017f`. `main:.github/workflows/validate.yml` blob `e9dd58e1f4e5aaf33026fe64b9fa9f1e2c77eec6`. All read 2026-10-18. Additional workflows may exist; this is not an exhaustive repository-wide inventory.

## Required next independent checks
- Confirm GitHub environment protection rules and authorized deployment approvers via repository administration.
- Review GitHub Actions history for any production restore job launched by a rules-only merge.
- Audit all production-capable workflows and manual deployment entry points before merge approval.
- Verify staging Firebase project isolation from production IDs and credentials.

**No release approval is granted by this document.**
