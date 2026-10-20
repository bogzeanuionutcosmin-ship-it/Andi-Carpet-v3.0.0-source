# Member directory privacy decision register

Status: AWAITING PRODUCT/PRIVACY APPROVAL.

## Observed projection behavior
Current `main:functions/member_directory_projection.js` omits admin and hidden profiles, projects non-hidden inactive members with `active: false`, and includes optional `phone`, `photoBase64`, `city`, `county`, and `contractFunction`. Current Firestore rules allow active accounts to list the directory. This is source-derived behavior, not a claim of policy violation.

## Questions requiring explicit decisions
| Field / behavior | Decision needed | Current status |
|---|---|---|
| Phone number | Should every active member see it? Is consent/role filtering needed? | UNDECIDED |
| Profile photo | Is full base64 image distribution necessary? | UNDECIDED |
| City/county | Is this appropriate for all active members? | UNDECIDED |
| Contract function | Is employment-related detail approved for directory exposure? | UNDECIDED |
| Inactive member listing | Should inactive members remain visible to active users? | UNDECIDED |
| Hidden/admin | Verify all historical entries are removed and cannot be republished | NOT TESTED |
| Data retention | Define removal timing and audit requirements | UNDECIDED |

## Required evidence
Document product owner decision, privacy reviewer, effective date, scope of affected roles, synthetic staging verification and any migration impact. No assumption of consent or legal compliance may be inferred from the implementation.

Do not modify rules or backfill production data to answer these questions.
