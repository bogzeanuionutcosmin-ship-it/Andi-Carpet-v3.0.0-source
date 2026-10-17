#!/usr/bin/env python3
"""Read-only Dart import graph inventory for incremental modularization."""
import argparse
import json
import re
from pathlib import Path

IMPORT = re.compile(r"^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
PART = re.compile(r"^\s*part\s+['\\\"]([^'\\\"]+)['\\\"]", re.MULTILINE)
PART_OF = re.compile(r"^\s*part\s+of\s+['\\\"]([^'\\\"]+)['\\\"]", re.MULTILINE)
DOMAINS = ("schedule", "centralizer", "reports", "models", "home", "admin", "dashboard", "map")


def analyze(sources, package_name=None):
    """sources: map of lib-relative Dart path to source text."""
    if not isinstance(sources, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in sources.items()):
        raise ValueError("Expected filename-to-source dictionary")
    edges = set()
    unresolved = set()
    part_links = set()
    orphan_parts = set()
    invalid_part_owners = set()
    migration_candidates = []
    for path, content in sources.items():
        if not path.endswith(".dart"):
            continue
        source = path.split("/")[0]
        import posixpath
        for uri in PART.findall(content):
            target = posixpath.normpath(posixpath.join(posixpath.dirname(path), uri))
            part_links.add((path, target))
            if target not in sources:
                unresolved.add((path, uri))
        for uri in IMPORT.findall(content):
            if uri.startswith("package:"):
                match = re.match(r"package:[^/]+/(.+)", uri)
                package = uri.split("/", 1)[0].removeprefix("package:")
                if package_name is not None and package != package_name:
                    continue
                target = match.group(1) if match else ""
            elif uri.startswith("dart:") or "://" in uri:
                continue
            else:
                from pathlib import PurePosixPath
                import posixpath
                target = posixpath.normpath(str(PurePosixPath(path).parent / uri))
            if not target.endswith(".dart"):
                continue
            if target.startswith("../") or target.startswith("/"):
                unresolved.add((path, uri))
                continue
            if target not in sources:
                unresolved.add((path, uri))
            destination = target.split("/")[0]
            if source in DOMAINS and destination in DOMAINS and source != destination:
                edges.add((source, destination))
    for path, content in sources.items():
        if not path.endswith(".dart"):
            continue
        for uri in PART_OF.findall(content):
            owner = posixpath.normpath(posixpath.join(posixpath.dirname(path), uri))
            if (owner, path) not in part_links:
                orphan_parts.add((path, owner))
    for owner, part in part_links:
        if part not in sources:
            continue
        declared = {
            posixpath.normpath(posixpath.join(posixpath.dirname(part), uri))
            for uri in PART_OF.findall(sources[part])
        }
        if owner not in declared:
            invalid_part_owners.add((owner, part))
    for path, content in sorted(sources.items()):
        if not path.endswith(".dart") or path == "main.dart":
            continue
        owned_by_main = ("main.dart", path) in part_links
        has_part_of = bool(PART_OF.search(content))
        if owned_by_main or has_part_of:
            migration_candidates.append({
                "file": path,
                "classification": "main_part_requires_dependency_review",
                "safe_to_extract_automatically": False
            })
    return {"migration_candidates": migration_candidates,
            "invalid_part_owners": [{"owner": a, "part": b} for a, b in sorted(invalid_part_owners)],
            "part_links": [{"owner": a, "part": b} for a, b in sorted(part_links)],
            "orphan_parts": [{"part": a, "owner": b} for a, b in sorted(orphan_parts)],
            "files": sum(k.endswith(".dart") for k in sources),
            "cross_domain_edges": [{"from": a, "to": b} for a, b in sorted(edges)],
            "unresolved_imports": [{"file": a, "uri": b} for a, b in sorted(unresolved)],
            "modularization_complete": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lib", type=Path, help="local Flutter lib/ directory")
    args = parser.parse_args()
    try:
        if not args.lib.is_dir():
            raise ValueError("lib directory not found")
        sources = {str(p.relative_to(args.lib)).replace("\\", "/"): p.read_text(encoding="utf-8")
                   for p in args.lib.rglob("*.dart") if p.is_file()}
        pubspec = args.lib.parent / "pubspec.yaml"
        match = re.search(r"^name:\s*([\w-]+)\s*$", pubspec.read_text(encoding="utf-8"), re.MULTILINE)
        if match is None:
            raise ValueError("pubspec.yaml missing package name")
        result = analyze(sources, package_name=match.group(1))
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc), "modularization_complete": False}))
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
