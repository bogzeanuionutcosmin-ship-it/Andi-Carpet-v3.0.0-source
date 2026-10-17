# Firebase recovery drill — staging only

Status: NOT RUN. This is not permission to export or restore production data.

## Preconditions
Dedicated Firebase staging project, synthetic dataset, isolated credentials, explicit role approvals and documented recovery objectives. Confirm that the selected project is not `andicarpet-e777e` before every mutating command.

## Rehearsal sequence
1. Capture synthetic staging fixture manifest, rules hash, function revision and redacted Firestore snapshot metadata.
2. Produce a staging backup through an approved mechanism and verify its checksum/retention.
3. Introduce controlled synthetic directory corruption in staging only.
4. Restore to a clean staging namespace and verify expected document counts and role restrictions.
5. Replay delayed member-directory triggers and confirm hidden/admin profiles are not republished.
6. Re-run synthetic reconciliation and finance authorization matrix; compare expected versus observed.
7. Record elapsed recovery time, data consistency and any manual intervention.

## Fail-closed conditions
Wrong project ID, missing backup integrity, unreviewed credentials, live personal data, unknown IAM permissions, or any command that could target production.

## Evidence template
`test_id | staging_project | candidate_sha | backup_id | restore_id | elapsed | expected | actual | redacted_logs | reviewer`

No production Firebase actions or backups are performed in this documentation PR.
