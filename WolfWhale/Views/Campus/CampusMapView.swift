import SwiftUI
import MapKit
import CoreLocation

// MARK: - View Model

@Observable
@MainActor
final class CampusMapViewModel: NSObject, CLLocationManagerDelegate {
    var locations: [CampusLocation] = CampusLocation.mockLocations
    var selectedLocation: CampusLocation?
    var searchText = ""
    var selectedType: CampusLocationType?
    var mapStyle: MapStyleOption = .standard
    var userLocation: CLLocationCoordinate2D?
    var cameraPosition: MapCameraPosition = .automatic
    var showDetail = false

    private let locationManager = CLLocationManager()

    var filteredLocations: [CampusLocation] {
        locations.filter { location in
            let matchesType = selectedType == nil || location.type == selectedType
            let matchesSearch = searchText.isEmpty ||
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.buildingName.localizedCaseInsensitiveContains(searchText) ||
                location.roomNumber.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stopLocation() {
        locationManager.stopUpdatingLocation()
    }

    func zoomToFitAll() {
        cameraPosition = .automatic
    }

    func zoomToLocation(_ location: CampusLocation) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        )
    }

    func openInMaps(_ location: CampusLocation) {
        let destination = MKMapItem(location: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), address: nil)
        destination.name = location.name
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

// MARK: - Map Style

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"

    var id: String { rawValue }
}

// MARK: - Campus Map View

struct CampusMapView: View {
    @State private var viewModel = CampusMapViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            mapContent

            VStack(spacing: 0) {
                searchBar
                filterBar
            }
        }
        .sheet(isPresented: $viewModel.showDetail) {
            if let location = viewModel.selectedLocation {
                LocationDetailSheet(location: location, viewModel: viewModel)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationTitle("Campus Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Map Style", selection: $viewModel.mapStyle) {
                        ForEach(MapStyleOption.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                } label: {
                    Image(systemName: "map.fill")
                        .font(.subheadline)
                }
                .accessibilityLabel("Map style")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.zoomToFitAll()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline)
                }
                .accessibilityLabel("Zoom to fit all locations")
            }
        }
        .onAppear {
            viewModel.requestLocation()
        }
        .onDisappear {
            viewModel.stopLocation()
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $viewModel.cameraPosition) {
            // User location
            UserAnnotation()

            // Campus location annotations
            ForEach(viewModel.filteredLocations) { location in
                Annotation(
                    location.name,
                    coordinate: location.coordinate,
                    anchor: .bottom
                ) {
                    CampusAnnotationView(location: location, isSelected: viewModel.selectedLocation?.id == location.id)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                viewModel.selectedLocation = location
                                viewModel.showDetail = true
                                viewModel.zoomToLocation(location)
                            }
                        }
                }
            }
        }
        .mapStyle(resolvedMapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var resolvedMapStyle: MapStyle {
        switch viewModel.mapStyle {
        case .standard: .standard
        case .satellite: .imagery
        case .hybrid: .hybrid
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search buildings, rooms...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: viewModel.selectedType == nil) {
                    withAnimation { viewModel.selectedType = nil }
                }

                ForEach(CampusLocationType.allCases) { type in
                    FilterChip(
                        title: type.displayName,
                        systemImage: type.systemImage,
                        isSelected: viewModel.selectedType == type
                    ) {
                        withAnimation {
                            viewModel.selectedType = viewModel.selectedType == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Annotation View

private struct CampusAnnotationView: View {
    let location: CampusLocation
    let isSelected: Bool

    private var color: Color {
        Theme.courseColor(location.type.tintColor)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: isSelected ? 42 : 36, height: isSelected ? 42 : 36)
                    .shadow(color: color.opacity(0.4), radius: isSelected ? 6 : 3, y: 2)

                Image(systemName: location.type.systemImage)
                    .font(isSelected ? .subheadline.bold() : .caption.bold())
                    .foregroundStyle(.white)
            }

            // Pin tail
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .offset(y: -4)
        }
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel("\(location.name), \(location.type.displayName)")
        .accessibilityHint("Tap to view details")
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.systemGray5), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Location Detail Sheet

private struct LocationDetailSheet: View {
    let location: CampusLocation
    let viewModel: CampusMapViewModel
    @Environment(\.dismiss) private var dismiss

    private var color: Color {
        Theme.courseColor(location.type.tintColor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: location.type.systemImage)
                            .font(.title2)
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.headline)
                        Text(location.buildingName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Info grid
                HStack(spacing: 16) {
                    infoItem(icon: "door.left.hand.open", label: "Room", value: location.roomNumber)
                    Divider().frame(height: 40)
                    infoItem(icon: "tag.fill", label: "Type", value: location.type.displayName)
                    Divider().frame(height: 40)
                    infoItem(
                        icon: "arrow.up.to.line",
                        label: "Floor",
                        value: location.floor.map { $0 == 0 ? "Ground" : "Floor \($0)" } ?? "N/A"
                    )
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                // Walking info
                if let userCoord = viewModel.userLocation {
                    let userLoc = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
                    let destLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let distance = userLoc.distance(from: destLoc)
                    let walkingMinutes = max(1, Int(distance / 80)) // ~80m per minute walking

                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("~\(walkingMinutes) min walk")
                                .font(.subheadline.bold())
                            Text("\(Int(distance))m from your location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.blue.opacity(0.08), in: .rect(cornerRadius: 14))
                }

                // Directions button
                Button {
                    viewModel.openInMaps(location)
                } label: {
                    Label("Get Walking Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens Apple Maps with walking directions")

                Spacer()
            }
            .padding(20)
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
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
        CampusMapView()
    }
}
