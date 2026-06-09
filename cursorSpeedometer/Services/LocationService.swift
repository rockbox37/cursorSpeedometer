import CoreLocation
import Foundation

enum LocationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    @Published private(set) var latestSample: LocationSample?
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager: CLLocationManager
    private let onSample: (LocationSample) -> Void

    init(manager: CLLocationManager = CLLocationManager(), onSample: @escaping (LocationSample) -> Void) {
        self.manager = manager
        self.onSample = onSample
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .fitness
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
        updateAuthorizationState()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
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
        let speed = location.speed >= 0 ? location.speed : 0
        let sample = LocationSample(
            speedMetersPerSecond: speed,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            coordinateLatitude: location.coordinate.latitude,
            coordinateLongitude: location.coordinate.longitude
        )

        Task { @MainActor in
            latestSample = sample
            coordinate = location.coordinate
            onSample(sample)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS errors are transient; keep last known state.
    }
}
