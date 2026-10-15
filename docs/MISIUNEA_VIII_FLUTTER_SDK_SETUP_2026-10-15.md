# Flutter SDK emulator setup diagnosis

58ac66d job116452241844 seeded both emulators successfully and compiled/loaded
the browser test, but stayed in setUpAll until superseded. This is NOT a PASS
and no financial SDK scenario was certified. The follow-up adds constant stage
markers and30s setup deadlines, with an8min outer CLI deadline. Failures remain
RED; no assertion is removed or success accepted on timeout. Diagnostics contain
no UID/token/password/money. No application timeout/retry/production change.

98bbe35/run38745654765/job116458622311 confirms30s timeout specifically at
initialize_primary, before any scenario. Cleanup also referenced uninitialised
auth, adding a secondary fixture failure. Follow-up explicitly registers the
real Firebase Core/Auth/Firestore web plugin delegates for the browser unit-test
entrypoint and cleans only actually created apps/auth instances. No production
registration, mock delegate, financial assertion or SDK error classification is
changed. Existing locked transitive web packages only.
Official API references: pub.dev/documentation/firebase_core_web/latest/ ,
pub.dev/documentation/firebase_auth_web/latest/ ,
pub.dev/documentation/cloud_firestore_web/latest/ . Actual CI still required.

Real network result onfce0138/run38746250738/job116460560370:4PASS/1FAIL.
Setup/auth/Firestore, lostACK reconciliation,two clients,A→B→A2 and creation
worked. Strict closed-receipt local refusal returned UNCERTAIN because the real
web SDK wrapped the Dart FinanceRefusal. The assertion is preserved. Adapter
now retains typed callback refusal/conflict only if no write was scheduled in
ANY callback attempt. A scheduled write or untyped SDK failure stays uncertain.
Five injected SDK-wrapping tests cover beforewrite,afterwrite,earlier attempt
and untyped failure; exact realSDK closed assertion remains mandatory. No new
financial retry, no timeout/permission-denied reclassification as no-write.

Coordinator distinction: a wrapped callback refusal can prove no write only for
THIS invocation. If the durable intent was already pending (manual resume after
an uncertain attempt), that local rejection cannot certify the earlier outcome.
Journal preparation reports fresh/existing atomically; coordinator retains the
old intent and returns finance_prior_attempt_unresolved instead of erasing it.
One deterministic resume test enforces this rule. Missing server marker still
never proves non-commit. No automatic financial retry/rebase/rollback is added.
