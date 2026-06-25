import CoreLocation
import Foundation

enum LocationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    /// Below this speed we treat the rider as stationary and prefer device heading
    /// over course-over-ground (which is unreliable / invalid at a standstill).
    static let movingSpeedThresholdMps = 0.8

    @Published private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    @Published private(set) var latestSample: LocationSample?
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    /// Resolved hybrid heading in degrees (course over ground while moving,
    /// device heading when stationary), or nil when unavailable.
    @Published private(set) var headingDegrees: Double?

    private let manager: CLLocationManager
    private let onSample: (LocationSample) -> Void
    private var courseHeadingDegrees: Double?
    private var deviceHeadingDegrees: Double?

    init(manager: CLLocationManager = CLLocationManager(), onSample: @escaping (LocationSample) -> Void) {
        self.manager = manager
        self.onSample = onSample
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .otherNavigation
        updateAuthorizationState()
    }

    func requestPermissionIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdates()
        default:
            updateAuthorizationState()
        }
    }

    func startUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        updateAuthorizationState()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }

    /// Recompute the published heading: course over ground while moving,
    /// otherwise the device heading.
    private func resolveHeading() {
        headingDegrees = courseHeadingDegrees ?? deviceHeadingDegrees
    }

    private func updateAuthorizationState() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationState = .authorized
        case .notDetermined:
            authorizationState = .notDetermined
        default:
            authorizationState = .denied
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationState()
            if authorizationState == .authorized {
                startUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Preserve the raw Doppler speed; a negative value signals "no valid speed"
        // so the engine can fall back to position-derived speed.
        let sample = LocationSample(
            speedMetersPerSecond: location.speed,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            coordinateLatitude: location.coordinate.latitude,
            coordinateLongitude: location.coordinate.longitude
        )

        // Course over ground is only meaningful (and valid) while moving.
        let speed = location.speed
        let course = location.course

        Task { @MainActor in
            latestSample = sample
            coordinate = location.coordinate
            if speed >= LocationService.movingSpeedThresholdMps, course >= 0 {
                courseHeadingDegrees = course
            } else {
                courseHeadingDegrees = nil
            }
            resolveHeading()
            onSample(sample)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer true heading; fall back to magnetic when true is unavailable (negative).
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading

        Task { @MainActor in
            deviceHeadingDegrees = value >= 0 ? value : nil
            resolveHeading()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS errors are transient; keep last known state.
    }
}
