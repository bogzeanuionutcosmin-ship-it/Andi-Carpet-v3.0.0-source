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
