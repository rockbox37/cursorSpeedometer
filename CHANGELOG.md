# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- Clamp theme RGB and brightness values before bridging to UIColor (fixes out-of-range color component warning)
- Replace `.borderedProminent` tint on Night theme with explicit button colors (avoids UIKit highlight math on pure red)
- Speed display snaps to zero faster when stopped (position-based stationary detection, lower jitter threshold, stale-sample timeout)
- Day theme uses pure white background and higher-contrast text

### Changed

- Main speed font increased 35% (96pt → 130pt)
- GPS updates use `kCLDistanceFilterNone` for faster speed refresh
- App icon: digital speedometer design (bolder, larger digits)
- Animated splash screen: motorcycle logo zooms in and fades out over 1 second on launch

### Added

- Initial iOS SwiftUI app scaffold (`cursorSpeedometer.xcodeproj`)
- GPS trip computer: live speed, trip distance, max/average speed, odometer
- Display themes: Day, Night (all-red), Amber
- Auto theme switching at sunrise (Day) and sunset (Night)
- Auto brightness with solar/ambient fallback and manual slider
- Ride Mode (keep screen awake)
- Settings for units, theme, brightness, and odometer reset
- Unit tests for trip engine, themes, solar schedule, theme auto-switch, and brightness
