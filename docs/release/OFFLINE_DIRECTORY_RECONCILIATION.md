# Offline member-directory reconciliation

Executable: `tools/independent_release/reconcile_directory.py`.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_reconcile_directory.py' -v
python3 tools/independent_release/reconcile_directory.py synthetic-fixture.json
```

Fixture JSON structure: `{"users":{"u1":{"name":"Synthetic","active":true}},"memberDirectory":{"u1":{"name":"Synthetic","active":true,"role":"member"}}}`.

The implementation mirrors the checked main projection field allowlist, excludes hidden/admin users, and treats inactive non-hidden members as projected with `active: false`. It reports missing, extra and changed synthetic IDs without printing profile fields. Exit 0 = exact match; exit 2 = mismatch; exit 3 = invalid input.

**Safety:** This utility never contacts Firebase and must receive only synthetic data. Do not export real users or member directory records to JSON for this tool. The source projection could change; refresh the comparison logic and evidence before relying on it. Four synthetic tests are included; CI execution evidence is pending.
