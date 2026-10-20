# Static release guard adversarial test cases

Status: SPECIFICATION ONLY; not executed in GitHub CI.

The narrow `tools/independent_release/release_guard.py` script uses regular expressions, not a YAML/Gradle parser. These cases document blind spots and required test improvements without modifying Luna's code.

| ID | Fixture | Required outcome |
|---|---|---|
| G01 | `on: push` workflow with `firebase deploy` | BLOCK |
| G02 | `on: workflow_dispatch` workflow with deploy command | REVIEW, not PASS |
| G03 | `on: repository_dispatch` workflow with deploy command | BLOCK |
| G04 | Missing workflow file | UNKNOWN |
| G05 | `release` signing set to debug | BLOCK |
| G06 | Signing assigned through indirect variable | REVIEW/UNKNOWN, not false PASS |
| G07 | Backfill hardcodes production project | BLOCK |
| G08 | Backfill reads project ID from environment | REVIEW until fail-closed validation inspected |
| G09 | YAML comments contain `push:` | Must not count as active trigger |
| G10 | Alternate workflow invokes reusable production deploy | Must be detected by broader repository workflow inventory |

## Test harness expectations
Create temporary fixtures, call `inspect(root)` and assert finding IDs/statuses. Do not run `firebase`, `gcloud`, `gradle` or GitHub workflows. Run against an isolated checkout and retain command output before claiming tests passed.

## Known limitations
The checker is advisory. Exit code 2 denotes matched blockers and exit code 3 denotes uncertified results. No exit code authorizes production release.
