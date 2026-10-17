# Post-XIII — financial rollout decision record

Status: UNAPPROVED PROPOSAL. `production_ready=false`.

The source-of-truth writer inventory is
`docs/MISIUNEA_XIII_MIGRATION_WRITERS_2026-10-17.md`.
Do not duplicate that inventory or silently activate V2.

## Decision gates
- **G0 inventory:** enumerate all active APK/web/desktop versions, Admin SDK
  jobs, backend functions, restore scripts and third-party writers. Repository
  search alone cannot establish what is installed or deployed.
- **G1 exclusivity:** prove server-side denial of every old financial writer
  before admitting new V2 writes. Firestore allow rules compose with OR;
  one broad legacy grant can bypass a new V2-only predicate.
- **G2 migration snapshot:** immutable legacy snapshot, stable IDs, canonical
  digest, idempotent checkpoint, audited reviewer and independent restore plan.
- **G3 ambiguous outcome:** preserve pending immutable operationId and digest;
  lost ACK, missing permit and stale read never trigger automatic resend.
- **G4 observability:** test authorized positive transactions, adversarial
  old clients, exact billing/cost envelope and complete retention/privacy plan.
- **G5 mobile:** Android and iOS hardware evidence, key custody and backup
  rollback controls must pass separately.

## No-go triggers
Unknown writer, unverified old APK, mutable session claim, absent issuer,
missing key/backup policy, any live data ambiguity, incomplete platform proof,
or an unreviewed production rule change. Default is deny and stay on the
currently approved release. This document is not a migration runbook.
