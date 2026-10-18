# Integration evidence provenance contract

This is a specification, not a claim that integration has been executed.

## Candidate identity
A release candidate must be identified by the **exact combined Git tree SHA**, not a collection of PR labels. Capture main base SHA, each included PR head SHA, merge order, resolved conflicts and final commit/tree SHA. Recompute if any branch changes.

## Evidence per check
| Check | Minimum record |
|---|---|
| Flutter analysis | SDK version, command, combined SHA, complete log and exit code |
| Flutter unit/widget tests | Exact test list, command, combined SHA, results and failures |
| Firebase rules | Emulator version, rules hash, synthetic role fixtures and denied-write evidence |
| Schedule and Centralizator | Real staging persistence, replay/concurrency trace and reconciliation |
| PDF | Source fixture hash, page count, screenshots and clipped-content checks |
| Android | APK SHA-256, signer fingerprint, package metadata and physical device results |
| Production workflow | Main trigger source, environment protection evidence and approved transition plan |

## Freshness policy
An artifact is stale if its build tree differs from the proposed release tree, its external environment materially changes, or a relevant test implementation changes. A green CI badge without an attributable tree SHA is not release evidence.

## Current known constraints
#95, #99, #100 and #101 are independent Draft workstreams as last checked. Do not assume their union compiles or passes. Main's member-directory restore workflow remains a deployment hazard until verified mitigations are merged and protected.

No GitHub workflow, application code or production service was modified by this document.
