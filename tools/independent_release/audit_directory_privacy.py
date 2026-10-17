#!/usr/bin/env python3
"""Read-only directory projection privacy exposure audit; no user records."""
import argparse
import json
import re
from pathlib import Path

SENSITIVE = frozenset(("phone", "photoBase64", "email", "address", "birthDate"))
ALLOWLIST_PATTERN = re.compile(r"\bFIELDS\s*=\s*Object\.freeze\s*\(\s*\[([\s\S]*?)\]\s*\)")
STRING_PATTERN = re.compile(r"['\"]([^'\"]+)['\"]")


def audit(source):
    if not isinstance(source, str):
        raise ValueError("Source must be text")
    match = ALLOWLIST_PATTERN.search(source)
    if not match:
        raise ValueError("Cannot identify literal projection FIELDS allowlist")
    fields = STRING_PATTERN.findall(match.group(1))
    if len(fields) != len(set(fields)):
        raise ValueError("Duplicate projection field")
    exposure = sorted(set(fields) & SENSITIVE)
    return {"projection_fields": len(fields), "privacy_review_fields": exposure,
            "privacy_owner_approval_required": bool(exposure),
            "privacy_approved": False, "production_safe": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("projection", type=Path)
    args = parser.parse_args()
    try:
        result = audit(args.projection.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc), "privacy_approved": False}))
        return 3
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
