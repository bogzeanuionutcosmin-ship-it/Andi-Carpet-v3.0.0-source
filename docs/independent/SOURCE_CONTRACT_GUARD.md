# Read-only source contract guard

Executable: `tools/independent_release/source_contract_guard.py`. It checks four known high-risk patterns in the local checkout without executing application code or accessing production.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_source_contract_guard.py' -v
python3 tools/independent_release/source_contract_guard.py .
```

Patterns: main-push production deploy, release signing with debug key, backfill hardcoded to `andicarpet-e777e`, and transaction callback counters that can overcount on retries.

**Known main source references (18 October 2026):**
- `.github/workflows/restore-member-directory.yml` blob `0d8db4bf5c1e2c4e4fb3374b1aaf6312082dc404`.
- `android/app/build.gradle.kts` blob `d614d1247d01192efd9e7c754f549ebb479efb6a`.
- `functions/backfill_member_directory.js` blob `488d745f3b05b573d6bf246eae778391bdc5ab8b`.

Exit 2 indicates a matched blocker; exit 3 indicates no matched blocker but still uncertified. The regex checker is not a parser and does not authorize deployment. The backfill counter finding is a reporting-accuracy concern, not proof of duplicate writes. Four synthetic tests included.
