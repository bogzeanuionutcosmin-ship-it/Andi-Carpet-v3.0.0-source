#!/usr/bin/env python3
"""Offline APK SHA-256 manifest verification; never installs or publishes an APK."""
import argparse
import hashlib
import json
from pathlib import Path


def verify(apk: Path, manifest: Path):
    data = json.loads(manifest.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Manifest must be a JSON object")
    expected = data.get("sha256")
    if not isinstance(expected, str) or len(expected) != 64 or any(c not in "0123456789abcdefABCDEF" for c in expected):
        raise ValueError("Manifest sha256 must be 64 hexadecimal characters")
    if not apk.is_file() or not apk.name.lower().endswith(".apk"):
        raise ValueError("Input must be an existing .apk file")
    digest = hashlib.sha256()
    with apk.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    actual = digest.hexdigest()
    return {"apk": apk.name, "expected_sha256": expected.lower(), "actual_sha256": actual,
            "hash_matches": actual == expected.lower(), "signature_verified": False,
            "release_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("manifest", type=Path, help="JSON containing independently approved sha256")
    args = parser.parse_args()
    try:
        result = verify(args.apk, args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc), "release_approved": False}))
        return 3
    print(json.dumps(result, indent=2))
    return 0 if result["hash_matches"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
