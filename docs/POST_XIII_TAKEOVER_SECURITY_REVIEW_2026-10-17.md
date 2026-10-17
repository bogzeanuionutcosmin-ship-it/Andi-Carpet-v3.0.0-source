# Post-XIII takeover — independent safety review (no rollout)

**Source:** PR #85 at immutable SHA `9396b9b11722f492ebe098b1fc0da0f240a2a435`. This review is on a **new branch** and does not modify PR #85 or PR #82. `production_ready=false`.

## Trust boundaries still unproven

1. **Non-adoptable capability issuer.** A globally mutable custom claim alone cannot prevent an older refresh session from adopting a new epoch. A trusted issuer must bind authorization to the particular login/session/device and enforce refresh/revocation at the server. The Python test models this *requirement*; it does not implement the issuer.
2. **Anti-rollback and backup.** A correctly checksummed SQLite file can still be an older valid copy. Authentication and independent monotonic high-water state are required to reject stale backups; missing trusted state must quarantine. The model is not encrypted backup or trusted hardware storage.
3. **Exclusive V2 writer gate.** Old APKs and direct legacy writers may bypass a candidate if any overlapping server rule permits writes. Production rollout requires a server-enforced exclusive gate and an audited writer inventory, not merely a new client protocol.
4. **Android/iOS hardware.** Linux/Windows/macOS AOT probes do not establish Android/iOS power-loss durability, private-directory ACLs, key custody, background suspension or native packaging. Do not infer those results.
5. **Unknown finance outcome.** After lost ACK, missing marker or stale permission, retain the exact intent and require authorized reconciliation; never reissue as a fresh operation or infer rollback.

## Independent acceptance criteria

- A1→B→A2 must not let A1 adopt A2's newly issued capability.
- Every financial writer must be rejected server-side unless it provides a complete immutable V2 receipt/summary/permit under the current trusted authority.
- Restoring an older valid database must be detected by independent trusted state, or quarantined if no such state exists.
- Restored uncertain work is never automatically retransmitted.
- Production release requires independently verified CI, device evidence, trusted issuer, encryption/backup policy and explicit approval.

The companion Python files are **offline threat-model checks only**. They do not validate production Firebase rules, hardware, cryptographic identity, or app integration. No merge, deployment, migration, live data change or activation is authorized.

## Additional review cases

- `test_post_xiii_marker_integrity.py` requires a read-authorized, matching immutable marker (UID/team/operation/digest/frozen epoch). Missing evidence stays uncertain; mismatches conflict.
- `test_post_xiii_retention_policy.py` refuses silent capacity-based eviction of unresolved records. The real candidate's 32-intent limit is per scope, not a global retention solution.
- `test_post_xiii_key_custody.py` expresses device binding, unlock, current authorization and revocation requirements, **without** claiming actual encryption, Keychain, Keystore or a production key service.

All three are Python review models, not native/SDK execution. The review manifest now enumerates ten threat-model suites; CI status for the new branch is not established. `production_ready=false`.
