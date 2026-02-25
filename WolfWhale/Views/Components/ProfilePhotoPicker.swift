import SwiftUI
import PhotosUI
import Supabase

/// A reusable profile photo picker component.
///
/// Displays the current profile avatar as a circle. Tapping opens SwiftUI's native
/// `PhotosPicker` for gallery selection, with an optional camera capture fallback.
/// Includes a "Remove Photo" option when an uploaded image is present.
struct ProfilePhotoPicker: View {
    /// The current avatar URL (a full https:// URL for uploaded images, or nil).
    @Binding var avatarUrl: String?

    /// The selected SF Symbol fallback (used when no photo is uploaded).
    @Binding var selectedSystemImage: String

    /// Called when a new image is selected (from gallery or camera) with the resulting UIImage.
    /// The parent view should handle upload or local storage as needed.
    var onImageSelected: ((UIImage) -> Void)?

    /// Called when the user removes their photo.
    var onRemovePhoto: (() -> Void)?

    /// Size of the circular avatar.
    var size: CGFloat = 100

    /// Whether an upload is currently in progress.
    var isUploading: Bool = false

    // MARK: - Private State

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCameraSheet = false
    @State private var showActionSheet = false
    @State private var capturedImage: UIImage?
    @State private var hapticTrigger = false
    @State private var showFilterSheet = false
    @State private var pendingFilterImage: UIImage?

    private let photoService = PhotoService()

    /// Returns true when the avatar URL is a real uploaded image URL.
    private var hasUploadedAvatar: Bool {
        guard let url = avatarUrl, !url.isEmpty else { return false }
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Tappable avatar circle
            Button {
                hapticTrigger.toggle()
                showActionSheet = true
            } label: {
                avatarView
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .confirmationDialog("Change Profile Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
                // Photo Library option uses a separate PhotosPicker binding
                // so we present it via the onChange approach below
                Button("Choose from Library") {
                    // Trigger the hidden PhotosPicker via the overlay
                    showPhotosPicker = true
                }

                Button("Take Photo") {
                    showCameraSheet = true
                }

                if hasUploadedAvatar {
                    Button("Remove Photo", role: .destructive) {
                        withAnimation(.smooth) {
                            avatarUrl = nil
                            selectedPhoto = nil
                            onRemovePhoto?()
                        }
                    }
                }

                Button("Cancel", role: .cancel) {}
            }

            if isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading photo...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Tap to change photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .overlay {
            // Hidden PhotosPicker triggered programmatically
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Color.clear
                    .frame(width: 0, height: 0)
            }
            .opacity(0)
            .allowsHitTesting(false)
            .onChange(of: showPhotosPicker) { _, shouldShow in
                if shouldShow {
                    // Reset so the picker is triggered
                    selectedPhoto = nil
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                await handlePhotoPick(newValue)
            }
        }
        .fullScreenCover(isPresented: $showCameraSheet) {
            CameraCaptureView { image in
                showCameraSheet = false
                if let image {
                    presentFilter(for: image)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFilterSheet) {
            PhotoFilterView(image: $pendingFilterImage) { filtered in
                showFilterSheet = false
                onImageSelected?(filtered)
                pendingFilterImage = nil
            } onCancel: {
                // User skipped filtering — use the original image as-is
                showFilterSheet = false
                if let original = pendingFilterImage {
                    onImageSelected?(original)
                }
                pendingFilterImage = nil
            }
        }
    }

    @State private var showPhotosPicker = false

    // MARK: - Avatar View

    private var avatarView: some View {
        ZStack {
            if hasUploadedAvatar, let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackAvatar
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        fallbackAvatar
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                fallbackAvatar
            }

            // Camera badge overlay
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size * 0.3, height: size * 0.3)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(.orange)
                }
                .offset(x: size * 0.33, y: size * 0.33)
        }
        .accessibilityLabel("Profile photo")
        .accessibilityHint("Double tap to change your profile photo")
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.orange, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: selectedSystemImage)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Actions

    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        guard let image = await photoService.loadImage(from: item) else { return }
        showPhotosPicker = false
        presentFilter(for: image)
    }

    /// Presents the photo filter sheet for the given image.
    private func presentFilter(for image: UIImage) {
        pendingFilterImage = image
        showFilterSheet = true
    }
}

// MARK: - Camera Capture View

/// A `UIViewControllerRepresentable` wrapper for `UIImagePickerController`
/// configured for camera capture.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.editedImage] as? UIImage
                ?? info[.originalImage] as? UIImage
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
