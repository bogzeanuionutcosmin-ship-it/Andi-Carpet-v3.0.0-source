#!/usr/bin/env python3
"""Offline APK ZIP structure screening; not signing or installability verification."""
import argparse
import json
import zipfile
from pathlib import Path, PurePosixPath

MAX_ENTRIES = 20000
MAX_UNCOMPRESSED = 2 * 1024 * 1024 * 1024
MAX_RATIO = 1000


def inspect(apk: Path):
    if not apk.is_file() or apk.suffix.lower() != ".apk":
        raise ValueError("Input must be an existing .apk file")
    findings = []
    try:
        with zipfile.ZipFile(apk) as archive:
            infos = archive.infolist()
            names = set()
            total = 0
            if len(infos) > MAX_ENTRIES:
                findings.append("too_many_entries")
            for info in infos:
                name = info.filename
                normalized = PurePosixPath(name)
                if name.startswith("/") or "\\" in name or ".." in normalized.parts:
                    findings.append("unsafe_entry_path")
                if name in names:
                    findings.append("duplicate_entry_name")
                names.add(name)
                total += info.file_size
                if info.file_size > MAX_UNCOMPRESSED or total > MAX_UNCOMPRESSED:
                    findings.append("uncompressed_size_limit")
                if info.file_size > MAX_RATIO * max(info.compress_size, 1):
                    findings.append("compression_ratio_limit")
            if "AndroidManifest.xml" not in names:
                findings.append("missing_android_manifest")
            if "classes.dex" not in names:
                findings.append("missing_primary_dex")
            if not any(item in findings for item in (
                "too_many_entries", "uncompressed_size_limit", "compression_ratio_limit"
            )) and archive.testzip() is not None:
                findings.append("corrupt_zip_entry")
    except (zipfile.BadZipFile, EOFError) as exc:
        raise ValueError("Invalid APK ZIP archive") from exc
    return {"apk": apk.name, "zip_structure_pass": not findings,
            "findings": sorted(set(findings)), "signature_verified": False,
            "installability_verified": False, "release_approved": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    try:
        result = inspect(args.apk)
    except (OSError, ValueError, RuntimeError) as exc:
        print(json.dumps({"error": str(exc), "release_approved": False}))
        return 3
    print(json.dumps(result, indent=2))
    return 0 if result["zip_structure_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
