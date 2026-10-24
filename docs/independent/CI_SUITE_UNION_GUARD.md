# Firestore CI suite union guard

This offline tool checks that a proposed integration workflow names all four current Firestore test suites in one emulator command: diurna, program schedule, centralizer correction, finance identity.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_verify_ci_suite_union.py' -v
python3 tools/independent_release/verify_ci_suite_union.py .github/workflows/validate.yml
```

Exit 2 means missing combined suite; exit 3 means names are present but **not certified**. This is intentionally fail-closed: no exit code authorizes deployment. The checker is a static heuristic, not a YAML interpreter, and must be complemented by an actual emulator run and review of the workflow's trigger/permissions/project configuration.

The check is relevant because #99/#100 and #101 modify the same `validate.yml` command with different suite sets. Run it against the combined integration candidate, not the original main workflow. Five synthetic tests are included.
