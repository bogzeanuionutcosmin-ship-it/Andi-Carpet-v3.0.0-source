# XIII — session fencing candidate (opt-in, production_ready=false)

This candidate preserves `HistoryXiIntent.encode()` and its digest. It does not
add a session field to a historic receipt or retag pending work. The new frozen
`FinanceSessionXiiiIntent` envelope contains format `AndiSessionXiii`, version1,
`binding:{ownerUid,teamId,epoch}`, and the exact XI raw string. A journal using
this gate must persist that envelope/binding with the intent before submission.
Raw V1/XI pending work is NOT silently upgraded. A new login generation may
review prior evidence but cannot execute an old intent under its new epoch.

The shared authority is `financeSessionEpochXiii/{uid}` with exactly
`{ownerUid,teamId,epoch,enabled}`. Epoch is a positive integer at most
9007199254740991. Devices do not generate epochs using clocks, cache, timestamps,
BroadcastChannel or login counts. ALL client identities, including admin, are
forbidden from creating/updating/deleting this authority in the standalone rules.
The trusted provisioner must atomically increment, never recycle/decrease it,
and coordinate authorization/team changes. Saturation must fail closed.
**The provisioner is BLOCKED/not implemented, deployed or activated.** Synthetic
emulator authority writes use `withSecurityRulesDisabled`; they are not an
application endpoint. Admin SDK bypasses rules and requires its own trusted audit.

The chosen epoch is GLOBAL PER UID. Authoritative logout-all invalidates every
device/tab using the previous epoch; a local logout alone cannot promise remote
revocation, especially offline. Supporting logout-one-device needs a separate
server device registry/token contract, intentionally not invented here. A→B→A2
must acquire a fresh authoritative epoch for A; delayed callbacks must retain the
frozen old epoch. Team transfer advances the epoch and changes authoritative
membership/manager state atomically. No history or money is reattributed.

`FinanceSessionXiiiPort` wraps `FinanceAtomicPort`. On EACH transaction callback,
it reads authoritative fence and immutable permit before invoking the repository.
It buffers writes, restricts paths to the one bound XI intent, requires exactly
the matching receipt+summary pair, then writes the immutable companion permit
in the same transaction. No network wait outside the transaction can replace the
fence read. No writes to epochs/legacy collections are exposed by the adapter.
The Firestore adapter is separate, emulator-only and explicitly accepts these
new paths; the XI adapter's narrower path policy is not bypassed or modified.

Server safety requires the NEW standalone `finance_xiii_session.rules` fixture:
every receipt and summary transition requires an immutable NEW permit via
`getAfter`, matching actor/team/digest/paths and CURRENT authoritative epoch.
A malicious client skipping all Dart guards is still rejected on stale epoch.
The permit also requires the corresponding newly created receipt and valid
summary transition; permits cannot be orphaned, rewritten/deleted or replayed
into another write. Existing XI/V1 production rules DO NOT implement this gate.
No production rule/configuration was changed. Any additive production rollout
must remove overlapping catch-all/legacy grants and gate ALL financial writers;
otherwise Firestore's OR semantics would bypass the candidate.

## Revocation ordering and uncertainty

If the financial commit serializes before authority revocation, it remains
accepted permanently; later revocation cannot retract it. If revocation serializes
first, a stale write is denied; an SDK transaction which already read the fence
retries on version change and cannot commit against the earlier epoch. A client
may still observe a timeout/lost ACK after either outcome: report uncertain,
preserve the exact local intent and reconcile evidence, never invent rollback.
The genuine emulator probe pauses after transaction reads, advances authority,
and releases the stale transaction. It proves no partial receipt/summary/permit.

After confirmed server commit then lost ACK, read-only reconciliation uses the
SAME operationId, digest, frozen epoch and immutable permit. It does not demand
that the historic epoch remain current, because that would hide real accepted
money. Current read authorization is still required by server rules and the
monotonic local session guard. A new authorized A2 session in the same team may
review old evidence; the logged-out instance stays retired. A transferred/revoked
user cannot read the former team's receipt via this gate and must keep pending
uncertain for authorized administrative review. No automatic cleanup is licensed
by a matching amount or missing marker. Missing/corrupt/cached permit is unproven.
The code never executes a second financial transaction during reconciliation.

## Evidence levels and command

`test/finance_intent_session_xiii_test.dart` is a RAM/versioned-transaction MODEL:
canonical envelope, atomic three-doc pair, fence-change retry, lost ACK+epoch
advance read-only reconcile, monotonic logout and missing/corrupt permit.
`tests/firestore/finance_xiii_session.test.cjs` uses actual Firebase JS SDK against
loopback Firestore emulator with standalone rules and independent SDK contexts:
two devices same revision; client-check bypass; revocation during transaction;
A→B→A2; commit-before-logout+lost ACK; team transfer; permissions/admin no bypass;
protected authority; forged/orphan/rewritten permit; invalid epoch bounds.
This is NOT two physical devices, OS durability or native hardware evidence.
Run from repository root with existing CI npm dependencies:

```
npx firebase emulators:exec --only firestore --project demo-andi-carpet --config firebase.rules-test.json 'node --test --test-concurrency=1 tests/firestore/finance_xiii_session.test.cjs'
```

Local results and final SHA-specific CI must be recorded by the parent report;
syntax inspection alone is not an emulator PASS.

## Cost and remaining integration

Append: 2 extra transactional reads (fence+permit) and 1 extra write (permit)
over XI: 4 reads/3 writes, or 5 reads for source bootstrap. Replay: 4 reads/0writes.
Repository reconcile via guarded port: 4 server reads (permit+row,permit+summary),
0writes/0transactions. Snapshot caches are rejected for evidence. Rules access
reads, retries (adapter max3) and denied requests may incur additional costs;
these logical counts are NOT billed invoices or guarantees of a free tier.
No polling, timer, listener or paid service was introduced. Immutable permits add
one bounded document per accepted receipt and require retention with the receipt.

BLOCKED: real AuthGate/session provisioner integration; monotonic trusted epoch
provisioning across all backend/admin paths; atomic team handoff permissions;
exclusive V1/V2 old APK rollout; reconciliation access for transferred owners via
an audited authorized workflow; production rule/index/quota review; end-to-end
native hardware tests and persistent session-envelope integration. Candidate-only
code is not proof that current deployed writers are fenced. Backup/restore must
not decrease authority epochs or reuse them; an authority rollback needs global
fence invalidation outside the restored financial snapshot. No live migration,
restore, merge, deployment, billing changes or APK distribution is authorized.

## Local executable result and rules budget correction

Local Linux run 2026-10-16 UTC (2026-10-17 Bucharest): Firebase JS12.19.0,
Firestore emulator1.19.8, **15/15 PASS,0FAIL,0SKIP**,5118ms. Two initial runs
returned7/14PASS: positive writes hit the real1000-expression rules budget
because the full XI financial transition and new permit shape were repeated
across documents. Those runs were failures, not evidence of accepted writes.

The final fixture validates the complete financial transition ONCE, on the
summary write. Row and permit creates require the after-summary revision to be
before-summary+1 and lastOperationId to match: they therefore force an actual
summary write. The summary in turn requires the new row plus NEW permit and
current authoritative fence. Permit shape is checked on its own mandatory
create. This mutual forcing preserves all three atomic directions without
repeating the full validation. An additional adversarial test rejects all six
nonempty incomplete subsets of {summary,row,permit}, and a complete three-doc
batch with malformed money, then verifies legitimate append still succeeds.
Positive permission tests must remain in CI: a permanently rejecting ruleset is
not a successful financial safety gate. Final SHA-specific CI is separate from
this local result.
