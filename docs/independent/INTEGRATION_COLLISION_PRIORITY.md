# Integration collision priority — captured 18 October 2026

Evidence: `docs/independent/pr_collision_snapshot_20261018.json` generated from GitHub changed-file listings for Draft PRs #95, #99, #100, #101, #103, #104, #105. Each record includes the head SHA at capture time. **The #103 SHA is a snapshot value, not the current head after this documentation commit.** Refresh all SHA values before actual integration.

| Pair | Exact shared files | Priority |
|---|---:|---|
| #99 / #100 | **25** | P0 integration: overlapping schedule, centralizer, PDF, Firestore, UI, tests, CI |
| #99 / #101 | 2 | P0 security: `firestore.rules` and `validate.yml` |
| #100 / #101 | 2 | P0 security: `firestore.rules` and `validate.yml` |
| #95 / #99 | 1 | P1 test hygiene |
| #95 / #100 | 1 | P1 test hygiene |

No exact-path overlaps were observed between #103, #104, #105 or with these implementation PRs at capture time. **Absence of exact file collisions does not imply semantic compatibility.**

## Recommended integration procedure
1. Choose one authoritative base candidate and record its tree SHA. Do not merge Draft PRs automatically.
2. Compare #99 and #100 patch-by-patch, especially `firestore.rules`, `lib/centralizer/centralizer_page.dart`, `lib/reports/pdf_reports.dart`, and `lib/schedule/program_page.dart`. Preserve both sets of intended behavior in a new reviewed integration branch.
3. Reconcile #101 financial security rules with that candidate; run Firebase rules emulator tests for both directory/finance and schedule/centralizer permissions.
4. Include #95 Android link and hygiene changes, then run all affected tests.
5. Recompute candidate tree SHA and rebuild staging artifacts. Prior individual-PR CI passes do not certify the combined candidate.
6. Require independent security/privacy and release-signing review before any production action.

## Tooling
```sh
python3 tools/independent_release/pr_collision_guard.py docs/independent/pr_collision_snapshot_20261018.json
```
Expected result for this recorded snapshot: exit code 2 and five overlap pairs. The script does not contact GitHub or approve integration.
