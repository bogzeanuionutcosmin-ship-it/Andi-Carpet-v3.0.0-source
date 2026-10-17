# XIII → post-XIII: overlap audit and next engineering gates

Reviewed immutable XIII HEAD: `9396b9b11722f492ebe098b1fc0da0f240a2a435`.
This is a **review-only gap assessment**, not a claim of new runtime safety.
`production_ready=false`.

## Do not reimplement Luna's evidence

| Area | XIII evidence already exists | Post-XIII duplicate | Action |
|---|---|---|---|
| Native process contention and crash | `tool/native_xiii/adversarial_test.py` uses compiled Dart AOT FFI/SQLite in independent OS processes | `test_post_xiii_crash_phase.py`, retention/path policy models | **Do not extend synthetic crash tests**; Android/iOS device work remains blocked |
| Server fence, signed epoch, replay, 3-document atomicity | `tests/firestore/finance_xiii_session.test.cjs` uses Firebase SDK + emulator; signed claim issuer is synthetic | `test_post_xiii_authority_rotation.py`, `test_post_xiii_epoch_bounds.py`, `test_post_xiii_batch_atomicity.py`, `test_post_xiii_authority_read_gate.py`, `test_post_xiii_receipt_binding.py`, `test_post_xiii_marker_integrity.py` | **No additional models**; need trusted non-adoptable capability issuer, with actual refresh/revocation integration |
| Restore, no resend, historical epoch | XIII native and Firestore tests and migration report cover uncertainty and frozen identity | `test_post_xiii_backup_rollback.py`, `test_post_xiii_no_implicit_restore.py` | Keep only as unverified acceptance notes; need authenticated anti-rollback and real backup/restore integration |
| Financial writers and rollout | `docs/MISIUNEA_XIII_MIGRATION_WRITERS_2026-10-17.md` already inventories concrete writers and risks | `test_post_xiii_rollout_matrix.py` | Do not recreate inventory; need audited migration design with a server-side exclusive V1/V2 gate |
| Cost, key custody, log privacy | XIII report already identifies unknown live costs, key custody and privacy limits | `test_post_xiii_cost_bounds.py`, `test_post_xiii_key_custody.py`, `test_post_xiii_sensitive_logging.py` | Models are not performance, crypto, or privacy evidence |

## Actual unresolved integration work, not completed here

1. **Trusted capability issuer:** server-issued session-specific non-adoptable credentials; refresh-token and logout enforcement; cross-device revocation, team transfer and privilege changes. Do not mistake a mutable user-wide custom claim for a session-specific proof.
2. **Mobile native storage:** Android native engine packaging and app-private directory guarantees; iOS SQLite linking and container behavior; Keystore/Keychain and encryption-at-rest; backups, restore and anti-rollback; device-level kill/background/power-loss tests.
3. **Migration:** close every legacy financial write path at the server before enabling V2; audit the old-client experience and finance data migration without inventing an automatic resend.
4. **Evidence:** real Firebase SDK/emulator and native process tests are stronger than standalone Python policy models. Keep these classes of evidence explicitly separate; do not sum overlapping suites as unique coverage.
5. **Operational:** quantify live-plan read/write cost, native IO latency, energy, backup inventory, retention and failure handling only in an approved test environment.

## Scope and recommendation

PR #86 is **not a successor implementation of these gates**. Its Python files largely encode conditions already covered by stronger XIII tests or document still-blocked requirements. Their presence must not be presented as incremental production security. Keep PR #86 Draft and **do not merge it solely to add these models**. A future implementation PR should be narrowly scoped to one verified gap with a real integration harness and appropriate authorization.

No changes to PR #85, live Firebase, protected app code, billing, deployment or release status.
