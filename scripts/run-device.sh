#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/device-destination.env
source "$ROOT/scripts/device-destination.env"

PROJECT="$ROOT/cursorSpeedometer.xcodeproj"
SCHEME="cursorSpeedometer"
DESTINATION="platform=iOS,id=${DEVICE_ID}"

cd "$ROOT"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  "$@"
