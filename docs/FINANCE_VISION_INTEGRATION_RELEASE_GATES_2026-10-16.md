# Finance + Vision — integration gate review (Shiva, 2026-10-16)

**DRAFT / REVIEW ONLY / production_ready=false.** Base: PR #78 HEAD `291b10ac74d1c0f58d3e44416cf2f48ef8dc347b`. Read-only upstream: PR #75 HEAD `48235b14fa7345c454882960aecb0ba66ba1b596`; Mission XI PR #80 is concurrently owned by Luna and MUST NOT be altered. This review introduces no runtime wiring, merge, cherry-pick, Firebase writes, APK or paid service.

## Integration invariant

One and only one financial execution authority per authenticated ownership epoch: the existing FinanceIntentCoordinator / FinanceExpenseDemoAdapter and checked journal. Vision observes only the terminal `FinanceIntentStatus` enum via a one-way optional callback. Vision MUST NOT create an intent, retry, infer monetary success, expose amounts, UID, operationId, digest, raw errors or mutate storage. Observer failure cannot alter the original financial result. A1→B→A2 revokes stale session/lease/callbacks, even when UID returns.

## Explicit release blockers (not resolved by a green CI)

1. Home/AuthGate/main remain protected; the X Home patch is textual, unapplied and flag FALSE. No Home activation without separately explicit authorization and source-specific regression proof.
2. Existing legacy `set(merge:true)` writers and old APKs cannot meet operationId/revision/digest CAS. A server-enforced minimum-version gate and staged upgrade must precede any live ledger switch. A UI upgrade prompt alone is insufficient.
3. Cross-tab checked journal readback is not CAS. Same-isolate single-flight is not a multi-process guarantee. Web Locks or a transactional local store need independent tests; absence of lock fails closed.
4. XI append-only V2 is candidate only; no V1→V2 automatic migration, no double ledger, no truncation/TTL, no financial restore or unreviewed bootstrap.
5. Financial `uncertain` after lost ACK may already be committed: preserve pending journal, reconcile same operationId against authoritative server marker and revision; never resend automatically.
6. Other writers (manager/rate, OCR/manual/confirm, perDiems legacy/v2) need independent authorization and data contracts; receipt adapter cannot silently cover them.
7. Restore requires consistent cross-source inventory, marker completeness and conflict/rollback protocol; a per-source prefix checksum is not a live restore authorization.
8. Actual hardware, independent devices/processes, offline/restart, Firebase staging, ACL and cost ceilings remain unverified. Android debug compile and Chrome emulator tests are not release acceptance.

## Review/acceptance sequence

- [ ] Confirm PR #80 final SHA and **all active** workflow results; require XI final report, protected 116 hashes and 21 freeze pins unchanged. SKIPPED is not SUCCESS.
- [ ] Audit source-level compatibility of #78 with #75 and #80 without changing their branches; produce precise import/ownership matrix, conflict report and an isolated new integration branch only when no concurrent writer owns its files.
- [ ] Add one injectable enum-only Vision observer to the existing finance candidate; tests must prove identical financial return, no extra Firestore reads/writes, callback exceptions isolated, and no retry on uncertain.
- [ ] Exercise AuthGate epoch A1→B→A2, logout during ACK/reconcile, stale callback and UI refresh from authoritative server source. No cross-account Vision journal exposure.
- [ ] Demonstrate legacy writer blocking, durable cross-process journaling, bounded history, independent writer contracts and recoverable backup before considering Home wiring.
- [ ] Obtain explicit protected-source authorization before touching Home/AuthGate/main; then validate staging with two real devices and upgrade/rollback strategy before any merge/deploy/APK.

## Decisions carried forward

Max two members/team; one active team/member; graph 23:30–09:30 with operational day defined by shift end; per diem due at 09:31, advance above accrued due allowed; `perDiems` and `per_diem_settlements_v2` remain distinct; granular server-side permissions; Vision local deterministic/offline-first, anonymous bounded diagnostics, incremental cost target 0 lei (not a guarantee). Product rules remain authoritative in `REGULI_DEZVOLTARE_SI_FUNCTIONARE_ChatGPT.md` and `ARHITECTURA_VISION_ULTRON_JARVIS_ZERO_COST.md`.

This file is a **gate**, not evidence that the integration has been built or validated.

## Source-level audit update — XI and Vision (2026-10-16)

Read-only inspection of actual XI candidate at `81e81f2bb6c066d2fa2e1a9a5ebe41c715b7a920` and Vision integration at `48235b14fa7345c454882960aecb0ba66ba1b596`:

| XI interface | Vision interface | Integration decision |
| --- | --- | --- |
| `HistoryXiObservation.operationUncertain` | `VisionDiagnosticSignal.financeOperationUncertain` | Explicit enum mapping only, no arbitrary string or server error |
| `HistoryXiObservation.revisionConflict` | `VisionDiagnosticSignal.financeRevisionConflict` | Explicit enum mapping only, no money/identity data |
| `observeHistoryXiResult(result, emit)` returns original `FinanceIntentResult` | `FinanceVisionOutcomeObserver.observeStatus(status, sink, platform)` returns bool | Adapter must **not** replace financial result with bool; diagnostic delivery best-effort, exceptions isolated |
| XI independent `HistoryXiIntent` / append-only repository | IX `FinanceIntent` coordinator and observer | **No implicit protocol bridging**: independent candidate; never reinterpret pending V1 envelope as V2 |
| XI revocation and source ownership | `VisionAuthenticatedSessionScope(sessionEpochKey, sessionIsCurrent)` | Session epoch and team/source authority must be revalidated; UID alone insufficient |

The two observer surfaces overlap semantically but are **not** a reason to install two listeners/coordinators. The future boundary must choose one anonymous event emission path per financial outcome. A Vision signal is advisory, not an authoritative receipt, revision or ACL determination. Never emit `permissionRejected` from `rejectedBeforeWrite` without a separate trusted ACL fact.

**New blocker identified in XI proof:** reverse aggregation of floating amounts can reject legitimate `0.1+0.2+0.3`; a strict pinned-history proof therefore cannot universally certify existing monetary data. A proposed exact money representation needs a separate approved compatibility/migration contract; do not silently round, clamp, or convert existing balances. Timestamp nanosecond precision is carried in the XI V2 integer seconds/nanoseconds map, not native Firestore Timestamp; no V1 codec changes.

**Exact CI observation:** XI SHA `81e81f2`: Standard, Identity and IX Finance were SUCCESS; IX Android/Chrome workflow `38890474113` remained IN PROGRESS at this checkpoint. SKIPPED conditional workflows are not passes. This checkpoint is not final XI CI clearance; query exact SHA again before acceptance. Vision PR #75 SHA `48235b14` has all four active workflows SUCCESS. Neither proves real-device durability.

**Change-scope check:** this PR #82 only modifies this documentation file relative to PR #78. XI #80, Vision #75 and their protected sources are untouched; no CI or live integration is claimed for this review.
