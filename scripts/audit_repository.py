#!/usr/bin/env python3
"""Read-only audit of EVERY git-tracked file; produces a machine-readable inventory.

No deletions, migrations or secret values are emitted. Heuristics are leads, not proof
that a file is unused. Run from the repository root.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from collections import Counter, defaultdict

ROOT = Path(__file__).resolve().parents[1]
TRACKED = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
TRACKED = [p for p in TRACKED if p]
FILES = set(TRACKED)
TEXT_EXT = {".dart", ".js", ".cjs", ".py", ".json", ".yaml", ".yml", ".md", ".html",
            ".xml", ".gradle", ".kts", ".kt", ".swift", ".plist", ".properties",
            ".rules", ".txt", ".cmake", ".cc", ".cpp", ".h", ".sh", ".xcconfig",
            ".pbxproj", ".entitlements", ".storyboard", ".xib", ".rc"}
known_binary = {".png": b"\\x89PNG\\r\\n\\x1a\\n", ".jpg": b"\\xff\\xd8\\xff",
                ".pdf": b"%PDF-", ".zip": b"PK\\x03\\x04"}
rows, warnings = [], []
by_hash = defaultdict(list)
source_texts = {}
for relative in TRACKED:
    path = ROOT / relative
    if not path.is_file():
        warnings.append({"path": relative, "type": "tracked_file_missing"})
        continue
    data = path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    by_hash[sha].append(relative)
    ext = path.suffix.lower()
    rows.append({"path": relative, "bytes": len(data), "sha256": sha,
                 "extension": ext or "(none)"})
    signature = known_binary.get(ext)
    if signature and not data.startswith(signature):
        warnings.append({"path": relative, "type": "unexpected_binary_signature"})
    if ext in TEXT_EXT or relative in {"pubspec.yaml", "firebase.json", "firestore.rules"}:
        try:
            source_texts[relative] = data.decode("utf-8")
        except UnicodeDecodeError:
            if ext not in {".pbxproj"}:
                warnings.append({"path": relative, "type": "invalid_utf8"})
            continue
    if ext == ".json":
        try:
            json.loads(data)
        except (ValueError, UnicodeDecodeError):
            warnings.append({"path": relative, "type": "invalid_json"})

for paths in by_hash.values():
    if len(paths) > 1:
        warnings.append({"type": "identical_content_candidates", "paths": paths})

asset_refs = set()
for name, body in source_texts.items():
    if name.startswith(("lib/", "web/")):
        asset_refs.update(re.findall(r"assets/[A-Za-z0-9_./-]+\\.(?:png|jpg|jpeg|webp|pdf)", body))
for asset in sorted(asset_refs - FILES):
    warnings.append({"type": "referenced_asset_missing", "path": asset})

for name, body in source_texts.items():
    if not name.endswith(".dart"):
        continue
    for imp in re.findall(r"^import\\s+['\\\"]([^'\\\"]+)['\\\"]", body, re.M):
        if imp.startswith(("dart:", "package:")):
            continue
        target = (ROOT / name).parent.joinpath(imp).resolve()
        if not target.is_file():
            warnings.append({"type": "relative_dart_import_missing", "path": name,
                             "import": imp})

for name, body in source_texts.items():
    if not name.startswith(".github/workflows/"):
        continue
    for reference in re.findall(r"(?:run:|working-directory:|path:)\\s*([^\\n]+)", body):
        if "flutter " in reference or "python " in reference or "node " in reference:
            continue
        # Workflow inputs and globs need semantic inspection, not automatic deletion.

report = {
    "tracked_files_scanned": len(TRACKED),
    "readable_text_files": len(source_texts),
    "total_tracked_bytes": sum(row["bytes"] for row in rows),
    "by_extension": dict(sorted(Counter(row["extension"] for row in rows).items())),
    "by_top_folder": dict(sorted(Counter(row["path"].split("/")[0] for row in rows).items())),
    "warnings": warnings,
    "files": rows,
}
output = ROOT / "repository-audit.json"
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("AUDIT tracked=", len(TRACKED), "text=", len(source_texts),
      "warnings=", len(warnings), "bytes=", report["total_tracked_bytes"])
for item in warnings[:60]:
    print("AUDIT WARNING:", json.dumps(item, ensure_ascii=False))
print("Full inventory: repository-audit.json (CI artifact).")
