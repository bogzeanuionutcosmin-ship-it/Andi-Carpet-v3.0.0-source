# Staged durable encoding hardening

Integral double values in the safe JavaScript integer range now encode as JSON
integers, preventing200.0/200 representation differences from changing the request
digest between VM and Chrome. The immutable request's numbers and financial
transition arithmetic are unchanged. A golden test runs on both platforms.

User maps containing the reserved @date key are rejected before persistence.
Without that restriction, an arbitrary map could decode as a DateTime after
restart, violating exact-request semantics. Actual DateTime serialization and
round-trip remain supported. Nested/literal tag injection is tested.

This draft protocol has never been deployed. Pending envelopes/markers generated
by earlier synthetic prototypes may have a different digest and must remain
conflicted for review; do not rebind their ID, silently rewrite markers or migrate
real data. Production migration/backward compatibility is not accepted. No money
rounding, receipt cap, automatic retry or production activation is introduced.
