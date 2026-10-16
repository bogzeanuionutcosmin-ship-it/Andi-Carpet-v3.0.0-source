# SHIVA — Post-XII cross-tab session and integration boundary

Reference: PR #83, immutable head `7f3bbba3602e7ae109e4b678a90b2bd58431d88f`, four active CI workflows SUCCESS. Read-only upstream; this review does not import XII code.

## What XII establishes, and what it does not

- IndexedDB V2 + Web Locks + strict transactions protect cooperating same-origin browser writers; two real renderer PIDs and same-profile SIGKILL/restart have passed.
- Web Locks do not establish a common lock across browser profiles, devices, Android/iOS/Windows native processes or non-cooperating legacy writers. Firestore server CAS remains independently necessary.
- A callback scoped to the local AuthGate epoch does not synchronously know about logout/team transfer in another tab. Storage-lock safety and session authorization are separate properties.
- Browser strict durability is not proof against power loss, storage eviction, profile deletion, malicious same-origin code, encryption policy or OS backups.
- Existing uncertain intents require evidence-based reconciliation; neither a fresh login nor a newer observer may auto-resend them.

## Proposed shared-session contract — candidate only

A durable, origin-scoped session record would carry an opaque epoch identifier, UID binding, team binding and monotonically advancing revision, with an atomic compare-and-swap update on every logout, account switch, team transfer and permission revocation. No raw auth token, money or personal profile is stored in the record. A locally captured lease must be checked immediately before any financial send **under the same transactional exclusion boundary** as the operation's journal transition. An invalid lease blocks new sends, but cannot retroactively cancel an already-sent operation. The remote server must independently authorize the actor/team and reject stale protocol writers.

A BroadcastChannel notification can improve UI responsiveness, **but is not an authorization fence**: messages may be lost, delayed, or delivered after the sender has died. An IndexedDB generation record can serialize cooperating same-profile tabs, but cannot guarantee that a remote logout is observed between a lease check and an independently executed server call. A server-enforced session/version fence is required for the stronger cross-device promise; do not infer one from a client-side epoch.

## Acceptance matrix

| Scenario | Required proof | Current disposition |
| --- | --- | --- |
| A1→B while A1 awaits journal lock | B never reads A1 payload; A1 does not start a new send after revoked lease | NOT TESTED integrated |
| Tab A logout while tab B is idle | B refuses next new intent before network; stale callback cannot remount private A | NOT TESTED |
| Tab A logout while tab B already sent | Preserve uncertain until marker/server revision reconcile; never label canceled or retry | NOT TESTED |
| Team transfer with old pending receipt | Old team's journal remains segregated and recoverable only under proper authority; no adoption into new team | NOT TESTED |
| Crash between epoch update and UI notification | Persistent epoch authoritative; notifications advisory only | NOT TESTED |
| Browser profile A versus profile B | Independent local epochs/journals; server-side fence and CAS prevent unauthorized overwrite | NOT TESTED |
| Native Android/iOS/Windows restart | Transactional native store and OS-specific crash/key policy, tested on hardware | BLOCKED |
| Old APK against V2 server source | Explicit server version gate denies legacy mutation before rollout | BLOCKED |

## Required integration boundaries

1. Do not instantiate a second finance coordinator: retain one authority for each supported operation.
2. Do not wire PR #83 into protected Home/AuthGate/main without a separate reviewed patch and authorization.
3. Vision consumes only outcome enum/status and never UID, team, operationId, digest, amount, receipt content, token or raw error.
4. Reject unsupported manager/rate, OCR/manual expense, perDiems, bootstrap and legacy writers rather than silently falling back.
5. Preserve exact timestamp sec+nanos, history bounds, money precision and uncertain semantics. Never round existing finance values to force audit PASS.
6. Require staged multi-tab, multi-profile, native and server ACL proofs before activation. production_ready=false.

## Next isolated deliverable

Implement a pure contract fixture or standalone staging harness that injects session lease reads, delayed revocation and already-sent uncertain responses. Keep it outside protected runtime; use explicit assertions for zero second-send and no cross-UID exposure. No implicit activation or production Firebase writes.
