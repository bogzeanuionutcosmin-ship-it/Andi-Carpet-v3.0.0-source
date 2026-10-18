# Release blocker triage and evidence escalation

Status: HOLD. This is a documentation-only coordination protocol.

## Classification
- P0: any path that could unintentionally deploy or mutate production, unauthorized finance access, untrusted release signing, or personal data leakage.
- P1: failed staging integration, broken migration convergence, missing upgrade/rollback path, inconsistent PDF or schedule totals.
- P2: documentation drift, non-blocking UI defects or missing optional evidence.

## Issue record
Record exact candidate tree SHA, reproducible steps, expected/actual, affected data boundary, redacted evidence, owner, workaround, and retest criteria. Do not include Firebase service-account keys, personal profiles or signing secrets.

## Resolution policy
A blocker is not closed by an explanatory document. It needs an implemented fix in the owning branch, independent review and retest against the updated combined tree. If any input SHA changes, invalidate stale evidence.

## Escalation
Production-trigger hazards require environment-level approval before any merge. Security/privacy uncertainties require explicit owner decisions. Neither independent documentation nor passing synthetic tests can approve deployment.
