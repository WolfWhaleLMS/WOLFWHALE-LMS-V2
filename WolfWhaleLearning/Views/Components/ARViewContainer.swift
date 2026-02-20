import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let modelName: String

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // Add coaching overlay for first-time users
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)

        // Add a placeholder 3D object (colored box) since we don't have USDZ files yet
        let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
        let material = SimpleMaterial(color: .systemPurple, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        // Enable gestures
        arView.installGestures([.rotation, .scale, .translation], for: entity)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - AR Fullscreen Viewer

struct ARModelViewer: View {
    let model: ARModelLibraryView.ARModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ARViewContainer(modelName: model.name)
                .ignoresSafeArea()

            // Top overlay with model name and dismiss button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close AR view")
                    .accessibilityHint("Double tap to dismiss the AR viewer")

                    Spacer()

                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    // Balance the layout
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                // Bottom instruction label
                Text("Tap a surface to place model -- Pinch, rotate, or drag to adjust")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
        .statusBarHidden()
    }
}
