#!/usr/bin/env python3
"""Read-only release risk checker; no network or mutations."""
import argparse
import json
import re
from pathlib import Path


def inspect(root):
    findings = []

    def add(key, status, detail, source):
        findings.append({"id": key, "status": status, "detail": detail, "source": source})

    workflow = root / ".github/workflows/restore-member-directory.yml"
    if workflow.is_file():
        src = workflow.read_text(encoding="utf-8")
        triggers = re.search(r"(?m)^\s*[\"']?on[\"']?:\s*\n(?P<body>(?:[ \t]+[^\n]*\n|\s*\n)*)", src)
        block = triggers.group("body") if triggers else ""
        auto = bool(re.search(r"(?m)^\s+(push|pull_request|schedule|workflow_run):", block))
        prod = bool(re.search(r"firebase\s+deploy|backfill_member_directory\.js", src))
        add("PRODUCTION_AUTO_DEPLOY", "BLOCK" if auto and prod else ("REVIEW" if prod else "PASS"),
            "Production-capable workflow with automatic trigger" if auto and prod else "Review deploy controls and environment approvals" if prod else "No production deploy commands detected in target workflow",
            str(workflow.relative_to(root)))
    else:
        add("PRODUCTION_AUTO_DEPLOY", "UNKNOWN", "Workflow absent; not evidence that no deploy path exists", str(workflow.relative_to(root)))

    gradle = root / "android/app/build.gradle.kts"
    if gradle.is_file():
        src = gradle.read_text(encoding="utf-8")
        release = re.search(r"\brelease\s*\{(?P<body>.*?)(?=\n\s*\}\s*\n\s*\})", src, re.S)
        body = release.group("body") if release else ""
        debug = bool(re.search(r"signingConfig\s*=\s*signingConfigs\.getByName\(\s*\"debug\"\s*\)", body))
        add("RELEASE_DEBUG_SIGNING", "BLOCK" if debug else "REVIEW",
            "Release explicitly uses debug signing" if debug else "Signing identity must be verified on built APK",
            str(gradle.relative_to(root)))
    else:
        add("RELEASE_DEBUG_SIGNING", "UNKNOWN", "Gradle file missing", str(gradle.relative_to(root)))

    backfill = root / "functions/backfill_member_directory.js"
    if backfill.is_file():
        src = backfill.read_text(encoding="utf-8")
        hardcoded = bool(re.search(r"initializeApp\(\{\s*projectId:\s*[\"']andicarpet-e777e[\"']", src))
        add("BACKFILL_PRODUCTION_TARGET", "BLOCK" if hardcoded else "REVIEW",
            "Backfill initializes production project without a staging parameter" if hardcoded else "Verify backfill target is fail-closed and explicitly staged",
            str(backfill.relative_to(root)))
    else:
        add("BACKFILL_PRODUCTION_TARGET", "UNKNOWN", "Backfill script absent", str(backfill.relative_to(root)))
    return findings


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, default=Path("."))
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    findings = inspect(args.root.resolve())
    if args.json:
        print(json.dumps({"status": "BLOCKED" if any(f["status"] == "BLOCK" for f in findings) else "NOT_CERTIFIED", "findings": findings}, indent=2))
    else:
        for f in findings:
            print(f"{f['status']:7} {f['id']}: {f['detail']} ({f['source']})")
    return 2 if any(f["status"] == "BLOCK" for f in findings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
