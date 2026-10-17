# Release gates — independent acceptance contract

Status as of 2026-10-18: NOT RELEASE-READY. This is a checklist, not a claim that tests ran.

| Gate | Required proof | Present evidence / gap |
|---|---|---|
| Source integration | Exact SHAs of #95/#99/#100/#101 combined in isolated checkout; zero unresolved conflicts; relevant tests rerun | Historical synthetic integration CI; must refresh after any head changes |
| Schedule to PDF | Real app writes START/FINAL to staging Firestore; Centralizator reads them and exports accurate PDF, including overnight, deleted legacy IDs and offline replay | Unit/emulator/synthetic PDF evidence; physical end-to-end UNKNOWN |
| Finance authorization | Emulator and staging rejection of cross-user monetary tampering; identity, audit, idempotency and rollback assertions | #101 narrowly protects manager/team identity, does not claim monetary policy fixed |
| Data recovery | Restore on isolated staging copy with audit, identity preservation and rollback; never test destructive restore on production | UNKNOWN |
| Android signing | Production-controlled private signing key, validated signing lineage and fingerprint; no debug signing for release | android/app/build.gradle.kts at #100/#101 selects signingConfigs.getByName("debug") for release — BLOCKED |
| APK distribution | Approved HTTPS origin + immutable versioned APK checksum/signing fingerprint and anti-rollback policy | #95 validates URL shape but not publisher identity or APK cryptographic provenance — BLOCKED |
| Android device | Install/update/upgrade/uninstall/reinstall on representative Android devices; notifications, permissions, background location and SMS consent | Synthetic emulator only; physical device UNKNOWN |
| Production safety | Explicit manual approvals, protected environments, rollback and monitoring; no implicit Firebase deploy on merge | #101 gates restore-member-directory workflow, but other workflows need independent inventory |

## Fail-closed policy
Any BLOCKED or UNKNOWN release-critical gate prevents marking the release production-ready. Never convert an UNKNOWN into a PASS based on source inspection or a green unrelated workflow.

## Evidence record template
- Gate / exact commit SHA / date and environment
- Test command or procedure
- Expected outcome; observed outcome; logs/artifact URL
- Scope and exclusions (staging vs production, emulator vs physical)
- Reviewer and decision; rollback instructions
