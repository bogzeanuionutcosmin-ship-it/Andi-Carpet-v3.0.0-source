# Six-module integration: CI and cross-PR collision gate

Recorded 2026-10-18. This is evidence and a review gate, **not** a merge or deployment authorization.

## Verified integration candidate

- Draft [PR #115](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/pull/115)
- Exact head SHA: `c0591bd68cdb720f9a3f5d6aa50c7cd727750cb0`
- Base main SHA reported by PR: `8452159475ff187867002425fa9c3b8c7e8006aa`
- [Actions run 39086442314](https://github.com/bogzeanuionutcosmin-ship-it/Andi-Carpet-v3.0.0-source/actions/runs/39086442314): **success**, all five jobs:
  - Node projection tests
  - Flutter web build
  - Python source and security contracts
  - Firebase Functions syntax and dependencies
  - Firestore emulator authorization tests

This candidate combines independent extractions from #106, #107, #108, #110, #112 and #114. Each extraction also had a successful CI run on its own head before integration.

## Exact changed-path collisions (latest inspected heads)

| Other PR | Head SHA inspected | Shared paths with #115 |
|---|---|---|
| #95 | `3c372cc839614125b9f375e5ff20b818aa1e18ed` | `test/repository_hygiene_test.py` |
| #99 | `f5e3ebd078e02e14ee1e13114660f65a4cf10cd1` | `lib/main.dart`, `test/repository_hygiene_test.py` |
| #100 | `cfb00b9fea24e7e026019d81bac6ecfe3a294dd2` | `lib/main.dart`, `lib/reports/pdf_format_helpers.dart`, `test/repository_hygiene_test.py` |
| #101 | `98c40ae394941ddfc185f028fc04ad6809d6de3b` | none |

These are *path intersections*, not proof of a textual Git conflict. Conversely, no shared path is not proof of runtime compatibility. #99/#100 include security rules, scheduling, centralizer and PDF changes; #101 includes Firestore/security and workflow changes. Do not transplant or silently merge those changes into this candidate.

## Release gate

1. Re-fetch branch heads and changed files immediately before reconciliation. This snapshot becomes stale after any contributor pushes.
2. Review every intersecting file against the owner's PR, including PDF formatting and regression tests; do not overwrite the other contributor's changes.
3. Reconcile into a **new** review candidate, preserving original Draft PRs and explicit source ownership. Do not merge any production-triggering branch.
4. Re-run complete CI on the exact final combined SHA, plus device/runtime, PDF, staging and security acceptance appropriate to the actual changes.
5. Never claim production readiness from CI alone; no deploy, release signing or merge without explicit approval.
