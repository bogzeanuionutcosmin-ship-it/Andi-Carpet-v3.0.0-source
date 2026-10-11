#!/usr/bin/env python3
"""Improve widget tap targets after the original Android sources are extracted."""
from pathlib import Path
import xml.etree.ElementTree as ET

path = Path("android/app/src/main/res/layout/route_widget.xml")
if not path.exists():
    raise SystemExit("Widget layout missing from candidate archive")
ns = "{http://schemas.android.com/apk/res/android}"
tree = ET.parse(path)
root = tree.getroot()
ids = {}
for element in root.iter():
    element_id = element.attrib.get(ns + "id", "")
    if element_id:
        ids[element_id.rsplit("/", 1)[-1]] = element

required = ["route_prev_day", "route_next_day", "route_prev_page", "route_next_page"]
required += [f"route_{app}_{i}" for app in ("maps", "waze") for i in (1, 2, 3)]
required += [f"route_stop_{i}" for i in (1, 2, 3)]
missing = set(required) - ids.keys()
if missing:
    raise SystemExit(f"Unexpected widget layout; missing IDs: {sorted(missing)}")

for name in required:
    node = ids[name]
    node.set(ns + "minHeight", "48dp")
    if name.startswith("route_maps") or name.startswith("route_waze"):
        node.set(ns + "minWidth", "48dp")
        node.set(ns + "gravity", "center")
        node.set(ns + "textSize", "20sp")
        # Icons are drawn by Android; retain the IDs so existing navigation
        # PendingIntents still point to the right location and app.
        node.set(ns + "fontFamily", "sans")
    elif name.startswith("route_stop"):
        node.set(ns + "textSize", "16sp")
    else:
        node.set(ns + "minWidth", "48dp")
        node.set(ns + "gravity", "center")
        node.set(ns + "textSize", "22sp")
        node.set(ns + "text", "❮" if "prev" in name else "❯")

ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
tree.write(path, encoding="utf-8", xml_declaration=True)
print("Widget layout enlarged; provider IDs preserved")
