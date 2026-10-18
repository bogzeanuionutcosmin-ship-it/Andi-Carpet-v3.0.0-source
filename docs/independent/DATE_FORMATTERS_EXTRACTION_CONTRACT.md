# Date formatter extraction — compatibility contract

Scope: PR #106, isolated from Luna's Android, schedule, centralizer and finance changes.

The six pure helpers `two`, `formatDate`, `formatMonth`, `timeText`, `durationText`, and `sameDay` now live in `lib/utils/date_formatters.dart`. The app's `lib/main.dart` **imports and exports** that library, preserving calls from existing code that imports `main.dart`.

The `lib/utils/operational_dates.dart` file remains a `part of '../main.dart'` because `recordBelongsToWorkDate` and `recordEventTime` depend on `CentralizerRecord`, and moving them independently requires a separate dependency review. No Firestore, permissions, GPS, per-diem or runtime work-window behavior is changed by this extraction.

## Validation and release constraints

- `test/date_formatters_test.dart`: Romanian weekday/month names, null and negative duration formatting, time boundaries, leap-day and calendar-date comparisons.
- `test/widget_test.dart`: existing public `formatDate` access through `package:andi_carpeta/main.dart`.
- `test/repository_hygiene_test.py`: one definition per helper, correct main import/export, and retention of operational functions in the original part.
- Require green Flutter/Firebase CI on the final SHA, code review, and conflict assessment before any merge.
- Draft only; no production deploy or `production_ready=true` claim.
