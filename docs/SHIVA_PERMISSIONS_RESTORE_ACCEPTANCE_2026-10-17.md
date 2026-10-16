# Shiva — Permissions and backup/restore acceptance models

The standalone tests `test_shiva_permission_matrix.py` and `test_shiva_restore_quarantine.py` add two independent acceptance surfaces.

**Authorization:** finance writes require an approved identity, explicit granular finance permission, exact UID/team match and a current epoch. A privileged-sounding role label does not bypass permission checks; truthy non-boolean permission values are rejected. These tests do not verify actual Firebase security rules.

**Restore:** a restored pending or uncertain financial intent must require manual reconciliation; a foreign UID/team or malformed state must be quarantined. Even a locally restored confirmed state is only read-only when server marker evidence matches. No restore may implicitly initiate a financial send. This is a model, not an actual encrypted backup, restore implementation or crash-durability proof.

These review-only additions do not touch protected Home, Finance, AuthGate, server ACL or live backup data. Native persistence and real cross-device fences remain owned by Luna's separate Misiunea XIII. `production_ready=false`.
