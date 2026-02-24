import SwiftUI

struct ARExperienceView: View {
    let resource: ARResource
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                #if targetEnvironment(simulator)
                ARSimulatorPlaceholderView(resource: resource)
                #else
                realARView
                #endif
            }

            Button {
                hapticTrigger.toggle()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(16)
            }
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
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
    @State private var hapticTrigger = false

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

    private func organelleByName(_ name: String) -> CellOrganelle? {
        organelles.first(where: { $0.name == name })
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
                .stroke(Color(hex: 0xFFE082), lineWidth: 3)
                .frame(width: 280, height: 240)

            if let o = organelleByName("Nucleus") { organelleDot(organelle: o, x: 0, y: 0, size: 60) }
            if let o = organelleByName("Nucleolus") { organelleDot(organelle: o, x: 5, y: 5, size: 18) }
            if let o = organelleByName("Mitochondria") { organelleDot(organelle: o, x: -70, y: -30, size: 28) }
            if let o = organelleByName("Rough Endoplasmic Reticulum") { organelleDot(organelle: o, x: 55, y: -15, size: 28) }
            if let o = organelleByName("Smooth Endoplasmic Reticulum") { organelleDot(organelle: o, x: -60, y: 20, size: 24) }
            if let o = organelleByName("Golgi Apparatus") { organelleDot(organelle: o, x: -50, y: 55, size: 35) }
            if let o = organelleByName("Cell Membrane") { organelleDot(organelle: o, x: 110, y: -80, size: 20) }
            if let o = organelleByName("Lysosomes") { organelleDot(organelle: o, x: 85, y: 10, size: 18) }
            if let o = organelleByName("Vacuoles") { organelleDot(organelle: o, x: 40, y: 60, size: 22) }
            if let o = organelleByName("Centrioles") { organelleDot(organelle: o, x: -25, y: -65, size: 16) }
            if let o = organelleByName("Peroxisomes") { organelleDot(organelle: o, x: 75, y: -50, size: 12) }

            // Scattered ribosome dots
            ForEach([CGPoint(x: -100, y: -60), CGPoint(x: 80, y: -70), CGPoint(x: -80, y: 70), CGPoint(x: 100, y: 60), CGPoint(x: -20, y: 90)], id: \.x) { point in
                Circle()
                    .fill(Color(hex: 0x4A148C).opacity(0.5))
                    .frame(width: 5, height: 5)
                    .offset(x: point.x, y: point.y)
            }
        }
    }

    private func organelleDot(organelle: CellOrganelle, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Button {
            hapticTrigger.toggle()
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
                    hapticTrigger.toggle()
                    withAnimation(.spring(response: 0.3)) {
                        selectedOrganelle = selectedOrganelle == organelle ? nil : organelle
                    }
                } label: {
                    organelleRow(organelle)
                }
                .buttonStyle(.plain)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
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
        case "Nucleolus": return "circle.inset.filled"
        case "Nuclear Envelope": return "circle.dashed"
        case "Mitochondria": return "bolt.fill"
        case "Rough Endoplasmic Reticulum": return "wave.3.right"
        case "Smooth Endoplasmic Reticulum": return "wave.3.left"
        case "Golgi Apparatus": return "tray.full.fill"
        case "Cell Membrane": return "circle"
        case "Ribosomes": return "circle.grid.3x3.fill"
        case "Lysosomes": return "drop.fill"
        case "Vacuoles": return "drop.circle.fill"
        case "Centrioles": return "target"
        case "Peroxisomes": return "smallcircle.filled.circle"
        case "Cytoplasm": return "drop"
        default: return "circle.fill"
        }
    }
}

// Color(hex:) extension is now in Utilities/Color+Hex.swift
