# Android APK publication checklist

Status: NOT APPROVED. This is a human release checklist, not an automated publication workflow.

- [ ] Confirm immutable combined source SHA and successful CI tied to it.
- [ ] Confirm applicationId, versionName, versionCode and min/target SDK from APK manifest.
- [ ] Confirm production signer certificate fingerprint and signing lineage.
- [ ] Confirm SHA-256 of exactly the APK served to users.
- [ ] Confirm independent approval of trusted artifact manifest.
- [ ] Confirm HTTPS host allowlist and every redirect destination.
- [ ] Confirm physical device clean install, upgrade, offline reconnect and permission-denial tests.
- [ ] Confirm tested rollback build and prior version preservation.
- [ ] Confirm release notes and support contact.
- [ ] Confirm distribution link revocation and incident response owner.

## Final record
`source_sha | artifact_sha256 | signing_cert_sha256 | versionCode | URL | device_evidence | approver | approval_time`

If any field is absent, hold publication. Never publish a debug-signed APK as a production release.
