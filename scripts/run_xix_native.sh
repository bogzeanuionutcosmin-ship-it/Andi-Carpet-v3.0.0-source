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
# Capture evidence while the instrumentation package still exists. Flutter may
# remove its test APK (and sandbox files) when flutter test exits.
(
  for attempt in $(seq 1 90); do
    complete=1
    for file in native-flow.pdf observations.json; do
      target="xix-evidence/$file"
      if test -s "$target"; then continue; fi
      tmp="$target.polling"
      if adb exec-out run-as com.example.andi_carpeta cat "files/xix-evidence/$file" > "$tmp" 2>/dev/null && python3 - "$file" "$tmp" 2>/dev/null <<'PYPOLL'
import json, pathlib, sys
kind, name = sys.argv[1:]
raw = pathlib.Path(name).read_bytes()
if kind.endswith(".pdf"):
    assert raw.startswith(b"%PDF-") and b"%%EOF" in raw[-1024:]
else:
    assert json.loads(raw).get("completed") is True
PYPOLL
      then
        mv "$tmp" "$target"
      else
        rm -f "$tmp"
        complete=0
      fi
    done
    if test "$complete" = 1; then
      adb shell run-as com.example.andi_carpeta touch files/xix-evidence/host-captured.ok
      exit 0
    fi
    sleep 2
  done
  exit 1
) &
evidence_collector=$!
flutter test --no-uninstall integration_test/xix_native_test.dart -d emulator-5554 --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
if ! wait "$evidence_collector"; then
  echo "Evidence collector timed out before both completed artifacts were available" >&2
  adb shell pm list packages | grep -F andi_carpeta || true
  adb shell ls -la /data/user/0/com.example.andi_carpeta/files/xix-evidence || true
  adb shell dumpsys package com.example.andi_carpeta | grep -E "userId=|pkg=|versionName" | head -12 || true
  exit 1
fi
python3 scripts/verify_xix_native_evidence.py
# Flutter test may uninstall its instrumentation APK after a successful run.
# Install the operational app before using Android run-as to inspect its sandbox.
flutter build apk --debug --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
cp build/app/outputs/flutter-apk/app-debug.apk xix-evidence/emulator-operational-debug.apk
adb install -r xix-evidence/emulator-operational-debug.apk
python3 scripts/test_xix_operational_restart.py
