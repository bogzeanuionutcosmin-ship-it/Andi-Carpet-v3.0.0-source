# Android distribution acceptance contract

Independent documentation only. No keystore, secret, Firebase project or APK is modified.

## Required build metadata
- Release applicationId, versionCode, versionName and min/target SDK extracted from final APK, not inferred only from Gradle source.
- APK SHA-256 and byte size; canonical immutable artifact URI.
- Android signing certificate SHA-256 fingerprint, verified with apksigner (including all applicable schemes); signing key must not be the default debug key.
- Build provenance: exact source SHA, CI run ID, build job, toolchain versions, and approver.
- Upgrade compatibility: previous production signing lineage and applicationId must match supported Android upgrade rules. A new unrelated certificate can prevent in-place updates.
- Key custody: use protected release secrets or an approved signing service; never commit private keys or expose signing credentials in artifacts/logs.

## Distribution controls
- Publish only to a documented approved HTTPS host with a stable ownership policy. A syntactically valid HTTPS URL is not proof of trusted publisher.
- Publish a signed release manifest or equivalent independently authenticated digest + certificate fingerprint; compare the downloaded APK against it before release.
- Prevent accidental downgrade and rollback to insecure releases; document emergency rollback compatibility.
- Verify redirect chain and final download origin, MIME type and checksum. A redirect to another host needs explicit approval.
- Maintain an expiry/revocation procedure for compromised links and certificates.

## Device acceptance matrix
1. Clean install on a representative supported Android version.
2. In-place update from the currently installed production version with preserved app data and authenticated session behavior checked.
3. Denied/granted location, background location, camera, notification and SMS permissions; app must degrade safely and ask for consent when relevant.
4. Offline launch, delayed reconnect, repeated START/FINAL submission and duplicate prevention.
5. Centralizator export to PDF with Romanian diacritics and long history.
6. Failed download, invalid checksum, wrong signing certificate and lower versionCode must be blocked or surfaced safely.

## Current source observations
- #100 SHA cfb00b9: android/app/build.gradle.kts configures release with debug signing. This is a release blocker, not a request to alter Luna's branch.
- #95 SHA 3c372cc: lib/ui/install_app_buttons.dart checks HTTPS, credentials and obvious local hosts; it does not cryptographically attest APK identity.
- #100 SHA cfb00b9: AndroidManifest declares sensitive permissions requiring product-specific rationale and device validation.
- #101 SHA 98c40ae: synthetic Android runtime CI is not an authenticated production-like device test.

No claim that this contract is implemented. Acceptance requires artifacts and execution evidence, not a green static checklist.
