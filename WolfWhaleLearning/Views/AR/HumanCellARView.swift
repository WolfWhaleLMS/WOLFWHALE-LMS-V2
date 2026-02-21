import SwiftUI
import RealityKit
import ARKit

// MARK: - SwiftUI Wrapper View

struct HumanCellARView: View {
    @State private var selectedOrganelleName: String?
    @State private var selectedOrganelleInfo: String?
    @State private var selectedOrganelleFact: String?
    @State private var isPlaced = false
    @State private var arView: ARView?
    @State private var hapticTrigger = false

    var body: some View {
        ZStack {
            HumanCellARContainer(
                selectedOrganelleName: $selectedOrganelleName,
                selectedOrganelleInfo: $selectedOrganelleInfo,
                selectedOrganelleFact: $selectedOrganelleFact,
                isPlaced: $isPlaced,
                arViewRef: $arView
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
        .onDisappear {
            arView?.session.pause()
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
                    hapticTrigger.toggle()
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
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
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

// MARK: - AR Container (UIViewRepresentable)

struct HumanCellARContainer: UIViewRepresentable {
    @Binding var selectedOrganelleName: String?
    @Binding var selectedOrganelleInfo: String?
    @Binding var selectedOrganelleFact: String?
    @Binding var isPlaced: Bool
    @Binding var arViewRef: ARView?

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

        Task { @MainActor in
            arViewRef = arView
        }

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

    // MARK: - Coordinator

    class Coordinator: NSObject {
        weak var arView: ARView?
        var cellAnchor: AnchorEntity?
        var organelleEntities: [String: Entity] = [:]
        var labelEntities: [String: Entity] = [:]
        var rotationTimer: Timer?

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

        deinit {
            rotationTimer?.invalidate()
        }

        // MARK: Tap Handling

        @MainActor
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = sender.location(in: arView)

            // Check if tapping an organelle
            if let entity = arView.entity(at: location),
               let name = findOrganelleName(for: entity) {
                selectOrganelle(named: name)
                return
            }

            // Place cell on first tap
            guard cellAnchor == nil else { return }

            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            guard let result = results.first else { return }

            placeCell(at: result.worldTransform, in: arView)
        }

        @MainActor
        private func findOrganelleName(for entity: Entity) -> String? {
            // Walk up the hierarchy to find a named organelle
            var current: Entity? = entity
            while let e = current {
                if let name = organelleEntities.first(where: { _, value in
                    value === e
                })?.key {
                    return name
                }
                // Also check if entity is a child of any registered organelle
                for (name, orgEntity) in organelleEntities {
                    if isDescendant(entity: e, of: orgEntity) {
                        return name
                    }
                }
                current = e.parent
            }
            return nil
        }

        private func isDescendant(entity: Entity, of ancestor: Entity) -> Bool {
            var current: Entity? = entity
            while let e = current {
                if e === ancestor { return true }
                current = e.parent
            }
            return false
        }

        @MainActor
        private func selectOrganelle(named name: String) {
            guard let organelle = HumanCellData.organelles.first(where: { $0.name == name }) else { return }

            Task { @MainActor in
                selectedOrganelleName.wrappedValue = organelle.name
                selectedOrganelleInfo.wrappedValue = organelle.description
                selectedOrganelleFact.wrappedValue = organelle.funFact
            }

            // Show only the selected label
            for (entityName, labelEntity) in labelEntities {
                labelEntity.isEnabled = entityName == name
            }
        }

        // MARK: - Cell Placement

        @MainActor
        private func placeCell(at worldTransform: simd_float4x4, in arView: ARView) {
            let anchor = AnchorEntity(world: worldTransform)
            let cellRoot = buildDetailedHumanCell()
            cellRoot.name = "cellRoot"

            // Enable collision on the whole tree for tap detection
            cellRoot.generateCollisionShapes(recursive: true)

            // Allow scale and rotation gestures on the membrane (outermost entity)
            if let membrane = organelleEntities["Cell Membrane"] as? ModelEntity {
                arView.installGestures([.rotation, .scale], for: membrane)
            }

            anchor.addChild(cellRoot)
            arView.scene.addAnchor(anchor)
            cellAnchor = anchor

            // Start slow rotation animation
            startRotation(on: cellRoot)

            Task { @MainActor in
                isPlaced.wrappedValue = true
            }
        }

        // MARK: - Rotation Animation

        @MainActor
        private func startRotation(on entity: Entity) {
            // Full 360-degree rotation over 30 seconds, repeating
            let rotation = Transform(rotation: simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(0, 1, 0)))
            entity.move(
                to: rotation,
                relativeTo: entity.parent,
                duration: 30.0,
                timingFunction: .linear
            )

            // Schedule re-trigger after the animation completes
            rotationTimer?.invalidate()
            rotationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self, weak entity] timer in
                guard let coordinator = self, let entity else {
                    // Entity or coordinator deallocated – stop the timer to avoid a leak
                    timer.invalidate()
                    return
                }
                Task { @MainActor in
                    entity.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                    let nextRotation = Transform(rotation: simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(0, 1, 0)))
                    entity.move(
                        to: nextRotation,
                        relativeTo: entity.parent,
                        duration: 30.0,
                        timingFunction: .linear
                    )
                }
                _ = coordinator // silence unused-variable warning
            }
        }

        // MARK: - Build the Detailed Human Cell

        @MainActor
        private func buildDetailedHumanCell() -> Entity {
            let cellRoot = Entity()
            let cellRadius: Float = 0.15

            // ==========================================
            // 1. CELL MEMBRANE - outer boundary
            // ==========================================
            let membraneMesh = MeshResource.generateSphere(radius: cellRadius)
            var membraneMaterial = PhysicallyBasedMaterial()
            membraneMaterial.baseColor = .init(tint: UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.15))
            membraneMaterial.roughness = .init(floatLiteral: 0.1)
            membraneMaterial.metallic = .init(floatLiteral: 0.0)
            membraneMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.15))
            let membrane = ModelEntity(mesh: membraneMesh, materials: [membraneMaterial])
            membrane.name = "Cell Membrane"
            membrane.generateCollisionShapes(recursive: false)
            cellRoot.addChild(membrane)
            organelleEntities["Cell Membrane"] = membrane
            addLabel(named: "Cell Membrane", to: membrane, offset: SIMD3<Float>(0, cellRadius + 0.015, 0))

            // ==========================================
            // 2. CYTOPLASM - translucent interior fill
            // ==========================================
            let cytoplasmRadius: Float = cellRadius * 0.93
            let cytoplasmMesh = MeshResource.generateSphere(radius: cytoplasmRadius)
            var cytoplasmMaterial = PhysicallyBasedMaterial()
            cytoplasmMaterial.baseColor = .init(tint: UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 0.05))
            cytoplasmMaterial.roughness = .init(floatLiteral: 0.9)
            cytoplasmMaterial.metallic = .init(floatLiteral: 0.0)
            cytoplasmMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.05))
            let cytoplasm = ModelEntity(mesh: cytoplasmMesh, materials: [cytoplasmMaterial])
            cytoplasm.name = "Cytoplasm"
            cellRoot.addChild(cytoplasm)
            organelleEntities["Cytoplasm"] = cytoplasm
            addLabel(named: "Cytoplasm", to: cytoplasm, offset: SIMD3<Float>(0.08, -0.08, 0))

            // ==========================================
            // 3. NUCLEUS - large sphere, slightly off-center
            // ==========================================
            let nucleusRadius: Float = cellRadius * 0.30
            let nucleusEntity = Entity()
            nucleusEntity.name = "Nucleus"
            nucleusEntity.position = SIMD3<Float>(0.005, 0.005, -0.005)

            // Nuclear envelope (slightly larger, very transparent)
            let envelopeRadius: Float = nucleusRadius * 1.08
            let envelopeMesh = MeshResource.generateSphere(radius: envelopeRadius)
            var envelopeMaterial = PhysicallyBasedMaterial()
            envelopeMaterial.baseColor = .init(tint: UIColor(red: 0.36, green: 0.42, blue: 0.75, alpha: 0.2))
            envelopeMaterial.roughness = .init(floatLiteral: 0.2)
            envelopeMaterial.metallic = .init(floatLiteral: 0.0)
            envelopeMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.2))
            let envelope = ModelEntity(mesh: envelopeMesh, materials: [envelopeMaterial])
            envelope.name = "Nuclear Envelope"
            nucleusEntity.addChild(envelope)
            organelleEntities["Nuclear Envelope"] = envelope

            // Nuclear pores (small torus-like rings on the envelope surface)
            let poreCount = 10
            for i in 0..<poreCount {
                let phi = Float(i) * (.pi * 2.0 / Float(poreCount)) + Float.random(in: -0.2...0.2)
                let theta = Float.random(in: 0.4...2.7) // avoid poles
                let px = envelopeRadius * sin(theta) * cos(phi)
                let py = envelopeRadius * cos(theta)
                let pz = envelopeRadius * sin(theta) * sin(phi)

                // Pore as a small flattened cylinder (ring approximation)
                let poreMesh = MeshResource.generateCylinder(height: 0.001, radius: 0.004)
                var poreMaterial = PhysicallyBasedMaterial()
                poreMaterial.baseColor = .init(tint: UIColor(red: 0.25, green: 0.3, blue: 0.6, alpha: 0.7))
                poreMaterial.roughness = .init(floatLiteral: 0.5)
                poreMaterial.metallic = .init(floatLiteral: 0.0)
                poreMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.7))
                let pore = ModelEntity(mesh: poreMesh, materials: [poreMaterial])
                pore.position = SIMD3<Float>(px, py, pz)
                // Orient pore to face outward from center
                let direction = normalize(SIMD3<Float>(px, py, pz))
                let up = SIMD3<Float>(0, 1, 0)
                let right = normalize(cross(up, direction))
                let correctedUp = cross(direction, right)
                let rotationMatrix = simd_float3x3(columns: (right, direction, correctedUp))
                pore.orientation = simd_quatf(rotationMatrix)
                nucleusEntity.addChild(pore)
            }

            // Nucleus body (semi-transparent deep blue-purple)
            let nucleusMesh = MeshResource.generateSphere(radius: nucleusRadius)
            var nucleusMaterial = PhysicallyBasedMaterial()
            nucleusMaterial.baseColor = .init(tint: UIColor(red: 0.22, green: 0.29, blue: 0.67, alpha: 0.6))
            nucleusMaterial.roughness = .init(floatLiteral: 0.3)
            nucleusMaterial.metallic = .init(floatLiteral: 0.0)
            nucleusMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.6))
            let nucleusBody = ModelEntity(mesh: nucleusMesh, materials: [nucleusMaterial])
            nucleusBody.name = "Nucleus Body"
            nucleusEntity.addChild(nucleusBody)

            // Nucleolus (inside nucleus)
            let nucleolusRadius: Float = nucleusRadius * 0.25
            let nucleolusMesh = MeshResource.generateSphere(radius: nucleolusRadius)
            var nucleolusMaterial = PhysicallyBasedMaterial()
            nucleolusMaterial.baseColor = .init(tint: UIColor(red: 0.42, green: 0.11, blue: 0.6, alpha: 0.85))
            nucleolusMaterial.roughness = .init(floatLiteral: 0.4)
            nucleolusMaterial.metallic = .init(floatLiteral: 0.0)
            nucleolusMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.85))
            let nucleolus = ModelEntity(mesh: nucleolusMesh, materials: [nucleolusMaterial])
            nucleolus.name = "Nucleolus"
            nucleolus.position = SIMD3<Float>(0.008, 0.005, 0.003)
            nucleusEntity.addChild(nucleolus)
            organelleEntities["Nucleolus"] = nucleolus

            cellRoot.addChild(nucleusEntity)
            organelleEntities["Nucleus"] = nucleusEntity
            addLabel(named: "Nucleus", to: nucleusEntity, offset: SIMD3<Float>(0, nucleusRadius + 0.02, 0))
            addLabel(named: "Nucleolus", to: nucleolus, offset: SIMD3<Float>(0, nucleolusRadius + 0.012, 0))
            addLabel(named: "Nuclear Envelope", to: envelope, offset: SIMD3<Float>(envelopeRadius + 0.01, 0, 0))

            // ==========================================
            // 5. ROUGH ENDOPLASMIC RETICULUM
            // ==========================================
            let roughEREntity = Entity()
            roughEREntity.name = "Rough Endoplasmic Reticulum"
            roughEREntity.position = SIMD3<Float>(0.055, -0.005, -0.015)

            let rerColor = UIColor(red: 0.0, green: 0.54, blue: 0.48, alpha: 0.7)
            var rerMaterial = PhysicallyBasedMaterial()
            rerMaterial.baseColor = .init(tint: rerColor)
            rerMaterial.roughness = .init(floatLiteral: 0.5)
            rerMaterial.metallic = .init(floatLiteral: 0.0)
            rerMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.7))

            // 5 stacked curved layers (flattened boxes with corner radius)
            for i in 0..<5 {
                let yOffset = Float(i) * 0.006 - 0.012
                let layerWidth: Float = 0.04 - Float(i) * 0.003
                let layerMesh = MeshResource.generateBox(width: layerWidth, height: 0.002, depth: 0.025, cornerRadius: 0.001)
                let layer = ModelEntity(mesh: layerMesh, materials: [rerMaterial])
                layer.position = SIMD3<Float>(Float(i) * 0.002 - 0.004, yOffset, 0)
                // Slight curvature via rotation
                layer.orientation = simd_quatf(angle: Float(i) * 0.05 - 0.1, axis: SIMD3<Float>(0, 0, 1))
                roughEREntity.addChild(layer)

                // Add ribosomes on the surface of each layer
                let ribosomeMaterial = SimpleMaterial(color: UIColor(red: 0.29, green: 0.08, blue: 0.55, alpha: 1.0), isMetallic: false)
                let ribosomeMesh = MeshResource.generateSphere(radius: 0.0015)
                let ribosomeCount = Int.random(in: 4...6)
                for _ in 0..<ribosomeCount {
                    let rx = Float.random(in: -layerWidth * 0.4...layerWidth * 0.4)
                    let rz = Float.random(in: -0.01...0.01)
                    let ribosome = ModelEntity(mesh: ribosomeMesh, materials: [ribosomeMaterial])
                    ribosome.position = SIMD3<Float>(rx, 0.002, rz)
                    layer.addChild(ribosome)
                }
            }

            cellRoot.addChild(roughEREntity)
            organelleEntities["Rough Endoplasmic Reticulum"] = roughEREntity
            addLabel(named: "Rough ER", to: roughEREntity, offset: SIMD3<Float>(0, 0.025, 0))

            // ==========================================
            // 6. SMOOTH ENDOPLASMIC RETICULUM
            // ==========================================
            let smoothEREntity = Entity()
            smoothEREntity.name = "Smooth Endoplasmic Reticulum"
            smoothEREntity.position = SIMD3<Float>(-0.06, 0.015, -0.04)

            let serColor = UIColor(red: 0.62, green: 0.62, blue: 0.14, alpha: 0.7)
            var serMaterial = PhysicallyBasedMaterial()
            serMaterial.baseColor = .init(tint: serColor)
            serMaterial.roughness = .init(floatLiteral: 0.5)
            serMaterial.metallic = .init(floatLiteral: 0.0)
            serMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.7))

            // Tubular network using small cylinders at various angles
            let tubeSegments: [(SIMD3<Float>, SIMD3<Float>, Float)] = [
                (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 1), 0.3),
                (SIMD3<Float>(0.008, 0.003, 0.005), SIMD3<Float>(1, 0.3, 0), -0.4),
                (SIMD3<Float>(-0.005, -0.003, 0.01), SIMD3<Float>(0.5, 0, 1), 0.2),
                (SIMD3<Float>(0.01, -0.005, -0.005), SIMD3<Float>(0, 1, 0.5), -0.3),
                (SIMD3<Float>(-0.01, 0.005, 0), SIMD3<Float>(1, 0.5, 0), 0.5),
                (SIMD3<Float>(0.003, 0.008, 0.008), SIMD3<Float>(0.3, 0, 1), -0.2),
                (SIMD3<Float>(-0.008, -0.002, -0.008), SIMD3<Float>(1, 1, 0), 0.15),
                (SIMD3<Float>(0.012, 0.001, 0.003), SIMD3<Float>(0, 0.7, 1), -0.35),
            ]

            for (pos, axis, angle) in tubeSegments {
                let tubeLength: Float = Float.random(in: 0.012...0.022)
                let tubeMesh = MeshResource.generateCylinder(height: tubeLength, radius: 0.0025)
                let tube = ModelEntity(mesh: tubeMesh, materials: [serMaterial])
                tube.position = pos
                tube.orientation = simd_quatf(angle: angle, axis: normalize(axis))
                smoothEREntity.addChild(tube)
            }

            // Add connecting junction spheres
            for (pos, _, _) in tubeSegments {
                let junctionMesh = MeshResource.generateSphere(radius: 0.003)
                let junction = ModelEntity(mesh: junctionMesh, materials: [serMaterial])
                junction.position = pos
                smoothEREntity.addChild(junction)
            }

            cellRoot.addChild(smoothEREntity)
            organelleEntities["Smooth Endoplasmic Reticulum"] = smoothEREntity
            addLabel(named: "Smooth ER", to: smoothEREntity, offset: SIMD3<Float>(0, 0.02, 0))

            // ==========================================
            // 7. GOLGI APPARATUS
            // ==========================================
            let golgiEntity = Entity()
            golgiEntity.name = "Golgi Apparatus"
            golgiEntity.position = SIMD3<Float>(-0.055, 0.045, 0.015)

            let golgiColor = UIColor(red: 1.0, green: 0.63, blue: 0.0, alpha: 0.75)
            var golgiMaterial = PhysicallyBasedMaterial()
            golgiMaterial.baseColor = .init(tint: golgiColor)
            golgiMaterial.roughness = .init(floatLiteral: 0.4)
            golgiMaterial.metallic = .init(floatLiteral: 0.0)
            golgiMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.75))

            // 5 stacked curved flattened discs
            for i in 0..<5 {
                let discWidth: Float = 0.035 - Float(abs(i - 2)) * 0.004
                let discDepth: Float = 0.022 - Float(abs(i - 2)) * 0.002
                let yOffset = Float(i) * 0.005 - 0.01
                let discMesh = MeshResource.generateBox(width: discWidth, height: 0.0018, depth: discDepth, cornerRadius: 0.001)
                let disc = ModelEntity(mesh: discMesh, materials: [golgiMaterial])
                disc.position = SIMD3<Float>(0, yOffset, 0)
                // Slight curve via rotation
                disc.orientation = simd_quatf(angle: Float(i - 2) * 0.06, axis: SIMD3<Float>(0, 0, 1))
                golgiEntity.addChild(disc)
            }

            // Vesicles budding off edges
            let vesicleColor = UIColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 0.8)
            let vesicleMaterial = SimpleMaterial(color: vesicleColor, isMetallic: false)
            let vesicleMesh = MeshResource.generateSphere(radius: 0.003)

            let vesiclePositions: [SIMD3<Float>] = [
                SIMD3<Float>(0.022, 0.008, 0.008),
                SIMD3<Float>(-0.020, -0.006, -0.01),
                SIMD3<Float>(0.018, -0.01, 0.005),
                SIMD3<Float>(-0.015, 0.012, -0.006),
                SIMD3<Float>(0.025, 0.002, -0.008),
            ]
            for vPos in vesiclePositions {
                let vesicle = ModelEntity(mesh: vesicleMesh, materials: [vesicleMaterial])
                vesicle.position = vPos
                golgiEntity.addChild(vesicle)
            }

            cellRoot.addChild(golgiEntity)
            organelleEntities["Golgi Apparatus"] = golgiEntity
            addLabel(named: "Golgi Apparatus", to: golgiEntity, offset: SIMD3<Float>(0, 0.025, 0))

            // ==========================================
            // 8. MITOCHONDRIA (4 scattered)
            // ==========================================
            let mitoPositions: [SIMD3<Float>] = [
                SIMD3<Float>(-0.07, -0.025, 0.04),
                SIMD3<Float>(0.06, 0.04, 0.05),
                SIMD3<Float>(0.03, -0.06, -0.05),
                SIMD3<Float>(-0.04, -0.05, -0.06),
            ]
            let mitoOrientations: [simd_quatf] = [
                simd_quatf(angle: 0.3, axis: SIMD3<Float>(0, 0, 1)),
                simd_quatf(angle: -0.5, axis: SIMD3<Float>(1, 0, 0.5)),
                simd_quatf(angle: 0.8, axis: SIMD3<Float>(0.3, 1, 0)),
                simd_quatf(angle: -0.4, axis: SIMD3<Float>(0, 0.5, 1)),
            ]

            let mitoOuterColor = UIColor(red: 0.9, green: 0.32, blue: 0.0, alpha: 0.8)
            var mitoOuterMaterial = PhysicallyBasedMaterial()
            mitoOuterMaterial.baseColor = .init(tint: mitoOuterColor)
            mitoOuterMaterial.roughness = .init(floatLiteral: 0.4)
            mitoOuterMaterial.metallic = .init(floatLiteral: 0.0)
            mitoOuterMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.8))

            let mitoInnerColor = UIColor(red: 0.7, green: 0.18, blue: 0.0, alpha: 0.85)
            var mitoInnerMaterial = PhysicallyBasedMaterial()
            mitoInnerMaterial.baseColor = .init(tint: mitoInnerColor)
            mitoInnerMaterial.roughness = .init(floatLiteral: 0.5)
            mitoInnerMaterial.metallic = .init(floatLiteral: 0.0)
            mitoInnerMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.85))

            var firstMito: Entity?
            for i in 0..<mitoPositions.count {
                let mitoEntity = Entity()
                mitoEntity.name = "Mitochondria"
                mitoEntity.position = mitoPositions[i]
                mitoEntity.orientation = mitoOrientations[i]

                // Outer membrane (elongated capsule via scaled sphere)
                let mitoLength: Float = cellRadius * 0.10
                let mitoWidth: Float = cellRadius * 0.05
                let outerMesh = MeshResource.generateSphere(radius: mitoWidth)
                let outer = ModelEntity(mesh: outerMesh, materials: [mitoOuterMaterial])
                outer.scale = SIMD3<Float>(mitoLength / mitoWidth, 1.0, 1.0)
                mitoEntity.addChild(outer)

                // Inner cristae - simplified as thin internal folded planes
                let cristaeMaterial = SimpleMaterial(color: mitoInnerColor, isMetallic: false)
                for c in 0..<4 {
                    let cx = Float(c) * (mitoLength * 0.4) / 3.0 - mitoLength * 0.15
                    let cristaeHeight: Float = mitoWidth * 1.2
                    let cristaeMesh = MeshResource.generateBox(width: 0.001, height: cristaeHeight, depth: mitoWidth * 0.8, cornerRadius: 0.0005)
                    let cristae = ModelEntity(mesh: cristaeMesh, materials: [cristaeMaterial])
                    cristae.position = SIMD3<Float>(cx, 0, 0)
                    cristae.orientation = simd_quatf(angle: Float(c) * 0.15, axis: SIMD3<Float>(1, 0, 0))
                    mitoEntity.addChild(cristae)
                }

                cellRoot.addChild(mitoEntity)

                if i == 0 {
                    firstMito = mitoEntity
                }
                organelleEntities["Mitochondria"] = mitoEntity
            }
            if let mito = firstMito {
                addLabel(named: "Mitochondria", to: mito, offset: SIMD3<Float>(0, 0.02, 0))
            }

            // ==========================================
            // 9. RIBOSOMES (30 scattered, free-floating)
            // ==========================================
            let ribosomesEntity = Entity()
            ribosomesEntity.name = "Ribosomes"

            let riboColor = UIColor(red: 0.29, green: 0.08, blue: 0.55, alpha: 1.0)
            let riboMaterial = SimpleMaterial(color: riboColor, isMetallic: false)
            let riboMesh = MeshResource.generateSphere(radius: cellRadius * 0.01)

            var firstRiboPos = SIMD3<Float>(0, 0, 0)
            for i in 0..<30 {
                let angle1 = Float.random(in: 0...(Float.pi * 2))
                let angle2 = Float.random(in: 0...(Float.pi))
                let dist = Float.random(in: (cellRadius * 0.25)...(cellRadius * 0.85))
                let rx = dist * sin(angle2) * cos(angle1)
                let ry = dist * cos(angle2)
                let rz = dist * sin(angle2) * sin(angle1)
                let ribo = ModelEntity(mesh: riboMesh, materials: [riboMaterial])
                ribo.position = SIMD3<Float>(rx, ry, rz)
                ribosomesEntity.addChild(ribo)
                if i == 0 { firstRiboPos = ribo.position }
            }

            cellRoot.addChild(ribosomesEntity)
            organelleEntities["Ribosomes"] = ribosomesEntity
            addLabel(named: "Ribosomes", to: ribosomesEntity, offset: SIMD3<Float>(firstRiboPos.x, firstRiboPos.y + 0.012, firstRiboPos.z))

            // ==========================================
            // 10. LYSOSOMES (3 scattered)
            // ==========================================
            let lysoColor = UIColor(red: 0.55, green: 0.43, blue: 0.39, alpha: 0.85)
            var lysoMaterial = PhysicallyBasedMaterial()
            lysoMaterial.baseColor = .init(tint: lysoColor)
            lysoMaterial.roughness = .init(floatLiteral: 0.5)
            lysoMaterial.metallic = .init(floatLiteral: 0.0)
            lysoMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.85))

            let lysoRadius: Float = cellRadius * 0.05
            let lysoMesh = MeshResource.generateSphere(radius: lysoRadius)

            let lysoPositions: [SIMD3<Float>] = [
                SIMD3<Float>(-0.065, 0.01, 0.05),
                SIMD3<Float>(0.07, -0.04, 0.03),
                SIMD3<Float>(-0.03, -0.06, 0.06),
            ]

            var firstLyso: ModelEntity?
            for (i, lPos) in lysoPositions.enumerated() {
                let lyso = ModelEntity(mesh: lysoMesh, materials: [lysoMaterial])
                lyso.name = "Lysosomes"
                lyso.position = lPos
                cellRoot.addChild(lyso)
                if i == 0 { firstLyso = lyso }
                organelleEntities["Lysosomes"] = lyso
            }
            if let lyso = firstLyso {
                addLabel(named: "Lysosomes", to: lyso, offset: SIMD3<Float>(0, lysoRadius + 0.012, 0))
            }

            // ==========================================
            // 11. CENTRIOLES (pair at right angles)
            // ==========================================
            let centriolesEntity = Entity()
            centriolesEntity.name = "Centrioles"
            centriolesEntity.position = SIMD3<Float>(-0.02, -0.05, -0.01)

            let centrColor = UIColor(red: 0.18, green: 0.49, blue: 0.20, alpha: 0.9)
            var centrMaterial = PhysicallyBasedMaterial()
            centrMaterial.baseColor = .init(tint: centrColor)
            centrMaterial.roughness = .init(floatLiteral: 0.4)
            centrMaterial.metallic = .init(floatLiteral: 0.1)
            centrMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.9))

            let centrHeight: Float = 0.015
            let centrRadius: Float = 0.004

            // First centriole (vertical)
            let centr1Mesh = MeshResource.generateCylinder(height: centrHeight, radius: centrRadius)
            let centr1 = ModelEntity(mesh: centr1Mesh, materials: [centrMaterial])
            centr1.position = SIMD3<Float>(0, 0, 0)
            centriolesEntity.addChild(centr1)

            // Second centriole (horizontal, at right angle)
            let centr2 = ModelEntity(mesh: centr1Mesh, materials: [centrMaterial])
            centr2.position = SIMD3<Float>(0.006, 0, 0.006)
            centr2.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
            centriolesEntity.addChild(centr2)

            // Add microtubule ring details on each centriole
            let ringMaterial = SimpleMaterial(color: UIColor(red: 0.13, green: 0.38, blue: 0.15, alpha: 1.0), isMetallic: false)
            for c in [centr1, centr2] {
                for r in 0..<3 {
                    let ringMesh = MeshResource.generateCylinder(height: 0.0005, radius: centrRadius + 0.001)
                    let ring = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
                    ring.position = SIMD3<Float>(0, Float(r) * 0.005 - 0.005, 0)
                    c.addChild(ring)
                }
            }

            cellRoot.addChild(centriolesEntity)
            organelleEntities["Centrioles"] = centriolesEntity
            addLabel(named: "Centrioles", to: centriolesEntity, offset: SIMD3<Float>(0, centrHeight + 0.012, 0))

            // ==========================================
            // 12. VACUOLES (2 small ones)
            // ==========================================
            let vacColor = UIColor(red: 0.51, green: 0.78, blue: 0.52, alpha: 0.4)
            var vacMaterial = PhysicallyBasedMaterial()
            vacMaterial.baseColor = .init(tint: vacColor)
            vacMaterial.roughness = .init(floatLiteral: 0.2)
            vacMaterial.metallic = .init(floatLiteral: 0.0)
            vacMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.4))

            let vacPositions: [SIMD3<Float>] = [
                SIMD3<Float>(0.04, 0.055, 0.035),
                SIMD3<Float>(-0.035, 0.06, -0.04),
            ]
            let vacRadii: [Float] = [cellRadius * 0.08, cellRadius * 0.06]

            var firstVac: ModelEntity?
            for (i, vPos) in vacPositions.enumerated() {
                let vacMesh = MeshResource.generateSphere(radius: vacRadii[i])
                let vac = ModelEntity(mesh: vacMesh, materials: [vacMaterial])
                vac.name = "Vacuoles"
                vac.position = vPos
                cellRoot.addChild(vac)
                if i == 0 { firstVac = vac }
                organelleEntities["Vacuoles"] = vac
            }
            if let vac = firstVac {
                addLabel(named: "Vacuoles", to: vac, offset: SIMD3<Float>(0, vacRadii[0] + 0.012, 0))
            }

            // ==========================================
            // 13. PEROXISOMES (3 tiny)
            // ==========================================
            let peroColor = UIColor(red: 0.51, green: 0.47, blue: 0.09, alpha: 0.85)
            var peroMaterial = PhysicallyBasedMaterial()
            peroMaterial.baseColor = .init(tint: peroColor)
            peroMaterial.roughness = .init(floatLiteral: 0.5)
            peroMaterial.metallic = .init(floatLiteral: 0.0)
            peroMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.85))

            let peroRadius: Float = cellRadius * 0.03
            let peroMesh = MeshResource.generateSphere(radius: peroRadius)

            let peroPositions: [SIMD3<Float>] = [
                SIMD3<Float>(0.07, -0.03, -0.03),
                SIMD3<Float>(-0.075, -0.04, -0.02),
                SIMD3<Float>(0.02, 0.07, -0.05),
            ]

            var firstPero: ModelEntity?
            for (i, pPos) in peroPositions.enumerated() {
                let pero = ModelEntity(mesh: peroMesh, materials: [peroMaterial])
                pero.name = "Peroxisomes"
                pero.position = pPos
                cellRoot.addChild(pero)
                if i == 0 { firstPero = pero }
                organelleEntities["Peroxisomes"] = pero
            }
            if let pero = firstPero {
                addLabel(named: "Peroxisomes", to: pero, offset: SIMD3<Float>(0, peroRadius + 0.012, 0))
            }

            // Generate collision shapes for the entire cell
            cellRoot.generateCollisionShapes(recursive: true)

            return cellRoot
        }

        // MARK: - Label Creation

        @MainActor
        private func addLabel(named text: String, to entity: Entity, offset: SIMD3<Float>) {
            let labelRoot = Entity()
            labelRoot.name = "\(text)_label"

            // Background plane
            let textLength = Float(text.count) * 0.005 + 0.01
            let bgMesh = MeshResource.generatePlane(width: textLength, depth: 0.012)
            var bgMaterial = PhysicallyBasedMaterial()
            bgMaterial.baseColor = .init(tint: UIColor(white: 0.0, alpha: 0.65))
            bgMaterial.roughness = .init(floatLiteral: 1.0)
            bgMaterial.metallic = .init(floatLiteral: 0.0)
            bgMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.65))
            let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])

            // Text
            let textMesh = MeshResource.generateText(
                text,
                extrusionDepth: 0.0005,
                font: .systemFont(ofSize: 0.007, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textMaterial = UnlitMaterial(color: .white)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

            // Center the text on the background
            let textBounds = textEntity.visualBounds(relativeTo: textEntity)
            let textWidth = textBounds.max.x - textBounds.min.x
            textEntity.position = SIMD3<Float>(-textWidth / 2, 0.0005, 0.003)

            // Line connector from label to organelle
            let lineHeight: Float = max(offset.y * 0.5, 0.005)
            let lineMesh = MeshResource.generateCylinder(height: lineHeight, radius: 0.0003)
            var lineMaterial = PhysicallyBasedMaterial()
            lineMaterial.baseColor = .init(tint: UIColor(white: 1.0, alpha: 0.3))
            lineMaterial.roughness = .init(floatLiteral: 1.0)
            lineMaterial.metallic = .init(floatLiteral: 0.0)
            lineMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.3))
            let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
            lineEntity.position = SIMD3<Float>(0, -lineHeight / 2, 0)

            labelRoot.addChild(bgEntity)
            labelRoot.addChild(textEntity)
            labelRoot.addChild(lineEntity)
            labelRoot.position = offset

            // Labels start hidden
            labelRoot.isEnabled = false

            entity.addChild(labelRoot)
            labelEntities[text] = labelRoot

            // Map display names to data names for lookup
            // "Rough ER" -> "Rough Endoplasmic Reticulum", etc.
            let displayToData: [String: String] = [
                "Rough ER": "Rough Endoplasmic Reticulum",
                "Smooth ER": "Smooth Endoplasmic Reticulum",
            ]
            if let dataName = displayToData[text] {
                labelEntities[dataName] = labelRoot
            }
        }
    }
}
