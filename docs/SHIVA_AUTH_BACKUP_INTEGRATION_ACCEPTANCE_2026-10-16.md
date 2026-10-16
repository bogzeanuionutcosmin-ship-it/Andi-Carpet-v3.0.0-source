# SHIVA — AuthGate, backup and operational isolation acceptance plan

**Review-only; no executable rollout.** Base PR #78; PR #80 is owned by Luna and remains read-only. This is an independent cross-feature integration checklist, not a repeat of XI lots. All 116 protected hashes and 21 freeze pins stay unchanged. production_ready=false.

## Boundary matrix and observable assertions

| Boundary | Existing evidence | Missing independent acceptance / fail-closed outcome |
| --- | --- | --- |
| AuthGate A1→B→A2 | Mission IV A01–A12 and C01–C08 GREEN on historical isolated SHA; root Navigator/Messenger and FCM/GPS async guards | Repeat against actual integrated tree; stale finance operation completion, Vision signal, restore continuation and pending journal must never appear in B or A2. Re-login same UID does not revive A1 lease. |
| Same UID profile reconnect | Mission IV C01/C02 preserves legitimate route/profile | No needless journal reset or duplicate intent creation; observer generation remains valid only if same epoch. |
| Team transfer while signed in | X FinanceHomeCandidate binds UID+generation+team | Revoke old source and callback before new team is mounted; old ACK is not new team's authoritative model; no cross-team marker read or diagnostic. |
| FCM and GPS async permission delay | Mission IV/Vision VI fake SDK coverage | No new post-await attachment/writes after epoch change. Already-sent remote effects cannot be undone; no assertion of hardware GPS/FCM correctness. |
| Finance commit then ACK lost | IX/X/XI isolated model/emulator witnesses | UI displays uncertain, journal remains recoverable, no second send, no rollback/paid claim. Manual same-operationId server-marker reconcile only. |
| Backup export concurrent with write | Existing export loops top-level collections independently | Label export non-atomic; source-version pinned proof only where available. No claim of global consistent backup, no silent omission of financial markers. |
| Restore malformed/unknown schema | Earlier characterization and backup proposal | Zero writes before preflight; future schema must fail closed; unknown-only must not be called successful. Finance/settlements and pending journal must not be overwritten. |
| Restore already executing during logout | Mission IV scope protects new UI callbacks but not previously committed operations | Every subsequent step checks ownership and durable operation identity; already-sent commit is uncertain until reconciled, never treated as canceled. |
| Duplicate migration on two clients | Prior synthetic concurrency witness | Server idempotency and schema gate needed; local boolean or lease without transaction not enough. No destructive migration from stale schema. |
| Legacy APK vs V2 | X/XI documented incompatibility | Server-enforced per-source protocol/version gate before any new ledger activation; rollback must not reauthorize legacy overwrite. |

## Scenario ordering for an isolated future staging run

1. Freeze exact tested source SHA, protected hash manifest and pins; capture installed APK versions and backend rules hash, not live credentials.
2. With synthetic staging accounts A and B, exercise A1→B→A2 while blocking finance ACK, Vision callback, FCM permission and GPS permission independently. Verify zero cross-epoch UI exposure and zero new writes by stale owner.
3. With two isolated browsers and two physical devices, reproduce local journal interleaving, lost ACK and restart. Require durable single operationId and no silent journal replacement; without atomic cross-process storage, **STOP**.
4. Inventory all settlement, manager/rate, OCR/manual/confirm, perDiems and v2 settlement writers. Deny unsupported operations explicitly; never route them through receipt-only adapter.
5. Prove non-atomic backup detection with concurrent source mutation; validate malformed/future-schema, partial export, offline, crash and duplicate restore requests without destructive writes. Do not execute financial restore.
6. Check old/new APK behavior against the same staged source and restrictive rules; require legacy writer rejection *and* an approved upgrade/rollback path, not a permissive fallback.
7. Measure actual Firestore reads, writes, rules accesses, document/index sizes and mobile secure-storage persistence against agreed zero-incremental-cost target. Stop on unexplained spend or integrity risk.
8. Only after explicit source-by-source authorization, review any proposed protected Home/AuthGate/main patch. This plan grants no such authorization.

## Evidence classification

- **Verified historically:** isolated AuthGate Mission IV tests; Vision VI test checkpoints; finance IX/X emulator/model tests on their respective exact SHAs. These are not cross-branch integrated acceptance.
- **Observed in source/documentation:** XI receipt candidate, enum-only observation, readback-not-CAS interleaving, non-atomic backup, legacy client incompatibility.
- **Not verified:** integrated Home routing, physical cross-process journal, real hardware, live Firebase ACL/usage, coherent multi-source restore, production migration and upgrade gate.

## No-go rules

Never merge PR #75/#78/#80/#82 into main, change production Firebase/rules/indexes, activate billing/paid AI, ship APK or alter protected source/pins without the distinct approval already required by the project. CI green is not authorization. Vision status is not financial proof. No speculative rollback, auto-retry of uncertain, truncation of receipts, rounding existing money, or merging `perDiems` with `per_diem_settlements_v2`.

References: `docs/MISIUNE_IV_AUTHGATE_REZULTATE_2026-10-14.md`, `docs/MISIUNE_VI_VISION_HARDENING_2026-10-15.md`, `docs/PROTECTII_BACKUP_MIGRARE_PROPUNERE_2026-10-14.md`, `docs/MISIUNEA_X_HOME_BOUNDARY_2026-10-16.md`, `docs/MISIUNEA_XI_ROLLOUT_PROPOSAL_2026-10-16.md`, PR #75 and PR #80 read-only.
