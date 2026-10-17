# Modularization dependency inventory

Run read-only on a checked-out candidate:
```sh
python3 -m unittest discover -s tools/independent_release -p 'test_modularization_inventory.py' -v
python3 tools/independent_release/modularization_inventory.py lib > local-module-graph.json
```

Reports Dart file count, direct cross-domain import/export edges, and unresolved local Dart paths. No refactoring, network calls, deployment, or Firebase access. This is a **planning aid**, not a complete Dart analyzer: it does not resolve conditional imports, dynamic calls, generated code, or semantic dependency cycles. All results set `modularization_complete: false` until actual extraction and regression validation.

Use its edges to select small, reversible extractions after the combined Grafic/Centralizator/finance candidate has been validated.
