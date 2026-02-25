import Foundation
import CoreLocation

// MARK: - Location Type

nonisolated enum CampusLocationType: String, CaseIterable, Codable, Identifiable, Sendable {
    case classroom
    case library
    case gym
    case cafeteria
    case office
    case lab
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classroom: "Classroom"
        case .library: "Library"
        case .gym: "Gymnasium"
        case .cafeteria: "Cafeteria"
        case .office: "Office"
        case .lab: "Lab"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .classroom: "building.2.fill"
        case .library: "books.vertical.fill"
        case .gym: "figure.run"
        case .cafeteria: "fork.knife"
        case .office: "person.crop.rectangle.fill"
        case .lab: "flask.fill"
        case .other: "mappin.circle.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .classroom: "blue"
        case .library: "purple"
        case .gym: "orange"
        case .cafeteria: "green"
        case .office: "indigo"
        case .lab: "teal"
        case .other: "gray"
        }
    }
}

// MARK: - Campus Location

nonisolated struct CampusLocation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var buildingName: String
    var roomNumber: String
    var latitude: Double
    var longitude: Double
    var type: CampusLocationType
    var floor: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Codable conformance for CLLocationCoordinate2D is handled via lat/lon properties.

    static func == (lhs: CampusLocation, rhs: CampusLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Mock Campus Locations
// Coordinates clustered around University of Toronto area (43.6629, -79.3957)

extension CampusLocation {
    static let mockLocations: [CampusLocation] = [
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000001") ?? UUID(),
            name: "Canadian History Lecture Hall",
            buildingName: "Heritage Hall",
            roomNumber: "HH-101",
            latitude: 43.6629,
            longitude: -79.3957,
            type: .classroom,
            floor: 1
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000002") ?? UUID(),
            name: "Main Library",
            buildingName: "Wolfe Learning Centre",
            roomNumber: "WLC-200",
            latitude: 43.6635,
            longitude: -79.3945,
            type: .library,
            floor: 2
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000003") ?? UUID(),
            name: "Whale Fitness Centre",
            buildingName: "Athletics Complex",
            roomNumber: "AC-G01",
            latitude: 43.6622,
            longitude: -79.3970,
            type: .gym,
            floor: 0
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000004") ?? UUID(),
            name: "The Orca Cafe",
            buildingName: "Student Commons",
            roomNumber: "SC-100",
            latitude: 43.6640,
            longitude: -79.3960,
            type: .cafeteria,
            floor: 1
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000005") ?? UUID(),
            name: "Science Lab",
            buildingName: "Newton Building",
            roomNumber: "NB-305",
            latitude: 43.6618,
            longitude: -79.3940,
            type: .lab,
            floor: 3
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000006") ?? UUID(),
            name: "Math & Computing Room",
            buildingName: "Euler Centre",
            roomNumber: "EC-210",
            latitude: 43.6625,
            longitude: -79.3935,
            type: .classroom,
            floor: 2
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000007") ?? UUID(),
            name: "Guidance Office",
            buildingName: "Admin Building",
            roomNumber: "AB-102",
            latitude: 43.6645,
            longitude: -79.3950,
            type: .office,
            floor: 1
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000008") ?? UUID(),
            name: "Art Studio",
            buildingName: "Creative Arts Wing",
            roomNumber: "CA-115",
            latitude: 43.6632,
            longitude: -79.3975,
            type: .classroom,
            floor: 1
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-000000000009") ?? UUID(),
            name: "Chemistry Lab",
            buildingName: "Newton Building",
            roomNumber: "NB-310",
            latitude: 43.6619,
            longitude: -79.3942,
            type: .lab,
            floor: 3
        ),
        CampusLocation(
            id: UUID(uuidString: "A0000001-0001-0001-0001-00000000000A") ?? UUID(),
            name: "Principal's Office",
            buildingName: "Admin Building",
            roomNumber: "AB-001",
            latitude: 43.6646,
            longitude: -79.3952,
            type: .office,
            floor: 0
        )
    ]

    /// Center coordinate of the mock campus (average of all locations).
    static var campusCenter: CLLocationCoordinate2D {
        let lats = mockLocations.map(\.latitude)
        let lons = mockLocations.map(\.longitude)
        return CLLocationCoordinate2D(
            latitude: lats.reduce(0, +) / Double(lats.count),
            longitude: lons.reduce(0, +) / Double(lons.count)
        )
    }
}
