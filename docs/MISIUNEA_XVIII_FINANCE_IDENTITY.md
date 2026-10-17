# Misiunea XVIII — narrow finance identity protection

Base main: 377f1fd5e73ae78a0df5cab58b09770c873cd167. Separate recovery branch; #15, #83, #85, #88 and #100 untouched.

## Reproduction

The #15 authorization fixture run against current main-derived #100 rules passed 18/19; it demonstrated that a manager could replace managerId. Eight focused new SDK/emulator tests on untouched main reproduced five failures: manager reassignment, another member reassigning, member self-assignment during create, adding authority to a legacy record and changing team identity.

## Minimal fix

Keep Admin's existing assignment authority and the existing team-member amount-update policy. Non-admin creation cannot assign a nonempty managerId. Non-admin updates must preserve managerId and team identity; missing legacy identity fields normalize without a migration. A rejected combined reassignment/amount update changes neither field.

This recovers the narrow identity-protection intent from blocked #15 without importing its broad financial changes or merge conflicts. It does NOT claim that the legacy monetary policy, idempotent financial operations, backup/restore, trusted session issuance, hardware anti-rollback or all financial release gates are resolved.

## Evidence before PR

- Main RED: new focused suite 3 passed / 5 failed.
- Patched GREEN: existing diurna suite + 8 new identity cases = 18/18, real SDK + Firestore Emulator, synthetic demo project only.
- Python source suite 107/107; diff-check clean.
- CI must run on final SHA. No deploy, live rules change, production data, merge or APK distribution.

## Release hardening

The historical restore-member-directory workflow automatically deployed rules/functions and backfilled production on relevant main pushes. This would couple a future rules merge to a production action. Its operations are retained but the trigger becomes manual-only, restricted to main, with DEPLOY_MEMBER_DIRECTORY confirmation and the exact approved SHA matching github.sha. No dispatch is performed. A source regression protects the trigger and gates. Other release workflows remain unchanged; no live settings or environment permissions are modified.
