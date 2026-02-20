import SwiftUI

struct ARExperienceView: View {
    let resource: ARResource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                #if targetEnvironment(simulator)
                ARSimulatorPlaceholderView(resource: resource)
                #else
                realARView
                #endif
            }
            .navigationTitle(resource.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var realARView: some View {
        switch resource.experienceType {
        case .humanCell:
            HumanCellARView()
        case .placeholder:
            ARSimulatorPlaceholderView(resource: resource)
        }
    }
}

struct ARSimulatorPlaceholderView: View {
    let resource: ARResource
    @State private var selectedOrganelle: CellOrganelle?
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0

    private let organelles = HumanCellData.organelles

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                arPlaceholderCard
                interactivePreview
                organellesList
            }
            .padding()
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var arPlaceholderCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "arkit")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)

            Text("AR Experience Preview")
                .font(.title2.bold())

            Text("Install this app on your device\nvia the Rork App for the full AR experience.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label("Tap to Place", systemImage: "hand.tap.fill")
                Label("Pinch to Scale", systemImage: "arrow.up.left.and.arrow.down.right")
                Label("Rotate", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private var interactivePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cell Structure Preview")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 300)

                cellDiagram
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotationAngle))
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = min(max(value.magnification, 0.5), 2.5)
                            }
                    )
                    .gesture(
                        RotateGesture()
                            .onChanged { value in
                                rotationAngle = value.rotation.degrees
                            }
                    )
            }
            .clipShape(.rect(cornerRadius: 20))

            Text("Pinch to zoom, rotate to examine")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var cellDiagram: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xE8F5E9).opacity(0.6), Color(hex: 0xA5D6A7).opacity(0.3)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 240)

            Ellipse()
                .stroke(Color(hex: 0x66BB6A), lineWidth: 3)
                .frame(width: 280, height: 240)

            organelleDot(organelle: organelles[0], x: 0, y: 0, size: 60)
            organelleDot(organelle: organelles[1], x: -70, y: -30, size: 28)
            organelleDot(organelle: organelles[2], x: 70, y: -40, size: 28)
            organelleDot(organelle: organelles[3], x: -50, y: 50, size: 35)
            organelleDot(organelle: organelles[4], x: 60, y: 50, size: 32)
            organelleDot(organelle: organelles[5], x: -90, y: 10, size: 22)
            organelleDot(organelle: organelles[6], x: 95, y: 0, size: 20)
            organelleDot(organelle: organelles[7], x: -30, y: -70, size: 24)
            organelleDot(organelle: organelles[8], x: 30, y: 75, size: 18)

            ForEach([CGPoint(x: -100, y: -60), CGPoint(x: 80, y: -70), CGPoint(x: -80, y: 70), CGPoint(x: 100, y: 60), CGPoint(x: -20, y: 90)], id: \.x) { point in
                Circle()
                    .fill(Color(hex: 0x795548).opacity(0.5))
                    .frame(width: 5, height: 5)
                    .offset(x: point.x, y: point.y)
            }
        }
    }

    private func organelleDot(organelle: CellOrganelle, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedOrganelle = selectedOrganelle == organelle ? nil : organelle
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: organelle.colorHex).opacity(0.7))
                    .frame(width: size, height: size)

                if organelle.shape == .sphere && size > 40 {
                    Circle()
                        .fill(Color(hex: organelle.colorHex).opacity(0.9))
                        .frame(width: size * 0.5, height: size * 0.5)
                }

                if selectedOrganelle == organelle {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: size + 6, height: size + 6)
                }
            }
        }
        .offset(x: x, y: y)
    }

    private var organellesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cell Organelles")
                .font(.headline)

            ForEach(organelles) { organelle in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedOrganelle = selectedOrganelle == organelle ? nil : organelle
                    }
                } label: {
                    organelleRow(organelle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func organelleRow(_ organelle: CellOrganelle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: organelle.colorHex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: iconForOrganelle(organelle.name))
                            .font(.caption)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(organelle.name)
                        .font(.subheadline.bold())
                    Text(organelle.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(selectedOrganelle == organelle ? nil : 2)
                }

                Spacer()

                Image(systemName: selectedOrganelle == organelle ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if selectedOrganelle == organelle {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)
                    Label(organelle.funFact, systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 10))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    private func iconForOrganelle(_ name: String) -> String {
        switch name {
        case "Nucleus": return "circle.fill"
        case "Mitochondria": return "bolt.fill"
        case "Endoplasmic Reticulum": return "wave.3.right"
        case "Golgi Apparatus": return "tray.full.fill"
        case "Cell Membrane": return "circle"
        case "Ribosome": return "circle.grid.3x3.fill"
        case "Lysosome": return "drop.fill"
        case "Vacuole": return "drop.circle.fill"
        case "Centrosome": return "target"
        default: return "circle.fill"
        }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
