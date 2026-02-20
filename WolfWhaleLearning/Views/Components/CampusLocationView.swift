import SwiftUI
import CoreLocation

struct CampusLocationView: View {
    @StateObject private var geoService = GeoFenceService()
    @State private var appeared = false
    @State private var radarAngle: Double = 0
    @State private var hapticTrigger = false

    /// Whether to show a compact version suitable for embedding
    var isCompact = false

    var body: some View {
        if isCompact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Full View

    private var fullView: some View {
        VStack(spacing: 24) {
            // Campus visualization
            campusVisualization
                .frame(height: 260)

            // Status card
            statusCard

            // Distance info
            distanceCard

            // Permission button if needed
            if geoService.authorizationStatus == .notDetermined {
                permissionButton
            } else if geoService.authorizationStatus == .denied ||
                      geoService.authorizationStatus == .restricted {
                permissionDeniedNotice
            }
        }
        .onAppear {
            geoService.requestPermission()
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                radarAngle = 360
            }
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            geoService.stopMonitoring()
        }
    }

    // MARK: - Compact View (for embedding)

    private var compactView: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(statusColor.gradient)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: geoService.isOnCampus ? "checkmark" : "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(geoService.isOnCampus ? "On Campus" : "Off Campus")
                    .font(.subheadline.bold())
                    .foregroundStyle(statusColor)

                Text(distanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "location.fill")
                .font(.subheadline)
                .foregroundStyle(statusColor)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .onAppear {
            geoService.requestPermission()
        }
        .onDisappear {
            geoService.stopMonitoring()
        }
    }

    // MARK: - Campus Visualization

    private var campusVisualization: some View {
        ZStack {
            // Background circles (campus zones)
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .stroke(
                        statusColor.opacity(0.08 + Double(ring) * 0.04),
                        lineWidth: 1
                    )
                    .frame(
                        width: CGFloat(60 + ring * 50),
                        height: CGFloat(60 + ring * 50)
                    )
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(
                        .spring(duration: 0.8, bounce: 0.3).delay(Double(ring) * 0.1),
                        value: appeared
                    )
            }

            // Radar sweep
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    AngularGradient(
                        colors: [statusColor.opacity(0.4), statusColor.opacity(0)],
                        center: .center
                    ),
                    lineWidth: 80
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(radarAngle))

            // Campus boundary circle
            Circle()
                .stroke(statusColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 180, height: 180)

            // Campus center marker
            VStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.title3)
                    .foregroundStyle(statusColor)
                Text("Campus")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            // User position indicator
            userPositionDot
                .offset(userOffset)
                .animation(.spring(duration: 0.6), value: geoService.distanceFromCampus)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(geoService.isOnCampus
            ? "Campus map showing you are on campus"
            : "Campus map showing you are \(distanceText) from campus")
    }

    private var userPositionDot: some View {
        ZStack {
            // Pulse ring
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)
                .scaleEffect(appeared ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: appeared
                )

            // Dot
            Circle()
                .fill(.blue.gradient)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                }
                .shadow(color: .blue.opacity(0.4), radius: 4, y: 2)
        }
    }

    /// Offset the user dot based on distance from campus center.
    /// When on campus, the dot is near the center; when off campus, it moves to the edge.
    private var userOffset: CGSize {
        let maxOffset: CGFloat = 100
        let normalized = min(geoService.distanceFromCampus / max(geoService.campusRadius * 2, 1), 1.0)
        let offset = CGFloat(normalized) * maxOffset
        return CGSize(width: offset * 0.7, height: -offset * 0.5)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: geoService.isOnCampus ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.bounce, value: geoService.isOnCampus)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(geoService.isOnCampus ? "You are on campus" : "You are off campus")
                    .font(.headline)

                Text(geoService.isOnCampus
                    ? "Your location has been verified"
                    : "Move closer to campus to check in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Distance Card

    private var distanceCard: some View {
        HStack(spacing: 16) {
            distanceStatItem(
                icon: "mappin.and.ellipse",
                value: distanceText,
                label: "From Campus",
                color: .blue
            )

            Divider()
                .frame(height: 40)

            distanceStatItem(
                icon: "circle.dashed",
                value: "\(Int(geoService.campusRadius))m",
                label: "Campus Radius",
                color: .purple
            )

            Divider()
                .frame(height: 40)

            distanceStatItem(
                icon: "location.fill",
                value: locationAccuracyText,
                label: "Status",
                color: statusColor
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func distanceStatItem(icon: String, value: String, label: String, color: Color) -> some View {
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

    // MARK: - Permission Controls

    private var permissionButton: some View {
        Button {
            hapticTrigger.toggle()
            geoService.requestPermission()
        } label: {
            Label("Enable Location Services", systemImage: "location.fill")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .tint(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var permissionDeniedNotice: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Text("Location Access Denied")
                .font(.subheadline.bold())
            Text("Enable location in Settings > Privacy > Location Services to use campus verification.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        geoService.isOnCampus ? .green : .red
    }

    private var distanceText: String {
        let distance = geoService.distanceFromCampus
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    private var locationAccuracyText: String {
        switch geoService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            geoService.currentLocation != nil ? "Active" : "Locating"
        case .denied, .restricted:
            "Denied"
        default:
            "Pending"
        }
    }
}
