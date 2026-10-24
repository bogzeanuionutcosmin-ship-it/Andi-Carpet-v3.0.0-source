# Android upgrade and rollback rehearsal

Status: PROCEDURE ONLY. No APK installed or signed here.

## Preconditions
Use isolated staging, synthetic data and a physical test device. Record old and new versionCode, package ID, signer SHA-256, APK SHA-256 and device Android version. Obtain the prior approved APK from a trusted artifact archive.
Both rehearsal builds must use the same staging application ID and test signer.
The `.staging` package installs alongside production and cannot establish a
production upgrade or production signing lineage.

## Upgrade rehearsal
1. Verify both APK signatures and hashes independently.
2. Install the prior approved build, create synthetic local app state, authenticate only to staging.
3. Upgrade without uninstalling; confirm application ID and signing continuity.
4. Validate schedule history, START/FINAL, Centralizator, PDF, background permission prompts and offline replay.
5. Inspect crash logs and confirm no production endpoints were contacted.
6. Repeat with a pending official STOP intent: preserve app data and secure
   storage, reconnect after upgrade and verify the original request/receipt and
   authoritative graph state. Record a failed journal read as a blocker; do not
   clear it to make the test pass.

## Failure/rollback rehearsal
1. Simulate a failed candidate launch and capture redacted logs.
2. Prefer a fixed, higher-versionCode APK signed with the same approved lineage. Android ordinarily rejects lower-versionCode downgrades.
3. Do not tell users to uninstall without an approved data preservation and migration plan.
4. Verify local data recovery, re-authentication behavior and staging consistency.
5. Document communication, distribution link revocation and decision authority.

## Blockers
Debug signing, mismatched certificate, unknown package identity, unverified APK digest, missing physical-device evidence, or a rollback procedure that destroys data.

This runbook changes no Android build or production signing configuration.
