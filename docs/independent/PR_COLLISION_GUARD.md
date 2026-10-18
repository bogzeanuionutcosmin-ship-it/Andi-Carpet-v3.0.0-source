# PR collision guard — offline integration safety

Executable: `tools/independent_release/pr_collision_guard.py`. This detects exact-path overlaps, **not** semantic conflicts or safe merge order.

```sh
python3 -m unittest discover -s tools/independent_release -p 'test_pr_collision_guard.py' -v
python3 tools/independent_release/pr_collision_guard.py /path/to/pr-snapshot.json
```

Input is a JSON object with `prs` array of `{number, head_sha, files}` records. Each SHA must match the currently reviewed PR head. Exit 2 indicates overlapping files, 0 means no exact-path overlap, 3 means invalid input. All results explicitly set `integration_approved: false`.

## Confirmed snapshot: 18 October 2026
GitHub PR changed-file lists show that #99, #100 and #101 all touch `firestore.rules`. #99 and #100 also share several application and CI paths, including `lib/centralizer/centralizer_page.dart`, `lib/schedule/program_page.dart` and `.github/workflows/validate.yml`. #101 and #100 share `.github/workflows/validate.yml` and `firestore.rules`. These PRs **cannot** be assumed independently merge-safe. Their candidate integration requires deliberate reconciliation and revalidation.

The independent #103, #104 and #105 paths were disjoint at this snapshot. Their workflow filenames and tool files are unique; no merge authorization follows from that fact.

Six synthetic tests are included. GitHub Actions evidence for these tests is pending.
