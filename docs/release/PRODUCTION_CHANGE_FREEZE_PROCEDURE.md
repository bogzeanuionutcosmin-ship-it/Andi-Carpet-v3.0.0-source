# Production deployment change freeze and transition procedure

**Status:** PROPOSED; no freeze, environment protection, deployment or backfill was performed.

## Source-backed hazard
Main's `.github/workflows/restore-member-directory.yml` listens to pushes on main for its own workflow file, `firestore.rules`, `functions/index.js`, the projection and backfill scripts. It authenticates to `andicarpet-e777e`, deploys Firestore rules and the sync function, then runs member-directory backfill. A documentation PR does not neutralize this behavior.

## Pre-merge hold
1. Authorized repo administrator verifies GitHub `firebase-production` environment protection, required reviewers, deployment branch restrictions and service-account IAM.
2. Put a documented environment-level hold in place before merging any change to the triggering paths. The old workflow definition may execute for the transition push.
3. Capture current rules, function revision, workflow definition and approved backups; document rollback owner.
4. Review #101's proposed manual workflow dispatch and SHA/confirmation requirements against the actual merged candidate.
5. Verify no other production-capable workflows, schedules or external deploy triggers bypass the hold.

## Transition rehearsal
Use a disposable staging repository/project with equivalent workflow semantics. Verify that a workflow-file push does not reach production credentials, and that unauthorized dispatch, wrong SHA and missing confirmation all fail closed. Capture run URLs and reviewer sign-off.

## Post-merge verification
Confirm current main workflow trigger, environment gates and service-account scope, and ensure no unintended backfill was run. Lift any hold only with explicit release authority. A new manual workflow is not proof that an old push-triggered run cannot start.

## Stop conditions
Unknown environment configuration, no reliable hold, missing backup, unclear ownership, unexpected production job or unreviewed IAM permissions.

This document is not authorization to disable production workflows or alter live IAM.
