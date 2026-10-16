# Shiva isolated financial authority test boundaries

These checks are **contract models**, not implementation integration or a claim of production security.

- `test_shiva_scope_isolation_contract.py`: scope key is (protocol, UID, team, epoch); duplicate operation IDs in distinct scopes do not alias. Cross-scope reads refuse. A reused ID with a changed digest conflicts. Marker lookup requires scope authority; a missing or mismatched marker remains uncertain.
- `test_shiva_session_interleavings.py`: all six prepare/revoke/send permutations, including a counterexample for local-only authorization.
- `test_shiva_shared_session_contract.py`: A1→B→A2, transfer, stale marker-read denial, and uncertain no-resend.
- `test_shiva_release_evidence_gate.py`: fail-closed review-only 20-gate baseline.

**Critical distinction:** this isolated journal model intentionally includes the epoch in its namespace to demonstrate segregation. A real durable financial recovery protocol must also define how a newly authorized epoch recovers the *same unresolved operation* without leaking old-session payload or minting a duplicate. Merely changing the storage key on logout is insufficient and could strand pending intents. No code in this branch wires that policy to Home or Firestore.

The native journal and authoritative shared-session implementation are owned by Luna Misiunea XIII, Issue #84. Shiva only exercises independent threat models and acceptance contracts. The tests are included in a branch-scoped workflow; success must be verified for the exact commit. No merge, deployment or production rollout.
