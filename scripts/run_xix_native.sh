#!/usr/bin/env bash
set -euo pipefail
python3 scripts/seed_xix_emulator.py
trap 'adb logcat -d -s AndroidRuntime:E flutter:I > xix-evidence/native-logcat.txt || true' EXIT
flutter test integration_test/xix_native_test.dart -d emulator-5554 --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
for file in native-flow.pdf observations.json; do
  adb exec-out run-as com.example.andi_carpeta cat "files/xix-evidence/$file" > "xix-evidence/$file"
done
flutter build apk --debug --dart-define=ANDICARPET_EMULATOR_HOST=10.0.2.2 --dart-define=MAPBOX_ACCESS_TOKEN=
cp build/app/outputs/flutter-apk/app-debug.apk xix-evidence/emulator-operational-debug.apk
adb install -r xix-evidence/emulator-operational-debug.apk
python3 scripts/test_xix_operational_restart.py
