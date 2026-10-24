#!/usr/bin/env python3
"""Offline candidate evidence gate. Never deploys or grants release approval."""
import argparse
import json
import re
from pathlib import Path

REQUIRED = ("candidate_tree_sha", "firebase_emulator_pass", "android_device_pass",
            "release_signing_verified", "production_workflow_hold_verified",
            "privacy_owner_approval", "combined_ci_pass")


def evaluate(record):
    if not isinstance(record, dict):
        raise ValueError("Evidence record must be a JSON object")
    sha = record.get("candidate_tree_sha")
    if not isinstance(sha, str) or re.fullmatch(r"[0-9a-fA-F]{40}", sha) is None:
        raise ValueError("candidate_tree_sha must be a 40-digit Git SHA")
    missing = [key for key in REQUIRED[1:] if key not in record]
    invalid = [key for key in REQUIRED[1:] if key in record and type(record[key]) is not bool]
    failed = [key for key in REQUIRED[1:] if record.get(key) is False]
    return {"candidate_tree_sha": sha.lower(), "missing": missing, "invalid": invalid,
            "failed": failed, "evidence_complete": not (missing or invalid or failed),
            "release_approved": False,
            "status": "BLOCK" if missing or invalid or failed else "HUMAN_REVIEW_REQUIRED"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args()
    try:
        result = evaluate(json.loads(args.record.read_text(encoding="utf-8")))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "BLOCK", "release_approved": False, "error": str(exc)}))
        return 2
    print(json.dumps(result, indent=2))
    return 2 if result["status"] == "BLOCK" else 3


if __name__ == "__main__":
    raise SystemExit(main())
