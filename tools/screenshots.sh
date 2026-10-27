#!/bin/bash
#
# Capture Wishcast's App Store screenshots on one simulator, in as many languages as you name.
#
# The app is launched once per shot with `-shot N` (see Wishcast/Views/ScreenshotMode.swift) plus the
# language as launch arguments, and simctl grabs the framebuffer — already the exact size Apple asks
# for (1320 × 2868 on a 6.9" iPhone, 2064 × 2752 on a 13" iPad). The shots use real forecasts for
# Denver, so they show whatever the weather models say at capture time.
#
#   tools/screenshots.sh "iPhone 17 Pro Max" en-US de-DE ja
#   tools/screenshots.sh "iPad Pro 13-inch (M5)" all
#
# Output: fastlane/screenshots/<locale>/<device>_<n>-<name>.png
# Requires a Debug simulator build (BuildProject, or xcodebuild for an iOS simulator).
set -euo pipefail

BUNDLE_ID="com.jirofeingold.Wishcast"
SHOTS=(1-list 2-day 3-snow 4-wild-guess 5-how-it-works)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALL_LOCALES=(en-US de-DE es-ES fr-FR it ja ko pt-BR ru zh-Hans zh-Hant)

# App Store Connect locale → the iOS language and region to launch with (the region sets the units).
locale_language() {
  case "$1" in
    en-US)   echo "en en_US" ;;
    de-DE)   echo "de de_DE" ;;
    es-ES)   echo "es es_ES" ;;
    fr-FR)   echo "fr fr_FR" ;;
    it)      echo "it it_IT" ;;
    ja)      echo "ja ja_JP" ;;
    ko)      echo "ko ko_KR" ;;
    pt-BR)   echo "pt-BR pt_BR" ;;
    ru)      echo "ru ru_RU" ;;
    zh-Hans) echo "zh-Hans zh_CN" ;;
    zh-Hant) echo "zh-Hant zh_TW" ;;
    *)       echo "" ;;
  esac
}

DEVICE="${1:?usage: screenshots.sh <simulator name> <locale…|all>}"
shift
LOCALES=("$@")
if [[ "${LOCALES[0]:-}" == "all" ]]; then LOCALES=("${ALL_LOCALES[@]}"); fi

UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | tail -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "no available simulator named '$DEVICE'"; exit 1; }
case "$DEVICE" in
  iPad*) PREFIX="ipad13" ;;
  *)     PREFIX="iphone69" ;;
esac

# The Debug simulator build: APP_PATH if set, else Xcode's custom build location on this Mac.
APP="${APP_PATH:-}"
if [[ -z "$APP" ]]; then
  # Ask Xcode where it builds (this Mac uses a custom location on an external volume).
  PRODUCTS=$(cd "$ROOT" && xcodebuild -project Wishcast.xcodeproj -scheme Wishcast -sdk iphonesimulator \
    -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
  [[ -d "$PRODUCTS/Wishcast.app" ]] && APP="$PRODUCTS/Wishcast.app"
fi
[[ -n "$APP" ]] || { echo "no Debug simulator build found — build the app first (or set APP_PATH)"; exit 1; }

echo "device:  $DEVICE ($UDID)"
echo "app:     $APP"
echo "locales: ${LOCALES[*]}"

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
timeout 120 xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
# A clean status bar, as on the App Store.
timeout 30 xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 >/dev/null 2>&1 || true

# A throwaway launch first: the first launch after an install is the slow one.
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -shot 1 >/dev/null
sleep 8

for locale in "${LOCALES[@]}"; do
  read -r language applelocale <<<"$(locale_language "$locale")"
  [[ -n "$language" ]] || { echo "!! unknown locale $locale — skipped"; continue; }
  out="$ROOT/fastlane/screenshots/$locale"
  mkdir -p "$out"
  for i in "${!SHOTS[@]}"; do
    shot=$((i + 1))
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" \
      -shot "$shot" -AppleLanguages "($language)" -AppleLocale "$applelocale" >/dev/null
    # Long enough to download ~170 forecasts (and, for the wild guess, the long-range ones) and settle.
    if [[ $shot -eq 4 ]]; then sleep 16; else sleep 9; fi
    xcrun simctl io "$UDID" screenshot --type=png "$out/${PREFIX}_${SHOTS[$i]}.png" >/dev/null 2>&1
  done
  echo "  $locale: ${#SHOTS[@]} shots"
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
