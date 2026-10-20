# Fail-closed release criteria

Release status: HOLD until all gates have traceable evidence.

## Decision table
| Condition | Required decision |
|---|---|
| Current main workflow can deploy production from push | HOLD until approved environment-level mitigation and verified transition |
| APK release signed with debug certificate | HOLD |
| APK SHA-256 or signer fingerprint unknown | HOLD |
| Combined candidate tree SHA not recorded | HOLD |
| Staging Firebase role and migration tests absent | HOLD |
| Android physical-device upgrade untested | HOLD |
| Financial cross-team mutation authorization unverified | HOLD |
| All gates passed with immutable evidence | Eligible for human release review; not automatic deploy |

## Evidence hygiene
For every PASS attach exact commit/tree SHA, test environment, command, timestamp, observed result and immutable artifact URL. A source review is not a runtime test. An unknown cannot be silently promoted to PASS.

## Scope
Documentation-only criteria. No deployment, merge, signing, or data mutation.
