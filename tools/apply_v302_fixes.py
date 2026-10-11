#!/usr/bin/env python3
"""Safe, idempotent fixes applied to the original v3.0.1 ZIP at build time.

The source archive is not edited; each expected source fragment is verified
before replacement, so a future incompatible version fails rather than
silently removing unrelated features.
"""
from pathlib import Path

source = Path("lib/main.dart")
data = source.read_text(encoding="utf-8")
changes = [
    ("const String _appVersionLabel = '3.0.0+32';",
     "const String _appVersionLabel = '3.0.2+34';"),
    ("Text('Fereastră standard: ${timeText(workWindowStart(workDate))} → ${timeText(workWindowEnd(workDate))}'),",
     ""),
    ("_StatMini(label:'Km GPS (linie dreaptă)',value:", "_StatMini(label:'Km GPS estimativi (linie dreaptă)',value:"),
    ("_InfoCard(icon:Icons.info_outline,title:'Estimare traseu complet',text:", "_InfoCard(icon:Icons.info_outline,title:'Estimare geometrică (nu rutieră)',text:"),
]
for before, after in changes:
    count = data.count(before)
    if count != 1:
        raise SystemExit(f"Expected exactly one occurrence ({count}): {before[:90]}")
    data = data.replace(before, after, 1)
source.write_text(data, encoding="utf-8")

pubspec = Path("pubspec.yaml")
text = pubspec.read_text(encoding="utf-8")
if "version: 3.0.1+33" not in text:
    raise SystemExit("Unexpected pubspec version; manual review required")
pubspec.write_text(text.replace("version: 3.0.1+33", "version: 3.0.2+34", 1), encoding="utf-8")
print("Applied verified UI and version fixes")
