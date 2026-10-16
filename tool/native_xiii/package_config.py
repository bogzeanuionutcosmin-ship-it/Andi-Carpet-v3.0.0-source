"""Bind reviewed app library into the isolated pure-Dart test runner only."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
path=root/'tool/native_xiii/runner/.dart_tool/package_config.json'
data=json.loads(path.read_text())
data['packages']=[p for p in data['packages'] if p['name']!='andi_carpeta']
data['packages'].append(dict(name='andi_carpeta',rootUri=root.as_uri()+'/',packageUri='lib/',languageVersion='3.12'))
path.write_text(json.dumps(data))
