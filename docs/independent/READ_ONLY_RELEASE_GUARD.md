# Read-only release guard — executable independent lane

Files: `tools/independent_release/release_guard.py` and `test_release_guard.py`.

## Invocation

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_*.py' -v
python3 tools/independent_release/release_guard.py --root . --json
```

The second command exits with code **2** if any known blocker is detected, or **3** if no blocker matches but release safety remains unverified. Neither exit code authorizes release. It does not invoke Firebase, GitHub Actions, subprocesses, network APIs, or mutate files. It reads three local source paths only: production member-directory workflow, Android Gradle build and member-directory backfill.

## Three static hazards checked
1. Production-capable member-directory workflow with an automatic event trigger.
2. Explicit `debug` signing configuration within Android release build.
3. Hardcoded production project in member-directory backfill initialization.

## Validation performed
Four synthetic Python unit tests are defined, but no verified execution output was available during this review: automatic deploy detection, manual dispatch classification, missing files fail-unknown, and commented trigger exclusion. The script was **not** executed on a complete repository checkout, and it is **not** a YAML parser or exhaustive security scanner.

## Interpretation
- `BLOCK`: matching known unsafe static pattern; stop release.
- `REVIEW`: no matching static blocker but runtime/security assurance still required.
- `UNKNOWN`: missing source; do not treat as safe.
- `PASS`: only the narrow inspected pattern is absent, not a release approval.

Limitations: regex-based inspection can miss alternate workflow syntax, indirect deploy commands, alternative signing assignments or renamed scripts. All other workflows and project credentials remain outside its scope. No exit code from this narrow scanner constitutes production approval.

This implementation deliberately lives in an isolated `tools/independent_release/` namespace, outside Luna's Grafic, finance, PDF, rules and CI paths.
