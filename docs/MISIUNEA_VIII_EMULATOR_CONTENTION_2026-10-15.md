# Emulator contention discovery — not a transparent retry guarantee

On 231059e, run38707851670 / job116331612929: 37/40 actual emulator assertions PASS,
3FAIL (two-device races in both collections and20copies of oneID). Positive sequential
receipt/replay, edit/close/create, Admin rights and Restore protection passed.

The JavaScript client can receive permission-denied from latest-state Rules before
an optimistic contention retry returns to the callback. Therefore a losing call is
not guaranteed to throw our local revision-conflict exception. A generic SDK error
remains UNCERTAIN in the Dart repository. It never authorises deleting the journal,
rolling back memory, changing the operation ID or automatically writing again.

Some denials also reached1000Rules expressions. The follow-up caches the finance
user/parent in let bindings, checks excluded catch-all roots BEFORE Admin predicates,
and avoids repeated full permission/member predicates for the financial actor.
Rules pin0fd4bf3... -> bd024d10fb3e4e7fd5a74e3e5633af366d4d998e5afe81bd36dcdb60c15f3ee6.
All other115 catalog entries are preserved.

Acceptance still requires exactly one durable application and one marker under
concurrency. No assertion has been removed: tests now explicitly distinguish a local
revision conflict from SDK uncertainty, reject the1000-expression failure, and read
immutable server evidence for each uncertain SAME-ID client. Different-ID loser
remains unresolved in the real client; the test reads both markers and target for
audit but does not claim an absent marker alone proves non-commit. A stronger
read-only conflict-resolution contract and final UI are still required. No financial
retry was added to obtain green.

This suite uses JS SDK against actual emulator rules, not Flutter SDK network
integration. Dart unit tests cover the repository/adapter/coordinator separately.
Full Flutter SDK + emulator + restart/offline acceptance remains a release blocker.


Continuation: a722238 CI had38PASS/2FAIL; cost reduction alone did NOT fix all
expression exhaustion. New predicate ordering checks target and marker revisions
before authorisation/binding/transition helpers. Stale envelopes are rejected
with the same required successor revision; no permission or atomicity condition
is removed. Added a focused stale-envelope case which explicitly rejects an
expression-budget error. Rules pin bd024d10fb3e4e7fd5a74e3e5633af366d4d998e5afe81bd36dcdb60c15f3ee6 -> 0c446a3d99c12d5ccbb0d52deec17de12fd7daf075eb771acfff3d7d31229591. Actual CI pending.

Guard reordering ab518dd still had38PASS/3FAIL, including the new focused
stale test; it is not accepted. Follow-up removes repeated general isActive/
userData/permission expansion from financial reads, marker reads and write
authority, using one profile binding and an explicit effective-permission
ternary. Legacy fallback semantics are retained and tested (worker manager
allowed; explicit empty list denied). Creation now permits reading an absent
settlement to an active view-own manager, necessary for the actual marker-first
transaction; no existing foreign document gets a new read grant. New rules pin
a59b0a27d5e58b2e7e3c9e4936addeeff52c71dce29901e340795842b8060cf4. All previous assertions retained. CI pending.
