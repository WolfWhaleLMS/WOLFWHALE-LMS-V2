import CoreLocation
import Observation

@MainActor
@Observable
class GeoFenceService: NSObject, CLLocationManagerDelegate {
    var isOnCampus = false
    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var distanceFromCampus: Double = 0

    private let locationManager = CLLocationManager()

    // Default campus center -- should be configured per tenant
    var campusCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    var campusRadius: Double = 500 // meters

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
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
        Task { @MainActor in
            let campusCenterLocation = CLLocation(latitude: self.campusCenter.latitude, longitude: self.campusCenter.longitude)
            let distance = location.distance(from: campusCenterLocation)
            self.currentLocation = location.coordinate
            self.distanceFromCampus = distance
            self.isOnCampus = distance <= self.campusRadius
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[GeoFenceService] Location manager error: \(error.localizedDescription)")
        #endif
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
