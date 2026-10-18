# Independent release-readiness lane (2026-10-18)

Scope: documentation, release gates, evidence inventory and reproducible *read-only* verification. This branch must never modify source, Firebase rules, workflows, dependencies, secrets, production data or Luna's PRs.

## Ownership and non-overlap
- Luna owns Grafic / schedule persistence, Centralizator, PDF, finance identity, CI integration, and their associated tests and remediation. Do not reimplement or cherry-pick those areas.
- This independent lane owns the cross-PR release acceptance checklist, Android distribution trust requirements, provenance matrix, and evidence requirements.
- Treat #95, #99, #100, #101 as independently moving Draft PRs. Never assume their commits are merged or production-ready.
- Do not deploy, merge, distribute APKs, run production migrations, or invoke destructive operations.
- Future updates to this lane must first compare changed filenames and documentation in open PRs; no duplicate tests or files.

## Current decision
Prefer **evidence-first isolated integration** before expanding feature scope. The highest release blockers are trusted Android signing/distribution and realistic end-to-end authorization/data validation. Passing synthetic tests or an offline harness is not equivalent to real device + real Firebase staging verification.

## Evidence levels
1. Static source inspection (not runtime proof).
2. Unit/emulator or synthetic CI (controlled fixtures).
3. Isolated staging backend + real application APK, real SDK and adversarial scenarios.
4. Physical device / installation, upgrade, offline/reconnect, PDF export, and rollback rehearsal.
5. Approved release and monitored rollout (requires separate explicit release decision).

## Update protocol
Record each claim with exact PR/SHA, file or CI run, timestamp, method, expected/actual result and limitation. Mark unknown as UNKNOWN, not PASS. A newer PR SHA invalidates previous SHA-scoped evidence until rerun. Keep this lane documentation-only.
