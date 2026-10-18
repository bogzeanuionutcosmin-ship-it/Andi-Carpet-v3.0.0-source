# Integration evidence gate (offline)

Executable: `tools/independent_release/integration_gate.py`. This checks whether a human-entered evidence checklist is structurally complete. It **does not validate the underlying evidence**, fetch GitHub results, approve release, merge, deploy, or touch Firebase.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_integration_gate.py' -v
python3 tools/independent_release/integration_gate.py local-evidence.json
```

Example input (replace values only after independently verifying the evidence):
```json
{
  "candidate_tree_sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "firebase_emulator_pass": false,
  "android_device_pass": false,
  "release_signing_verified": false,
  "production_workflow_hold_verified": false,
  "privacy_owner_approval": false,
  "combined_ci_pass": false
}
```

Exit 2 = BLOCK; exit 3 = all fields true but HUMAN_REVIEW_REQUIRED. There is deliberately **no success/approval exit code**. Do not set a field true on the strength of a plan, an individual PR test, or a generated document. Six synthetic tests included; GitHub CI results must be checked independently.
