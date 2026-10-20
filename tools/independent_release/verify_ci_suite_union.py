#!/usr/bin/env python3
"""Offline check that a candidate CI file names all required Firestore suites."""
import argparse
import json
import re
from pathlib import Path

REQUIRED = (
    "tests/firestore/diurna.test.cjs",
    "tests/firestore/program_schedule.test.cjs",
    "tests/firestore/centralizer_correction.test.cjs",
    "tests/firestore/finance_identity.test.cjs",
)


def inspect(text):
    # Require test paths inside one command; scattered comments do not qualify.
    lines = text.splitlines()
    candidates = [line for line in lines if "firebase emulators:exec" in line and "node --test" in line
                  and not line.lstrip().startswith("#")]
    if not candidates:
        return {"status": "BLOCK", "reason": "No combined emulator test command", "missing": list(REQUIRED),
                "certified": False}
    best = min((sorted(set(REQUIRED) - set(re.findall(r"tests/firestore/[\w.-]+\.test\.cjs", line)))
                for line in candidates), key=len)
    return {"status": "REVIEW" if not best else "BLOCK", "missing": best,
            "reason": "Static suite-name presence only; does not execute tests",
            "certified": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workflow", type=Path)
    args = parser.parse_args()
    try:
        result = inspect(args.workflow.read_text(encoding="utf-8"))
    except OSError as exc:
        result = {"status": "BLOCK", "reason": str(exc), "certified": False}
    print(json.dumps(result, indent=2))
    return 2 if result["status"] == "BLOCK" else 3


if __name__ == "__main__":
    raise SystemExit(main())
