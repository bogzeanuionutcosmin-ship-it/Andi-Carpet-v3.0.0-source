# Modularization execution plan — after independent gates, prepared in parallel

Status: architecture preparation only. Do not modify Luna's active implementation PRs (#99/#100/#101), merge Draft PRs, or deploy production without an integration owner.

## Proposed bounded modules

| Module | Current surface | Proposed boundary | First characterization tests |
|---|---|---|---|
| Schedule/Grafic | `lib/schedule/program_page.dart`, `schedule_card_full.dart` | domain schedule models, Firestore repository, editor/controller, UI | ordering, closed schedules, stale writes, batch atomicity |
| Centralizator | `lib/centralizer/centralizer_page.dart`, `correction_snapshot.dart` | execution domain, correction service, read models, UI | correction without duplication, team permissions, operational day |
| PDF reporting | `lib/reports/pdf_reports.dart`, `pdf_format_helpers.dart` | immutable report DTOs, renderer, platform delivery | layout snapshot, diacritics, cross-midnight totals |
| Finance | `lib/models/app_data_models.dart`, finance UI/Firestore paths | identity/authorization model, repository, view model | manager assignment, team isolation, legacy data |
| Member directory | `functions/member_directory_projection.js`, `functions/index.js` | pure projection, sync adapter, migration/backfill CLI | hidden/admin filtering, allowlist, idempotent reconciliation |
| Release/Android | `android/app/build.gradle.kts`, CI workflows | signing/provenance validation, publishing separate from build | signed identity, artifact digest, upgrade and rollback |

## Implementation sequence
1. Capture baseline behavior and test fixtures at an immutable **combined candidate SHA**, after reconciling PR #99/#100/#101.
2. Extract pure models and transformations first, preserving serialized Firestore document shapes and callable UI contracts.
3. Introduce repository interfaces/adapters without switching Firebase projects, production data, or permissions.
4. Move controllers/services in small independently testable slices. Keep user-visible routes and navigation stable.
5. Extract widgets and rendering last; add regression tests and verify APK on devices before claiming equivalence.
6. Rebuild Android/web, run Flutter tests and all four Firebase emulator suites after **each** extraction, not just at the end.

## Parallelizable preparation
- Characterization test inventory and Firestore schema mapping can proceed now.
- Release/CI guard tooling can proceed independently.
- Pure PDF format helpers and directory projection boundaries can be designed, but extraction against Luna's moving implementation is deferred to an agreed candidate branch.

## Non-negotiable
No mass file move without a green baseline; no silent data migration; no release-signing substitution; no production deploy or backfill. Modularization is not itself evidence of production readiness.
