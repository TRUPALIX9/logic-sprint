#!/usr/bin/env bash
# Records integration_test/store_demo_test.dart on an iOS simulator or an
# Android emulator: ../logic-sprint-release/demo/<name>.mov|.mp4 plus <name>.marks (scene
# start times, ms from the start of the recording).
#
#   tool/record_demo.sh ios "iPhone 17 Pro Max" iphone
#   tool/record_demo.sh ios "iPad Pro 13-inch (M5)" ipad
#   tool/record_demo.sh android emulator-5554 android
set -euo pipefail

platform=$1 device=$2 name=$3
cd "$(dirname "$0")/.."
out=../logic-sprint-release/demo
mkdir -p "$out"
log="$out/$name.log"
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

if [[ $platform == ios ]]; then
  udid=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
for rt in json.load(sys.stdin)['devices'].values():
    for d in rt:
        if d['name'] == sys.argv[1]:
            print(d['udid']); sys.exit()" "$device")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
  # Build and install first, so the recording isn't minutes of home screen.
  flutter build ios --simulator --debug -t integration_test/store_demo_test.dart >/dev/null
  rm -f "$out/$name.mov"
  xcrun simctl io "$udid" recordVideo --codec h264 --force "$out/$name.mov" &
  rec=$!
  trap 'kill -INT $rec 2>/dev/null || true' EXIT
  target=$udid
else
  flutter build apk --debug -t integration_test/store_demo_test.dart >/dev/null
  adb -s "$device" shell settings put global sysui_demo_allowed 1
  adb -s "$device" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  adb -s "$device" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
  adb -s "$device" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
  adb -s "$device" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
  # screenrecord stops at 3 minutes, so chain three segments.
  adb -s "$device" shell 'for i in 1 2 3; do screenrecord --bit-rate 12000000 /sdcard/demo_$i.mp4; done' &
  rec=$!
  target=$device
fi
sleep 1
start=$(now_ms)

flutter test integration_test/store_demo_test.dart -d "$target" 2>&1 | tee "$log"

sleep 1
if [[ $platform == ios ]]; then
  kill -INT $rec 2>/dev/null || true
  wait $rec || true
  xcrun simctl status_bar "$udid" clear
else
  adb -s "$device" shell pkill -INT screenrecord || true
  wait $rec || true
  sleep 2
  files=()
  for i in 1 2 3; do
    if adb -s "$device" pull /sdcard/demo_$i.mp4 "$out/${name}_$i.mp4" >/dev/null 2>&1; then
      files+=("file '${name}_$i.mp4'")
    fi
    adb -s "$device" shell rm -f /sdcard/demo_$i.mp4
  done
  printf '%s\n' "${files[@]}" > "$out/$name.concat"
  ffmpeg -loglevel error -y -f concat -safe 0 -i "$out/$name.concat" -c copy "$out/$name.mp4"
  adb -s "$device" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
fi

grep -o 'DEMO_MARK [a-z_]* [0-9]*' "$log" | awk -v s="$start" '{print $2, $3 - s}' > "$out/$name.marks"
echo "Recorded $out/$name.* (marks: $out/$name.marks)"
