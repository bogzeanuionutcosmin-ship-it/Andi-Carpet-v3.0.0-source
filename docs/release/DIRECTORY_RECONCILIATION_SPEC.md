# Directory backfill reconciliation specification

Status: DESIGN ONLY. No Firebase operation performed.

## Synthetic staging dataset
Include source profiles: active member, inactive member, hidden member, admin, deleted member, legacy member without optional fields, concurrently updated member, and member whose transaction is deliberately retried. Use invented identifiers and no personal data.

## Deterministic expected directory
For each `users/{id}` snapshot, calculate `projectMember` using the checked-out candidate implementation. Expected IDs are precisely those for which the projection is non-null; expected document fields match the projection allowlist. Verify that hidden/admin/deleted profiles have no directory record. Inactive non-hidden members remain projected with `active: false` according to current source; do not silently change this expectation.

## Reconciliation output
Record counts for eligible, missing, extra, changed and identical directory IDs. Store only synthetic IDs and field-name differences; do not log phone numbers, photos or private profile contents. Compute a canonical deterministic hash for non-sensitive fixture projections if useful.

## Failure injection
1. Stop after a prefix of processed profiles, restart and verify eventual convergence.
2. Deliver delayed source-write events after hide/delete; ensure no stale re-publication.
3. Retry Firestore transactions and verify operation counters are counted only after successful commits.
4. Change profile fields during backfill; verify final directory matches the latest source state after triggers settle.
5. Attempt unauthenticated, inactive and active-client reads/writes; verify the documented Firestore ACL matrix.
6. Ensure any dry-run refuses `andicarpet-e777e` and lacks production credentials.

## Stop conditions
Unexpected public field, extra hidden/admin record, missing eligible member, project ID ambiguity, failed reconciliation or unreviewed privacy policy decision. No production backfill before explicit approval, backup and rollback plan.
