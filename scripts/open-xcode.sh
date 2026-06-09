#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/device-destination.env
source "$ROOT/scripts/device-destination.env"

PROJECT="$ROOT/cursorSpeedometer.xcodeproj"

osascript <<EOF
tell application "Xcode"
  activate
  open POSIX file "$PROJECT"
  repeat 120 times
    if (count of workspace documents) > 0 then exit repeat
    delay 0.5
  end repeat
  if (count of workspace documents) is 0 then
    error "Xcode did not open the project in time."
  end if
  set doc to workspace document 1
  repeat 120 times
    if loaded of doc is true then exit repeat
    delay 0.5
  end repeat
  if loaded of doc is false then
    error "Xcode workspace did not finish loading in time."
  end if
  set schemeToUse to scheme "cursorSpeedometer" of doc
  set active scheme of doc to schemeToUse
  set deviceId to "$DEVICE_ID"
  set foundDestination to missing value
  repeat with d in run destinations of doc
    if (id of d as text) contains deviceId then
      set foundDestination to d
      exit repeat
    end if
  end repeat
  if foundDestination is missing value then
    error "Run destination not found. Connect Baba's iPhone 15 Pro and trust this Mac."
  end if
  set active run destination of doc to foundDestination
end tell
EOF
