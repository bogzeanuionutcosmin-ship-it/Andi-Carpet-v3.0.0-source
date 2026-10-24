#!/usr/bin/env python3
"""Read-only source contract checks for high-risk release paths."""
import argparse
import json
import re
from pathlib import Path


def inspect(workflow, gradle, backfill):
    findings = []
    # Heuristics intentionally conservative: these findings require human review.
    if re.search(r"branches:\s*\[\s*main\s*\]", workflow) and "firebase deploy" in workflow:
        findings.append("PRODUCTION_DEPLOY_ON_MAIN_PUSH_REVIEW")
    if re.search(r'signingConfig\s*=\s*signingConfigs\.getByName\(["\']debug["\']\)', gradle):
        findings.append("RELEASE_DEBUG_SIGNING")
    if re.search(r"initializeApp\(\{\s*projectId:\s*['\"]andicarpet-e777e['\"]", backfill):
        findings.append("BACKFILL_HARDCODED_PRODUCTION")
    if "runTransaction" in backfill and re.search(r"\b(?:written|deleted)\+\+", backfill):
        findings.append("BACKFILL_TRANSACTION_COUNTER_RETRY_REVIEW")
    return {"status": "BLOCK" if findings else "UNCERTIFIED", "findings": findings,
            "production_safe": False, "release_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    try:
        result = inspect(
            (args.root / ".github/workflows/restore-member-directory.yml").read_text(encoding="utf-8"),
            (args.root / "android/app/build.gradle.kts").read_text(encoding="utf-8"),
            (args.root / "functions/backfill_member_directory.js").read_text(encoding="utf-8"))
    except OSError as exc:
        result = {"status": "BLOCK", "error": str(exc), "production_safe": False, "release_approved": False}
    print(json.dumps(result, indent=2))
    return 2 if result["status"] == "BLOCK" else 3


if __name__ == "__main__":
    raise SystemExit(main())
