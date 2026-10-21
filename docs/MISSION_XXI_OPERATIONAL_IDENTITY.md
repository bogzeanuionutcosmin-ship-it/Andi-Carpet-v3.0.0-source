# Mission XXI — stable visits and official STOP

Implementation follows candidate 5944943d. No production migration or deployment.
Validation of this change is pending exact-HEAD CI; older success is not evidence.

## Identity and retries

New planned visits receive a random 128-bit `interventionId` once at creation.
Clone, reorder, postponement and transfer preserve it. Records and reservations
carry graph/day/visit scope. Record updates cannot retarget immutable identity.
Manual Dashboard START and Home arrival choose the same deterministic attempt
slot. Waiting reuses that slot; a finished refusal consumes it. Replayed START
and FINAL adopt committed server times only when all other business data agree.
Conflicting outcomes use the existing compare-and-swap error path.

Legacy visits retain empty IDs. They remain readable and operable through the
legacy path but cannot be silently attributed to a new graph. Official STOP
requires explicit reconciliation for legacy visits; no production backfill is
included. Deleted attempt slots fail on collision rather than overwrite history.

## Server closure boundary

`closeProgramGraph` authenticates the Firebase token, then transactionally reads
current user permissions, membership, every team schedule and record, reservation,
graph state and request receipt. It checks exact loaded day IDs/revision tokens,
all planned visit identities, the latest final result and absence of open attempts.
All graph days, the closed graph marker and receipt commit together. The marker
prevents a concurrent or later client adding a day/attempt to the closed graph.
Client rules reject direct closure even for Admin; the old catch-all excludes
operational collections so it cannot bypass these checks.

An identical request ID/body replays its receipt without changing timestamps.
A reused ID for another payload is rejected. Authorization is rechecked on every
replay. The HTTP client retries the same serialized request after transport/ACK
uncertainty and never falls back to local closure. Home reloads authoritative
schedule revisions after acceptance. A crash recovers closed state through the
normal subscriptions; durable resubmission of arbitrary offline intents is not
claimed. The endpoint requires an active profile and an explicit stored
`effectivePermissions` grant for members; Admin remains supported.

Completed-record corrections, including additional facade work, remain available
through the audited Centralizer flow after closure. Reopening a newly closed
graph requires a future explicit server operation; local reopening cannot erase
the graph marker. Backup/restore of closed schedules/graph state/receipts requires
an authorized server restore protocol and is not claimed complete by the older
client batch-restore test.

## Emulator evidence required

- Firestore tests: atomic all-day persistence, immutable receipt replay, stale
  revisions/membership, legacy ambiguity, refusals/running/unexplained outcomes,
  authorization revocation, direct Admin/member bypass, identity retargeting,
  concurrent correction and concurrent added day.
- Native: two clients replay stable START/FINAL with different local times;
  Home Program UI calls the actual Functions emulator endpoint, reloads closure
  and receipt, then replays the accepted request.
- Flutter tests: identity retention, graph isolation, retry slots, codec roundtrip,
  replay outcome matching and HTTP uncertain-ACK/conflict handling.

Firebase demo emulators are separate from staging. Live provider, physical GPS,
background, camera/OCR, signing and upgrade acceptance remain external gates.
Deploying this protocol requires coordinated Functions/rules/application rollout,
legacy reconciliation and a rollback plan. Nothing here authorizes deployment.
