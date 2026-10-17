# Staging and privacy evidence ledger — template

**Status:** NOT RUN. This document records test obligations, not test outcomes.

| ID | Assertion | Evidence required | Status |
|---|---|---|---|
| S01 | Staging project isolated from production | Project ID, IAM policy review, test config | NOT RUN |
| S02 | No production credentials in test runner | Secret scopes and workload identity review | NOT RUN |
| S03 | Anonymous user cannot list directory | Emulator/staging security rules test | NOT RUN |
| S04 | Inactive user cannot list directory | Role-based SDK test | NOT RUN |
| S05 | Active user can read only approved directory fields | Synthetic fixture diff and policy sign-off | NOT RUN |
| S06 | Hidden/admin profiles absent | Directory reconciliation | NOT RUN |
| S07 | Deleted profile stays absent after delayed trigger | Out-of-order event simulation | NOT RUN |
| S08 | Interrupted backfill rerun converges | Staging before/after snapshots | NOT RUN |
| S09 | Transaction retry does not overstate counts | Controlled retry test and committed counts | NOT RUN |
| S10 | Concurrent profile edit converges | Timeline and final state diff | NOT RUN |
| S11 | Production deployment cannot start from ordinary merge | GitHub environment approvals and trigger audit | NOT RUN |
| S12 | Approved rollback and backup available | Dry-run restore and retention evidence | NOT RUN |

## Evidence requirements
Each test must cite an exact commit SHA, staging project ID, fixture ID, test command, timestamp, expected and observed results, redacted log location and reviewer. Do not log personal information or real user IDs.

## Source-specific caution
The existing `backfill_member_directory.js` initializes `andicarpet-e777e` directly. Do not run it as a staging test without implementation changes that safely enforce the isolated project. This ledger does not authorize production writes.

## Acceptance
A complete ledger and explicit privacy policy sign-off are prerequisites, not substitutes for independent release approval.
