#!/usr/bin/env python3
"""Read-only Dart import graph inventory for incremental modularization."""
import argparse
import json
import re
from pathlib import Path

IMPORT = re.compile(r"^\s*(?:import|export)\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
DOMAINS = ("schedule", "centralizer", "reports", "models", "home", "admin", "dashboard", "map")


def analyze(sources, package_name=None):
    """sources: map of lib-relative Dart path to source text."""
    if not isinstance(sources, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in sources.items()):
        raise ValueError("Expected filename-to-source dictionary")
    edges = set()
    unresolved = set()
    for path, content in sources.items():
        if not path.endswith(".dart"):
            continue
        source = path.split("/")[0]
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
            if target not in sources:
                unresolved.add((path, uri))
            destination = target.split("/")[0]
            if source in DOMAINS and destination in DOMAINS and source != destination:
                edges.add((source, destination))
    return {"files": sum(k.endswith(".dart") for k in sources),
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
        match = re.search(r"^name:\\s*([\\w-]+)\\s*$", pubspec.read_text(encoding="utf-8"), re.MULTILINE)
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
