# Android release evidence manifest — template

**Status:** NOT VERIFIED. Do not fill PASS from a build job name alone.

| Field | Recorded value | Verification source |
|---|---|---|
| Combined integration commit/tree | NOT RECORDED | Git checkout and tree hash |
| Flutter / Dart / JDK / Android build tools | NOT RECORDED | Build job output |
| APK filename / size / SHA-256 | NOT RECORDED | Immutable artifact and `sha256sum` |
| Package ID / versionName / versionCode | NOT RECORDED | `aapt dump badging` |
| APK signing certificate SHA-256 | NOT RECORDED | `apksigner verify --print-certs` |
| Prior installed version signing certificate | NOT RECORDED | Approved existing installation |
| HTTPS URL / final redirect destination | NOT RECORDED | Controlled distribution test |
| Authorized publisher / reviewer | NOT RECORDED | Release approval record |
| Device install / upgrade / rollback | NOT RUN | Redacted physical-device logs |
| Staging Firebase project | NOT RECORDED | Non-production build config |

## Artifact integrity and trust chain
1. Build from the exact reviewed integration SHA with pinned dependencies.
2. Sign with the approved release certificate, not debug. Keep signing private key out of repository and logs.
3. Generate and retain immutable APK digest and signing certificate fingerprint.
4. Have an independent approver compare those values with a trusted release manifest, not the download page itself.
5. Check redirect destination and certificate chain before distributing a link.
6. Preserve the prior approved APK and tested rollback procedure. Android package downgrade may be disallowed, so rollback can require a newly versioned build.

## Stop conditions
Unknown signer, changed package ID, unexplained certificate rotation, mismatched digest, untrusted final URL, failed upgrade, or missing device evidence. All are BLOCKED pending resolution.

No actual APK has been inspected in this documentation PR.
