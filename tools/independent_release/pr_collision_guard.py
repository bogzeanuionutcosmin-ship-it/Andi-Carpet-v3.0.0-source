#!/usr/bin/env python3
"""Offline PR file-overlap analysis from a locally supplied JSON snapshot."""
import argparse
import json
from itertools import combinations
from pathlib import Path


def analyze(snapshot):
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get("prs"), list):
        raise ValueError("Expected object with prs list")
    prs = snapshot["prs"]
    seen = set()
    normalized = []
    for item in prs:
        if not isinstance(item, dict):
            raise ValueError("Each PR must be an object")
        number, sha, files = item.get("number"), item.get("head_sha"), item.get("files")
        if (not isinstance(number, int) or isinstance(number, bool) or number < 1
                or number in seen or not isinstance(sha, str) or len(sha) != 40
                or any(c not in "0123456789abcdefABCDEF" for c in sha)
                or not isinstance(files, list) or any(not isinstance(f, str) or not f for f in files)):
            raise ValueError("Invalid PR number, SHA, or files")
        seen.add(number)
        normalized.append((number, sha.lower(), set(files)))
    overlaps = []
    for (a, sha_a, files_a), (b, sha_b, files_b) in combinations(normalized, 2):
        shared = sorted(files_a & files_b)
        if shared:
            overlaps.append({"prs": [a, b], "heads": [sha_a, sha_b],
                             "shared_files": shared, "shared_count": len(shared)})
    return {"pr_count": len(normalized), "overlap_pairs": overlaps,
            "overlap_count": len(overlaps), "integration_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path, help="JSON with prs: [{number, head_sha, files}]")
    args = parser.parse_args()
    try:
        result = analyze(json.loads(args.snapshot.read_text(encoding="utf-8")))
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc), "integration_approved": False}))
        return 3
    print(json.dumps(result, indent=2))
    return 2 if result["overlap_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
