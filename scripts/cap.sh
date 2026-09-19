#!/usr/bin/env bash
# cap.sh - device helpers for capturing store-ready app screens.
#
#   cap.sh devices                          list Android emulators/devices + booted iOS sims
#   cap.sh clean   android|ios [id]         clean status bar (9:41, full battery, no notifications)
#   cap.sh unclean android|ios [id]         restore the normal status bar
#   cap.sh shot    android|ios|ipad-land|mac OUT.png [id|window-name]
#                                           capture full-res; ipad-land rotates to landscape
#   cap.sh preview IN.png [px]              downscaled copy (IN.preview.png) for looking at
#   cap.sh type    ios|android "text"       reliable typing (iOS: System Events keystroke)
#   cap.sh clear   ios|android              select-all + delete in the focused field
#   cap.sh tap     android X Y [id]         tap in device pixels
#   cap.sh push    android|ios FILE...      put sample photos/PDFs into the gallery/Photos
#   cap.sh files   ios FILE...              put files into the sim's Files app ("On My iPhone/iPad")
#   cap.sh rotate  ios left|right           rotate the Simulator window (iPad landscape)
#   cap.sh empty   IN.png                   heuristic: warns if the screen looks mostly blank
set -euo pipefail
cmd=${1:-}; shift || true

adbs() { if [ -n "${ID:-}" ]; then adb -s "$ID" "$@"; else adb "$@"; fi; }
py() { python3 - "$@"; }

case "$cmd" in
devices)
  echo "== Android"; adb devices -l 2>/dev/null | tail -n +2
  for d in $(adb devices | awk 'NR>1&&$2=="device"{print $1}'); do
    echo "$d: $(adb -s $d shell wm size | tail -1) density $(adb -s $d shell wm density | tail -1 | awk '{print $NF}')"; done
  echo "== iOS (booted)"; xcrun simctl list devices booted 2>/dev/null | grep -v "^==" || true ;;
clean)
  p=$1; ID=${2:-}
  if [ "$p" = android ]; then
    adbs shell settings put global sysui_demo_allowed 1
    for c in "enter" "clock -e hhmm 0941" "battery -e level 100 -e plugged false" \
             "network -e wifi show -e level 4 -e mobile show -e level 4 -e datatype none" "notifications -e visible false"; do
      adbs shell am broadcast -a com.android.systemui.demo -e command $c >/dev/null; done
  else
    xcrun simctl status_bar "${ID:-booted}" override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularBars 4
  fi ;;
unclean)
  p=$1; ID=${2:-}
  if [ "$p" = android ]; then adbs shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
  else xcrun simctl status_bar "${ID:-booted}" clear; fi ;;
shot)
  p=$1; out=$2; ID=${3:-}; mkdir -p "$(dirname "$out")"
  case "$p" in
    android) adbs exec-out screencap -p > "$out" ;;
    ios) xcrun simctl io "${ID:-booted}" screenshot "$out" >/dev/null 2>&1 ;;
    ipad-land) xcrun simctl io "${ID:-booted}" screenshot "$out" >/dev/null 2>&1
      py "$out" <<'EOF'
import sys; from PIL import Image
p=sys.argv[1]; im=Image.open(p)
if im.height>im.width: im=im.rotate(-90,expand=True)
im.convert("RGB").save(p)
EOF
      ;;
    mac) name=${3:?window/app name}
      wid=$(osascript -e "tell application \"System Events\" to tell process \"$name\" to get id of window 1" 2>/dev/null || true)
      if [ -n "$wid" ]; then screencapture -o -l "$wid" "$out"; else screencapture -o -w "$out"; fi ;;
  esac
  python3 -c "from PIL import Image;im=Image.open('$out');print('$out',im.size)" ;;
preview)
  px=${2:-900}; sips -Z "$px" "$1" --out "${1%.png}.preview.png" >/dev/null; echo "${1%.png}.preview.png" ;;
type)
  p=$1; t=$2
  if [ "$p" = ios ]; then
    osascript -e 'tell application "Simulator" to activate' -e 'delay 0.3' -e "tell application \"System Events\" to keystroke \"${t//\"/\\\"}\""
  else adbs shell input text "$(printf '%s' "$t" | sed 's/ /%s/g;s/[()<>|;&*\\~"'"'"'`$]//g')"; fi ;;
clear)
  if [ "$1" = ios ]; then
    osascript -e 'tell application "Simulator" to activate' -e 'delay 0.3' -e 'tell application "System Events"' -e 'keystroke "a" using command down' -e 'key code 51' -e 'end tell'
  else adbs shell input keyevent 123; adbs shell input keyevent $(printf '67 %.0s' $(seq 1 300)); fi ;;
tap) ID=${4:-}; adbs shell input tap "$2" "$3" ;;
push)
  p=$1; shift
  if [ "$p" = android ]; then
    for f in "$@"; do adbs push "$f" "/sdcard/Pictures/$(basename "$f")" >/dev/null
      adbs shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Pictures/$(basename "$f")" >/dev/null; done
  else xcrun simctl addmedia booted "$@"; fi; echo pushed ;;
files)
  shift; U=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
  P=$(find ~/Library/Developer/CoreSimulator/Devices/$U/data/Containers/Shared/AppGroup -maxdepth 2 -name "File Provider Storage" | head -1)
  cp "$@" "$P/"; ls "$P" ;;
rotate)
  k=$([ "$2" = left ] && echo 123 || echo 124)
  osascript -e 'tell application "Simulator" to activate' -e 'delay 0.5' -e "tell application \"System Events\" to key code $k using command down" ;;
empty)
  py "$1" <<'EOF'
import sys; from PIL import Image, ImageFilter; import numpy as np
im=Image.open(sys.argv[1]).convert("L"); w,h=im.size
a=np.asarray(im.crop((0,int(h*.12),w,int(h*.9))).filter(ImageFilter.FIND_EDGES))
busy=(a>40).mean()
print(f"detail={busy:.3f}", "WARNING: looks mostly empty - add data before using this capture" if busy<0.012 else "ok")
EOF
  ;;
*) sed -n 2,17p "$0" ;;
esac
