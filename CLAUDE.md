# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`cursorSpeedometer` is a native iOS (SwiftUI, iOS 16+) GPS trip computer for motorcycle, bicycle, and e-bike riders. It shows live speed, trip distance, max/average speed, a persistent odometer, weather, and severe-weather alerts in a glanceable, glove-friendly interface.

## Build, test, lint

The Xcode project is **generated from source**, not hand-edited. After adding, moving, or deleting any Swift file you must regenerate it:

```bash
python3 scripts/generate_xcode_project.py
```

CI regenerates the project on every run, so a source file that isn't picked up by the generator will silently be missing from the build. `scripts/generate_xcode_project.py` walks `cursorSpeedometer/` and `cursorSpeedometerTests/` — new files under those directories are included automatically; there is no manual file list to update.

```bash
# Run the full test suite on a simulator (matches CI)
xcodebuild -project cursorSpeedometer.xcodeproj -scheme cursorSpeedometer \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class or method (append to the test destination)
xcodebuild -project cursorSpeedometer.xcodeproj -scheme cursorSpeedometer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cursorSpeedometerTests/TripComputerEngineTests test

# Lint (CI runs --strict; warnings fail the build)
swiftlint lint --strict

# Build/run on the connected physical device (Baba's iPhone 15 Pro)
./scripts/run-device.sh build      # or: task build:device
./scripts/open-xcode.sh            # or: task open
```

CI (`.github/workflows/ios-ci.yml`) pins **Xcode 15.4**, builds + tests with code coverage, and gates the app target at a **60% line-coverage floor** (`scripts/check_coverage.py`). SwiftLint runs in a separate strict job.

## Architecture

**Composition root.** [`AppModel`](cursorSpeedometer/App/AppModel.swift) (`@MainActor`, `ObservableObject`) owns every long-lived object — `AppSettings`, `RideViewModel`, `LocationService`, and the theme/brightness/weather/alert controllers — and wires them together with Combine in `init`. `cursorSpeedometerApp` creates it as a `@StateObject` and forwards scene-phase and settings changes to it. When adding a new service or controller, construct and bind it in `AppModel`, not in views.

**Lifecycle is centralized.** `AppModel.onAppear`, `onScenePhaseChange`, and `onSettingsChanged` start/stop the adaptive controllers and location updates. Background → foreground calls `rideViewModel.prepareForResume()` to avoid a stale speed jumping on resume. Don't start timers or location work from views.

**Speed pipeline (the core domain logic).**
1. [`LocationService`](cursorSpeedometer/Services/LocationService.swift) wraps `CLLocationManager`, emits `LocationSample`s via an `onSample` closure, and separately publishes a hybrid heading (course-over-ground while moving, device heading when stationary).
2. [`RideViewModel`](cursorSpeedometer/ViewModels/RideViewModel.swift) feeds each sample into the engine, persists the odometer to `AppSettings`, and runs a 0.5s timer that zeroes the displayed speed after a stale gap.
3. [`TripComputerEngine`](cursorSpeedometer/Engine/TripComputerEngine.swift) is a **pure, `Sendable` struct** with no dependencies — `process(sample:state:now:) -> TripComputerState`. It reconciles the GPS Doppler speed against a position-derived (haversine) speed, rejecting glitches in either, snapping stationary jitter to zero, and taking the more responsive reading during acceleration. All the tuning constants and the reasoning behind them live at the top of the file. **This is where speed correctness lives; it is heavily unit-tested and should stay pure and deterministic (inject `now`).**

**Settings & persistence.** [`AppSettings`](cursorSpeedometer/Stores/AppSettings.swift) (`@MainActor`, `ObservableObject`) is the single source of truth for user preferences and the persisted odometer, backed by `UserDefaults`. Each `@Published` property persists in its `didSet` and clamps invalid values by re-assigning (which re-triggers `didSet`, so the guard returns early). Add new preferences here following that pattern.

**Weather & alerts.** [`WeatherController`](cursorSpeedometer/Services/WeatherController.swift) polls Open-Meteo through a `WeatherProvider`, with an **adaptive refresh cadence** (slower when stationary, faster while riding or near freezing, and an immediate refetch after a significant move). `SevereWeatherAlertController` polls the US National Weather Service. Both are location-driven via Combine subscriptions in `AppModel` and are started/stopped with scene phase. Rain/low-temp warning windows are user-configurable and clamped via `OpenMeteoMapper`.

**Theming.** `ThemePreset` (Day / Night-all-red / Amber) resolves to a `ThemePalette` of clamped `ThemeColor`s ([`DisplayTheme.swift`](cursorSpeedometer/Models/DisplayTheme.swift)). `ThemeAutoSwitcherController` + `SolarScheduleService` flip Day/Night at sunrise/sunset; `BrightnessControllerRunner` drives auto-brightness. Both take latitude/longitude (falling back to a default location when GPS is unavailable).

**Views** ([`cursorSpeedometer/Views/`](cursorSpeedometer/Views)) are thin: `RootView` hosts a custom taller-than-native `MainTabBar` (Ride / Settings) and reads state from the injected observable objects. Views observe; they don't own logic or lifecycle.

## Conventions

- **Keep domain logic pure and injectable.** The engine, solar, and mapper types take their inputs (including `now: Date`) as parameters so tests are deterministic. New logic worth testing should follow this — put it in `Engine/`, `Services/`, or `Models/` as a pure type, not inline in a view or view model.
- **UIKit is optional-guarded** (`#if canImport(UIKit)`) so pure-logic types stay testable off-device.
- Tests in [`cursorSpeedometerTests/`](cursorSpeedometerTests) mirror the type they cover (`TripComputerEngineTests`, `WeatherControllerTests`, …). Every service/engine/model with logic has a matching test file.
- SwiftLint config ([`.swiftlint.yml`](.swiftlint.yml)) allows short identifiers (math/geometry) and disables the `todo`/`trailing_comma` rules; line length warns at 140.

## Deft framework (ignore for app work)

`.agents/`, `vbrief/`, `AGENTS.md`, `.githooks/`, and `Taskfile.yml` (the `deft:` include) belong to the **Deft Directive** dev framework, not the app. For normal app work, ignore this subtree.

The framework payload is **not committed**. As of Deft v0.55.1+ it is npm-published and materialized locally under `.deft/core/` (gitignored) by the `deft` CLI. To bootstrap it on a fresh clone (or in any environment that needs `task deft:*`, the pre-commit hooks, or the skills):

```bash
npm i -g @deftai/directive@latest   # Node >= 20; installs the `deft` CLI
deft update                          # deposits .deft/core/ locally
deft migrate                         # one-time, idempotent provenance stamp
deft doctor                          # verify
```

The iOS CI (`ios-ci.yml`) does not depend on Deft, so it needs no bootstrap. The pre-commit hook enforces a branch-protection policy (no direct commits to the default branch unless explicitly allowed).
