# Android release provenance acceptance — independent track

Review date: 2026-10-18. Documentation only. This does not change APK builds, keystores, app code, CI, or production data.

## Current evidence
- `main:android/app/build.gradle.kts`: `buildTypes.release.signingConfig = signingConfigs.getByName("debug")`. This does not provide a trusted independently controlled production signing identity.
- `main:pubspec.yaml`: `version: 3.0.1+33`. Treat this as source metadata, not proof of final APK manifest values.
- `main:lib/main.dart`: in-app version label is also `3.0.1+33`; the older `RELEASE_3.0.0_FINAL.md` describes historical build `3.0.0+32` and must not be used as current-candidate evidence.
- #95 at `3c372cc839614125b9f375e5ff20b818aa1e18ed` adds HTTPS/public-host validation for Android APK links. It does not verify downloaded artifact SHA-256, certificate fingerprint, or redirect chain.
- #101 at `98c40ae394941ddfc185f028fc04ad6809d6de3b` contains a synthetic emulator APK test, not physical authenticated production-like application acceptance.

## Required immutable release record
For every candidate capture:
1. Git commit and combined integration tree SHA, builder ID, job URL, Flutter/Dart/Java/Android SDK versions.
2. APK filename, byte length, SHA-256, versionCode, versionName, applicationId, minSdk, targetSdk.
3. Verified signing certificate SHA-256, signature scheme results, comparison with previously installed production version and key custody approver.
4. Canonical approved HTTPS distribution URL, full redirect chain and final host, server-side checksum/manifest authentication, rollback and revocation plan.
5. Physical device model/Android version, clean install and upgrade results, user consent and permission behavior.

## Verification command contract
Run only on isolated candidate APK and approved machine; no production deploy:
```sh
sha256sum candidate.apk
apksigner verify --verbose --print-certs candidate.apk
aapt dump badging candidate.apk
```
Do not copy APK or certificate private keys into public logs. Hashes and public certificate fingerprints are not secrets, but must be checked against an independently approved source.

## Fail closed
No release distribution while debug signing is configured, signing lineage is unknown, APK integrity is unverified, or a physical upgrade test is missing. A valid HTTPS URL does not prove a valid APK.

## Non-overlap
Luna owns schedule, PDF, finance identity, integration CI and existing link validation. This PR documents only release acceptance; no implementation overlaps.
