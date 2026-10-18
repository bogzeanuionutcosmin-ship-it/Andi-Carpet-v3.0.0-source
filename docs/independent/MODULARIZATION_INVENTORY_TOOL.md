# Modularization dependency inventory

Run read-only on a checked-out candidate:
```sh
python3 -m unittest discover -s tools/independent_release -p 'test_modularization_inventory.py' -v
python3 tools/independent_release/modularization_inventory.py lib > local-module-graph.json
```

Reports Dart file count, direct cross-domain import/export edges, and unresolved local Dart paths. No refactoring, network calls, deployment, or Firebase access. This is a **planning aid**, not a complete Dart analyzer: it does not resolve conditional imports, dynamic calls, generated code, or semantic dependency cycles. All results set `modularization_complete: false` until actual extraction and regression validation.

Use its edges to select small, reversible extractions after the combined Grafic/Centralizator/finance candidate has been validated.

## CI evidence and safe interpretation

The independent release guard workflow generates `independent-module-inventory.json` from the actual checked-out `lib/` tree and uploads it as a GitHub Actions artifact retained for 14 days. The artifact is tied to that workflow run and commit; do not treat it as a snapshot of later commits.

The JSON also lists `part_links`, `orphan_parts`, `invalid_part_owners`, `inbound_dependencies`, and `migration_candidates`. A `main_part_requires_dependency_review` candidate is **not** safe for automatic extraction. Check imports, private identifiers, library-scoped declarations, and `part of` ownership before any move. `inbound_dependencies` covers explicit import/export directives, not references through shared Dart libraries or runtime calls.

Before approving an extraction, compare its base commit to the current integration candidate, run Flutter analysis/tests and the full combined Firebase emulator suite, and keep a reversible PR. The tool never authorizes release or production changes.

## Conflicting Dart part ownership

The read-only inventory reports `multiple_part_owners` when two or more Dart libraries declare the same existing `part` file. This is an extraction blocker requiring manual review; the report does not modify sources or certify modularization. Synthetic tests cover both conflicting and valid ownership.

## Local Dart import/export cycles

The read-only inventory includes `local_import_cycles`, listing strongly connected groups of local Dart files linked through import/export statements (including direct self-imports). Cycles require review before extracting modules; this structural signal is not a compiler verdict. External packages, conditional import branches and implicit `part` scope are not exhaustively modeled. Synthetic regression tests cover two-file cycles, transitive cycles, self-imports and acyclic graphs.

## Legacy named `part of` declarations

The inventory lists `named_part_of` declarations such as `part of legacy.core;` for explicit manual review. Named library ownership is checked against a static `library name;` declaration in the referencing owner file. Missing or mismatched names are flagged in `invalid_part_owners`; matching names are not flagged. This is a heuristic, not full Dart parsing or permission to extract automatically. Regression tests cover matching, mismatching and URI declarations.
