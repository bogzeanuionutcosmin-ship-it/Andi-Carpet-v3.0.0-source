# Firestore rules integration review — actual PR patch comparison

Reviewed on 18 October 2026: GitHub file patches for Draft PRs #99, #100, #101, specifically `firestore.rules` and `.github/workflows/validate.yml`. This is source review, **not emulator execution**.

## Findings

**#99 and #100 — same schedule rule change.** Both add `resource.data.closed != true` to the non-admin `program` update condition. This is an identical hunk, not a competing change. It appears intended to prevent non-admin edits of closed records. The adjacent delete condition remains separate and is not changed by this hunk; confirm whether closed records may still be deleted by permitted team members.

**#101 — different finance rule change.** #101 replaces combined create/update rules in the financial team document block with separate conditions. Non-admin create must not populate `managerId`; non-admin update must preserve both `teamId` and `managerId`. This is a distinct hunk from #99/#100, so these particular hunks can conceptually coexist. That does **not** establish that the whole candidate ruleset is safe.

**CI workflow conflict.** #99/#100 add the schedule and centralizer Firestore tests; #101 adds finance identity tests to the same `npx firebase emulators:exec` command. A naive choice of either PR's workflow would omit tests from the other. The integrated candidate should run **all four** suites:
```sh
npx firebase emulators:exec --only firestore --project demo-andi-carpet --config firebase.rules-test.json 'node --test --test-concurrency=1 tests/firestore/diurna.test.cjs tests/firestore/program_schedule.test.cjs tests/firestore/centralizer_correction.test.cjs tests/firestore/finance_identity.test.cjs'
```
Only run in an isolated emulator context after confirming the fixture configuration and project identity.

## Required security test additions
1. Non-admin attempts to update a closed program record, and attempts to delete it.
2. Authorized team member updates an open program record; cross-team update denied.
3. Finance create with arbitrary `managerId` denied; blank/absent manager ID behavior verified.
4. Finance update preserving identity allowed only under approved role policy; manager/team reassignment denied.
5. Admin exception exercised explicitly.
6. Every suite run against the **combined** candidate rules, not separately against individual PR heads.

## Review outcome
No production changes. These are actionable integration instructions; code merge, security policy approval, and emulator evidence remain pending.
