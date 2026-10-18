#!/usr/bin/env bash
set -euo pipefail
python3 scripts/seed_xix_emulator.py
collect_evidence() {
  adb logcat -d -s AndroidRuntime:E flutter:I > xix-evidence/native-logcat.txt || true
  for file in native-flow.pdf observations.json; do
    if adb exec-out run-as com.example.andi_carpeta cat "files/xix-evidence/$file" > "xix-evidence/$file.tmp"; then
      if python3 - "$file" "xix-evidence/$file.tmp" <<'PYVALID'
import json, pathlib, sys
kind, path=sys.argv[1:]
data=pathlib.Path(path).read_bytes()
if kind.endswith('.pdf'):
    assert data.startswith(b'%PDF-') and b'%%EOF' in data[-1024:], 'not a PDF'
else:
    assert isinstance(json.loads(data), dict), 'not an observation object'
PYVALID
      then
        mv "xix-evidence/$file.tmp" "xix-evidence/$file"
      else
        rm -f "xix-evidence/$file.tmp"
      fi
    else
      rm -f "xix-evidence/$file.tmp"
    fi
  done
}
trap collect_evidence EXIT
flutter test integration_test/xix_native_test.dart -d emulator-5554 --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
for file in native-flow.pdf observations.json; do
  tmp="xix-evidence/$file.tmp"
  if ! adb exec-out run-as com.example.andi_carpeta cat "files/xix-evidence/$file" > "$tmp"; then
    rm -f "$tmp"
    echo "Missing native evidence: $file (run-as failed)" >&2
    exit 1
  fi
  mv "$tmp" "xix-evidence/$file"
done
python3 scripts/verify_xix_native_evidence.py
flutter build apk --debug --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
cp build/app/outputs/flutter-apk/app-debug.apk xix-evidence/emulator-operational-debug.apk
adb install -r xix-evidence/emulator-operational-debug.apk
python3 scripts/test_xix_operational_restart.py
