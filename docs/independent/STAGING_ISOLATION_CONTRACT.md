# Staging isolation and non-destructive test contract

## Objective
Prove real application workflows without risking `andicarpet-e777e` or interfering with Luna's development branches.

## Required separation
- Dedicated Firebase staging project with independent Firestore, Auth, Functions, Messaging, service accounts, hosting and budgets.
- Separate app identifier or build flavor and Firebase configuration; staging APK must not replace production app or share production signing credentials.
- Dedicated test identities, synthetic teams/locations, and synthetic financial values. No live customer/member data copied into staging without a separately reviewed sanitization process.
- CI and scripts must fail closed if target project ID equals `andicarpet-e777e` for destructive writes, restores, backfills or migrations.
- Credential scopes and environment approvals must prevent staging jobs from authenticating to production.
- Capture the exact candidate integration tree SHA, not just independent PR head SHAs.

## Scenario acceptance matrix
| Scenario | Expected observable evidence |
|---|---|
| Two editors modify same day | Conflict/rollback behavior and persisted provenance are correct |
| Legacy day deleted and recreated | No silent resurrection or overwriting different schedule ID |
| START/FINAL replay after offline reconnect | No duplicate executions, stable audit and Centralizator counts |
| Overnight work | Correct date grouping and PDF chronology |
| 80+ historical interventions | Complete multi-page PDF with no clipping and matching counts |
| Financial cross-team edit | Denied with no partial mutation or audit bypass |
| Manager identity change | Only authorized role can assign/change |
| Hidden/admin directory profile | Not listed to ordinary active users |
| Directory backfill interrupted | Safe rerun, no stale hidden member republishing |
| Invalid APK provenance | Release blocked before distribution |

## Operational proof format
For each case record: exact source SHA, staging project ID (non-sensitive), build hash, test user roles, timestamps, screenshots/log IDs, Firestore before/after snapshots (redacted), expected and actual outcome, and known limitations.

## Restrictions
No test may write to production, run against the real member directory, disable device security protections, or use production signing keys. Do not claim E2E proof based solely on synthetic harnesses or emulator unit tests.
