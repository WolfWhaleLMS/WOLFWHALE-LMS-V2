import SwiftUI
import RealityKit
import ARKit

struct HumanCellARView: View {
    @State private var selectedOrganelleName: String?
    @State private var selectedOrganelleInfo: String?
    @State private var selectedOrganelleFact: String?
    @State private var isPlaced = false

    var body: some View {
        ZStack {
            HumanCellARContainer(
                selectedOrganelleName: $selectedOrganelleName,
                selectedOrganelleInfo: $selectedOrganelleInfo,
                selectedOrganelleFact: $selectedOrganelleFact,
                isPlaced: $isPlaced
            )
            .ignoresSafeArea()

            VStack {
                if !isPlaced {
                    instructionBanner
                }
                Spacer()
                if let name = selectedOrganelleName {
                    organelleInfoCard(name: name)
                }
            }
            .padding()
        }
    }

    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title3)
            Text("Tap a surface to place the cell")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    private func organelleInfoCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedOrganelleName = nil
                        selectedOrganelleInfo = nil
                        selectedOrganelleFact = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if let info = selectedOrganelleInfo {
                Text(info)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            if let fact = selectedOrganelleFact {
                Label(fact, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct HumanCellARContainer: UIViewRepresentable {
    @Binding var selectedOrganelleName: String?
    @Binding var selectedOrganelleInfo: String?
    @Binding var selectedOrganelleFact: String?
    @Binding var isPlaced: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.topAnchor.constraint(equalTo: arView.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
            coaching.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: arView.trailingAnchor)
        ])

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedOrganelleName: $selectedOrganelleName,
            selectedOrganelleInfo: $selectedOrganelleInfo,
            selectedOrganelleFact: $selectedOrganelleFact,
            isPlaced: $isPlaced
        )
    }

    class Coordinator: NSObject {
        weak var arView: ARView?
        var cellAnchor: AnchorEntity?
        var organelleEntities: [String: ModelEntity] = [:]
        var labelEntities: [String: Entity] = [:]

        var selectedOrganelleName: Binding<String?>
        var selectedOrganelleInfo: Binding<String?>
        var selectedOrganelleFact: Binding<String?>
        var isPlaced: Binding<Bool>

        init(
            selectedOrganelleName: Binding<String?>,
            selectedOrganelleInfo: Binding<String?>,
            selectedOrganelleFact: Binding<String?>,
            isPlaced: Binding<Bool>
        ) {
            self.selectedOrganelleName = selectedOrganelleName
            self.selectedOrganelleInfo = selectedOrganelleInfo
            self.selectedOrganelleFact = selectedOrganelleFact
            self.isPlaced = isPlaced
        }

        @MainActor
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = sender.location(in: arView)

            if let entity = arView.entity(at: location),
               let name = findOrganelleName(for: entity) {
                selectOrganelle(named: name)
                return
            }

            guard cellAnchor == nil else { return }

            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            guard let result = results.first else { return }

            placeCell(at: result.worldTransform, in: arView)
        }

        @MainActor
        private func findOrganelleName(for entity: Entity) -> String? {
            for (name, organelleEntity) in organelleEntities {
                if entity == organelleEntity || entity.parent == organelleEntity || organelleEntity.children.contains(where: { $0 == entity }) {
                    return name
                }
            }
            return nil
        }

        @MainActor
        private func selectOrganelle(named name: String) {
            guard let organelle = HumanCellData.organelles.first(where: { $0.name == name }) else { return }

            Task { @MainActor in
                selectedOrganelleName.wrappedValue = organelle.name
                selectedOrganelleInfo.wrappedValue = organelle.description
                selectedOrganelleFact.wrappedValue = organelle.funFact
            }

            for (entityName, labelEntity) in labelEntities {
                labelEntity.isEnabled = entityName == name
            }
        }

        @MainActor
        private func placeCell(at worldTransform: simd_float4x4, in arView: ARView) {
            let anchor = AnchorEntity(world: worldTransform)
            let cellRoot = Entity()
            cellRoot.name = "cellRoot"

            let membraneMesh = MeshResource.generateSphere(radius: 0.08)
            var membraneMaterial = PhysicallyBasedMaterial()
            membraneMaterial.baseColor = .init(tint: UIColor(red: 0.5, green: 0.78, blue: 0.52, alpha: 0.25))
            membraneMaterial.roughness = .init(floatLiteral: 0.1)
            membraneMaterial.metallic = .init(floatLiteral: 0.0)
            membraneMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.25))
            let membrane = ModelEntity(mesh: membraneMesh, materials: [membraneMaterial])
            membrane.name = "Cell Membrane"
            membrane.generateCollisionShapes(recursive: false)
            cellRoot.addChild(membrane)
            organelleEntities["Cell Membrane"] = membrane

            for organelle in HumanCellData.organelles where organelle.name != "Cell Membrane" {
                let entity = createOrganelleEntity(organelle)
                entity.name = organelle.name
                entity.position = organelle.relativePosition
                entity.generateCollisionShapes(recursive: true)
                cellRoot.addChild(entity)
                organelleEntities[organelle.name] = entity

                let label = createLabel(for: organelle)
                label.isEnabled = false
                entity.addChild(label)
                labelEntities[organelle.name] = label
            }

            let membraneLabel = createLabel(for: HumanCellData.organelles.first(where: { $0.name == "Cell Membrane" })!)
            membraneLabel.isEnabled = false
            membraneLabel.position = SIMD3<Float>(0, 0.1, 0)
            membrane.addChild(membraneLabel)
            labelEntities["Cell Membrane"] = membraneLabel

            cellRoot.generateCollisionShapes(recursive: true)

            arView.installGestures([.rotation, .scale], for: membrane)

            anchor.addChild(cellRoot)
            arView.scene.addAnchor(anchor)
            cellAnchor = anchor

            Task { @MainActor in
                isPlaced.wrappedValue = true
            }
        }

        @MainActor
        private func createOrganelleEntity(_ organelle: CellOrganelle) -> ModelEntity {
            let color = UIColor(
                red: CGFloat((organelle.colorHex >> 16) & 0xFF) / 255.0,
                green: CGFloat((organelle.colorHex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(organelle.colorHex & 0xFF) / 255.0,
                alpha: 1.0
            )

            let material = SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)

            let mesh: MeshResource
            switch organelle.shape {
            case .sphere:
                mesh = .generateSphere(radius: organelle.size.x)
            case .ellipsoid:
                mesh = .generateSphere(radius: 0.01)
            case .cylinder:
                mesh = .generateCylinder(height: organelle.size.y, radius: organelle.size.x / 2)
            case .flatDisc:
                mesh = .generateCylinder(height: 0.003, radius: organelle.size.x / 2)
            case .tinyDots:
                mesh = .generateSphere(radius: organelle.size.x)
            }

            let entity = ModelEntity(mesh: mesh, materials: [material])

            if organelle.shape == .ellipsoid {
                entity.scale = SIMD3<Float>(
                    organelle.size.x / 0.01,
                    organelle.size.y / 0.01,
                    organelle.size.z / 0.01
                )
            }

            if organelle.name == "Nucleus" {
                let nucleolusMesh = MeshResource.generateSphere(radius: organelle.size.x * 0.35)
                let nucleolusMaterial = SimpleMaterial(color: UIColor(red: 0.25, green: 0.28, blue: 0.55, alpha: 1.0), roughness: 0.3, isMetallic: false)
                let nucleolus = ModelEntity(mesh: nucleolusMesh, materials: [nucleolusMaterial])
                nucleolus.position = SIMD3<Float>(0.005, 0.005, 0)
                entity.addChild(nucleolus)
            }

            if organelle.name == "Ribosome" {
                for i in 0..<8 {
                    let angle = Float(i) * (.pi * 2 / 8)
                    let radius: Float = 0.012
                    let dot = ModelEntity(
                        mesh: .generateSphere(radius: 0.003),
                        materials: [material]
                    )
                    dot.position = SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
                    entity.addChild(dot)
                }
            }

            if organelle.name == "Golgi Apparatus" {
                for i in 1..<4 {
                    let disc = ModelEntity(
                        mesh: .generateCylinder(height: 0.002, radius: organelle.size.x / 2 - Float(i) * 0.002),
                        materials: [material]
                    )
                    disc.position = SIMD3<Float>(0, Float(i) * 0.004, 0)
                    entity.addChild(disc)
                }
            }

            if organelle.name == "Mitochondria" {
                let innerMesh = MeshResource.generateSphere(radius: 0.006)
                var innerMaterial = SimpleMaterial()
                innerMaterial.color = .init(tint: UIColor(red: 0.75, green: 0.2, blue: 0.2, alpha: 0.8))
                innerMaterial.roughness = .float(0.5)
                let inner = ModelEntity(mesh: innerMesh, materials: [innerMaterial])
                inner.scale = SIMD3<Float>(1.8, 0.8, 0.8)
                entity.addChild(inner)
            }

            return entity
        }

        @MainActor
        private func createLabel(for organelle: CellOrganelle) -> Entity {
            let labelRoot = Entity()

            let textMesh = MeshResource.generateText(
                organelle.name,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.008, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textMaterial = UnlitMaterial(color: .white)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

            let bgMesh = MeshResource.generatePlane(width: 0.06, depth: 0.015)
            let bgColor = UIColor(
                red: CGFloat((organelle.colorHex >> 16) & 0xFF) / 255.0,
                green: CGFloat((organelle.colorHex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(organelle.colorHex & 0xFF) / 255.0,
                alpha: 0.85
            )
            let bgMaterial = UnlitMaterial(color: bgColor)
            let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])

            labelRoot.addChild(bgEntity)
            labelRoot.addChild(textEntity)

            textEntity.position = SIMD3<Float>(-0.025, 0.001, 0.003)
            labelRoot.position = SIMD3<Float>(0, organelle.size.y + 0.02, 0)

            return labelRoot
        }
    }
}
