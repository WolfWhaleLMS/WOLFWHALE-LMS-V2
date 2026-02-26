import SwiftUI
import MapKit
import CoreLocation

// MARK: - View Model

@Observable
@MainActor
final class ClassroomFinderViewModel: NSObject, CLLocationManagerDelegate {
    var allLocations: [CampusLocation] = CampusLocation.mockLocations
    var targetLocation: CampusLocation?
    var userLocation: CLLocationCoordinate2D?
    var route: MKRoute?
    var isLoadingRoute = false
    var routeError: String?
    var cameraPosition: MapCameraPosition = .automatic

    // Mock schedule for "Next Class" feature
    var courses: [Course] = []

    private let locationManager = CLLocationManager()

    /// Walking time in minutes from current location to target.
    var estimatedWalkingMinutes: Int? {
        guard let route else { return nil }
        return max(1, Int(route.expectedTravelTime / 60))
    }

    /// Distance in meters from current location to target.
    var distanceToTarget: Double? {
        guard let userCoord = userLocation, let target = targetLocation else { return nil }
        let from = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        let to = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return from.distance(from: to)
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }

    func selectLocation(_ location: CampusLocation) {
        targetLocation = location
        calculateRoute()
    }

    /// Find the "next class" based on mock course schedule and map it to a campus location.
    func findNextClass() {
        // Match the first course to a classroom location for demo purposes.
        // In a real app this would use the student's timetable.
        guard let firstCourse = courses.first else { return }

        // Try to match course title keywords to a location name
        let match = allLocations.first { loc in
            loc.type == .classroom || loc.type == .lab
        }

        if let match {
            selectLocation(match)
        }

        // Suppress unused variable warning
        _ = firstCourse
    }

    func calculateRoute() {
        guard let target = targetLocation else { return }

        isLoadingRoute = true
        routeError = nil
        route = nil

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(location: CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude), address: nil)
        request.transportType = .walking

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoadingRoute = false
                if let error {
                    self.routeError = UserFacingError.message(from: error)
                    // Fallback: set camera to target anyway
                    self.cameraPosition = .region(
                        MKCoordinateRegion(
                            center: target.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )
                    )
                    return
                }
                if let route = response?.routes.first {
                    self.route = route
                    // Zoom to show the full route
                    self.cameraPosition = .automatic
                }
            }
        }
    }

    func openInMaps() {
        guard let target = targetLocation else { return }
        let destination = MKMapItem(location: CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude), address: nil)
        destination.name = target.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // MARK: - CLLocationManagerDelegate (nonisolated)

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Classroom Finder View

struct ClassroomFinderView: View {
    let courses: [Course]
    var preselectedLocation: CampusLocation?

    @State private var viewModel = ClassroomFinderViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Map
            mapSection
                .frame(maxHeight: .infinity)

            // Bottom panel
            bottomPanel
        }
        .navigationTitle("Classroom Finder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.findNextClass()
                } label: {
                    Label("Next Class", systemImage: "forward.fill")
                        .font(.subheadline)
                }
                .accessibilityLabel("Find next class location")
            }
        }
        .onAppear {
            viewModel.courses = courses
            viewModel.start()
            if let preselected = preselectedLocation {
                viewModel.selectLocation(preselected)
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapSection: some View {
        Map(position: $viewModel.cameraPosition) {
            UserAnnotation()

            // Show the route polyline
            if let route = viewModel.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }

            // Target annotation
            if let target = viewModel.targetLocation {
                Annotation(
                    target.name,
                    coordinate: target.coordinate,
                    anchor: .bottom
                ) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(Color.red.gradient)
                                .frame(width: 40, height: 40)
                                .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
                            Image(systemName: target.type.systemImage)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                            .rotationEffect(.degrees(180))
                            .offset(y: -4)
                    }
                }
            }

            // Other locations (dimmed)
            ForEach(viewModel.allLocations.filter { $0.id != viewModel.targetLocation?.id }) { location in
                Annotation(
                    location.name,
                    coordinate: location.coordinate,
                    anchor: .bottom
                ) {
                    Circle()
                        .fill(Theme.courseColor(location.type.tintColor).opacity(0.4))
                        .frame(width: 20, height: 20)
                        .overlay {
                            Image(systemName: location.type.systemImage)
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                        }
                        .onTapGesture {
                            viewModel.selectLocation(location)
                        }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if let target = viewModel.targetLocation {
                // Target info
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.courseColor(target.type.tintColor).opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: target.type.systemImage)
                            .font(.title3)
                            .foregroundStyle(Theme.courseColor(target.type.tintColor))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(target.name)
                            .font(.headline)
                        Text("\(target.buildingName) - \(target.roomNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let floor = target.floor {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(floor == 0 ? "G" : "\(floor)F")
                                .font(.caption.bold())
                        }
                        .padding(8)
                        .background(.blue.opacity(0.08), in: .rect(cornerRadius: 10))
                    }
                }

                // Route stats
                if viewModel.isLoadingRoute {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Calculating route...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                } else if let minutes = viewModel.estimatedWalkingMinutes,
                          let distance = viewModel.distanceToTarget {
                    HStack(spacing: 16) {
                        routeStat(icon: "figure.walk", value: "\(minutes) min", label: "Walking")
                        Divider().frame(height: 36)
                        routeStat(
                            icon: "mappin.and.ellipse",
                            value: distance < 1000 ? "\(Int(distance))m" : String(format: "%.1fkm", distance / 1000),
                            label: "Distance"
                        )
                        Divider().frame(height: 36)
                        routeStat(
                            icon: "arrow.up.to.line",
                            value: target.floor.map { $0 == 0 ? "Ground" : "Floor \($0)" } ?? "N/A",
                            label: "Floor"
                        )
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                } else if let error = viewModel.routeError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08), in: .rect(cornerRadius: 12))
                }

                // Directions button
                Button {
                    viewModel.openInMaps()
                } label: {
                    Label("Open in Apple Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens Apple Maps with walking directions")

            } else {
                // No target selected
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Select a Classroom")
                        .font(.headline)
                    Text("Tap a location on the map or use \"Next Class\" to find your classroom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Quick pick list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.allLocations.filter { $0.type == .classroom || $0.type == .lab }) { location in
                                Button {
                                    viewModel.selectLocation(location)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: location.type.systemImage)
                                            .font(.caption2)
                                        Text(location.roomNumber)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.courseColor(location.type.tintColor).opacity(0.12), in: Capsule())
                                    .foregroundStyle(Theme.courseColor(location.type.tintColor))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(location.name), room \(location.roomNumber)")
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func routeStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClassroomFinderView(courses: [])
    }
}
