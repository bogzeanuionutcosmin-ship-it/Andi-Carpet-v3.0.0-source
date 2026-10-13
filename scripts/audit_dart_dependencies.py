#!/usr/bin/env python3
"""Read-only Dart directive/declaration inventory (not a Dart analyzer).

Conditional branches are all retained. Parts are collapsed into their owning
library before checking import/export cycles; part-of is not an import cycle.
Declaration matches are an inventory, not proof of use or of safe deletion.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DIRECTIVE = re.compile(r"^\s*(import|export|part\s+of|part)\s+([^;]+);", re.M)
NAMED = re.compile(r"^(?:abstract\s+|final\s+|sealed\s+|base\s+)?(class|enum|mixin|extension|typedef)\s+(\w+)", re.M)
FUNCTION = re.compile(r"^(?:Future<[^\n]+?>|List<[^\n]+?>|Map<[^\n]+?>|[A-Z]\w*|void|bool|int|double)\??\s+(\w+)\(", re.M)


def cycles(graph):
    """Tarjan SCCs, returning only cycles including self-imports."""
    indices, low, stack, active, found = {}, {}, [], set(), []

    def visit(node):
        indices[node] = low[node] = len(indices)
        stack.append(node)
        active.add(node)
        for target in sorted(graph.get(node, ())):
            if target not in indices:
                visit(target)
                low[node] = min(low[node], low[target])
            elif target in active:
                low[node] = min(low[node], indices[target])
        if low[node] == indices[node]:
            component = []
            while True:
                target = stack.pop()
                active.remove(target)
                component.append(target)
                if target == node:
                    break
            if len(component) > 1 or node in graph.get(node, ()):
                found.append(sorted(component))

    for node in sorted(graph):
        if node not in indices:
            visit(node)
    return sorted(found)


def inventory(root=ROOT):
    paths = sorted(p for folder in ("lib", "test") for p in (root / folder).rglob("*.dart"))
    sources = {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8") for p in paths}
    rows, owners, missing = [], {}, []
    for path, body in sources.items():
        directives = []
        owner = path
        for match in DIRECTIVE.finditer(body):
            kind = " ".join(match[1].split())
            uris = re.findall(r"['\"]([^'\"]+)['\"]", match[2])
            targets = []
            for uri in uris:
                if uri.startswith("dart:") or (uri.startswith("package:") and not uri.startswith("package:andi_carpeta/")):
                    continue
                target = (root / "lib" / uri.removeprefix("package:andi_carpeta/")) if uri.startswith("package:andi_carpeta/") else root / Path(path).parent / uri
                target = target.resolve().relative_to(root.resolve()).as_posix()
                targets.append(target)
                if target not in sources:
                    missing.append({"source": path, "kind": kind, "target": target})
            if kind == "part of" and targets:
                owner = targets[0]
            directives.append({"kind": kind, "text": match[0].strip(), "uris": uris, "local_targets": targets})
        owners[path] = owner
        rows.append({"path": path, "bytes": len(body.encode()), "sha256": hashlib.sha256(body.encode()).hexdigest(),
                     "owner": owner, "directives": directives,
                     "declarations": [{"kind": m[1], "name": m[2]} for m in NAMED.finditer(body)],
                     "top_level_functions": FUNCTION.findall(body)})
    graph = {p: set() for p in sources if owners[p] == p}
    names = defaultdict(list)
    orphan_parts = []
    for row in rows:
        for declaration in row["declarations"]:
            names[(row["owner"], declaration["name"])].append(row["path"])
        for directive in row["directives"]:
            if directive["kind"] in {"import", "export"}:
                graph.setdefault(row["owner"], set()).update(owners.get(t, t) for t in directive["local_targets"])
        if row["owner"] != row["path"]:
            owner_body = sources.get(row["owner"], "")
            owner_parts = [t for m in DIRECTIVE.finditer(owner_body) if m[1] == "part"
                           for t in re.findall(r"['\"]([^'\"]+)['\"]", m[2])]
            expected = (root / row["owner"]).parent
            if not any((expected / t).resolve() == (root / row["path"]).resolve() for t in owner_parts):
                orphan_parts.append(row["path"])
    return {"format_version": 1, "dart_files": len(rows),
            "lib_dart_files": sum(row["path"].startswith("lib/") for row in rows),
            "test_dart_files": sum(row["path"].startswith("test/") for row in rows),
            "parts": sum(row["owner"] != row["path"] for row in rows), "libraries": len(graph),
            "limitations": "Directive/declaration inventory, all conditional branches included; no use/call/type analysis. Not proof of unused code.",
            "missing_targets": missing, "orphan_parts": orphan_parts,
            "duplicate_declarations_in_library": [{"owner": key[0], "name": key[1], "files": paths}
                                                  for key, paths in sorted(names.items()) if len(paths) > 1],
            "library_edges": {p: sorted(ts) for p, ts in sorted(graph.items())},
            "import_export_cycles": cycles(graph), "files": rows}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dart-dependency-audit.json")
    args = parser.parse_args()
    report = inventory()
    (ROOT / args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("dart_files", "parts", "libraries", "missing_targets", "orphan_parts", "duplicate_declarations_in_library", "import_export_cycles")}, ensure_ascii=False))
