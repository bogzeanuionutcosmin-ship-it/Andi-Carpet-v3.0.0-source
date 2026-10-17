# Post-XIII — trusted session issuer acceptance contract

Status: DESIGN/REVIEW ONLY. `production_ready=false`.

## Existing XIII boundary
`lib/finance/session_xiii/session_fence_xiii.dart` binds immutable
`ownerUid, teamId, epoch` to the XI history envelope and checks the server
fence inside every transaction callback. `finance_xiii_session.rules` requires
a signed `financeEpoch` claim. The emulator uses mock signed claims; the
provisioner does not exist. Do not replace the existing tests.

## Acceptance criteria for a separate implementation
1. A fresh, server-verified authentication event obtains a non-adoptable
   capability for exactly one authorized session and team; client clocks and
   client-supplied epochs have no authority.
2. An A1 refresh credential cannot silently receive A2's epoch/capability,
   including after a global custom-claim change. Explicitly test refresh
   before and after logout-all, account transfer and reauthentication.
3. The trusted issuer increments epoch atomically and never reuses/decreases
   it. Saturation, transaction conflict, issuer outage and malformed
   membership fail closed. No admin bypass.
4. Cross-device tests must distinguish **logout-all** from logout-one-device.
   XIII uses a global per-UID epoch; single-device revocation requires a
   new server registry/contract and cannot be claimed by current rules.
5. Test both orderings: commit-before-revocation remains valid; revocation-
   before-commit denies stale writes. ACK loss remains uncertain and only
   authorized read-only reconciliation can resolve it.
6. Token renewal and team change must not rebind a persisted old pending
   envelope. Old receipts retain their immutable original identity.
7. Test malicious SDK clients that bypass Dart; use real Firebase emulator
   and rules, not only mocked application callbacks.
8. Produce a threat review for Admin SDK bypass, account disable, refresh
   token invalidation, stolen old tokens and partial backend failure.

## Release gate
No production AuthGate, Functions, rules or billing changes under this review
PR. Evidence must include implementation SHA, emulator results, issuer
transaction tests and an approved revocation policy.
