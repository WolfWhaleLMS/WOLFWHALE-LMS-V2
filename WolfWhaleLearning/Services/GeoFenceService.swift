import CoreLocation
import Combine

@MainActor
class GeoFenceService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isOnCampus = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var distanceFromCampus: Double = 0

    private let locationManager = CLLocationManager()

    // Default campus center -- should be configured per tenant
    var campusCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    var campusRadius: Double = 500 // meters

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startMonitoring() {
        locationManager.startUpdatingLocation()
        let region = CLCircularRegion(
            center: campusCenter,
            radius: campusRadius,
            identifier: "campus"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.monitoredRegions.forEach { locationManager.stopMonitoring(for: $0) }
    }

    // MARK: - CLLocationManagerDelegate (nonisolated)

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let campusCenterLocal = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let distance = location.distance(from: campusCenterLocal)
        Task { @MainActor in
            self.currentLocation = location.coordinate
            self.distanceFromCampus = distance
            self.isOnCampus = distance <= self.campusRadius
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startMonitoring()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            self.isOnCampus = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            self.isOnCampus = false
        }
    }
}
