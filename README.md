# cursorSpeedometer

GPS trip computer for motorcycle, bicycle, and e-bike riders. Shows live speed, trip distance, max/average speed, and a persistent odometer in a glanceable SwiftUI interface.

## Features

- GPS-derived speed and trip stats
- Imperial and metric units
- Display themes: **Day**, **Night** (all-red), **Amber**
- Auto theme: Night at sunset, Day at sunrise
- Auto brightness with manual override
- Ride Mode keeps the screen awake while riding

## Requirements

- Xcode 15+
- iOS 16+ iPhone
- Location permission (When In Use)

## Open in Xcode

Default run destination: **Baba's iPhone 15 Pro**.

```bash
./scripts/open-xcode.sh
```

Or open the project manually and pick **Baba's iPhone 15 Pro** from the destination menu, then Run (⌘R).

## Regenerate Xcode project

If you add or move Swift source files:

```bash
python3 scripts/generate_xcode_project.py
```

## Build from CLI

Build for Baba's iPhone 15 Pro (device must be connected and trusted):

```bash
./scripts/run-device.sh build
```

Generic iOS build (no specific device):

```bash
xcodebuild -project cursorSpeedometer.xcodeproj \
  -scheme cursorSpeedometer \
  -destination 'generic/platform=iOS' \
  build
```

## Troubleshooting Xcode Run failures

**"Signing requires a development team"**  
Open the project in Xcode → select the **cursorSpeedometer** target → **Signing & Capabilities** → choose your **Team**. The project uses Automatic signing and no longer hard-codes an empty team ID.

**"Unable to find a device matching iPhone 16"**  
Use a simulator that exists on your Mac, e.g. **16 Pro** (iOS 18.6), from the scheme destination dropdown.

**App icon / asset catalog errors**  
Ensure `AppIcon-1024.png` is exactly **1024×1024**. Then **Product → Clean Build Folder** (⇧⌘K) and rebuild.

**CoreSimulator out of date**  
Update macOS and Xcode so Simulator runtimes match your Xcode version (Settings → General → Software Update).

## Tests

```bash
xcodebuild -project cursorSpeedometer.xcodeproj \
  -scheme cursorSpeedometer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Project layout

```
cursorSpeedometer/          # iOS app sources
cursorSpeedometerTests/     # Unit tests
cursorSpeedometer.xcodeproj/
vbrief/                     # Deft scope vBRIEFs
```

Built with [Deft Directive](https://github.com/deftai/directive).
