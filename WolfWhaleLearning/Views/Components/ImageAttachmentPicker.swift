import SwiftUI
import PhotosUI

/// A reusable multi-image picker for assignment submissions.
///
/// Uses SwiftUI's native `PhotosPicker` with an `.images` filter.
/// Displays a thumbnail grid of selected images with individual removal
/// and an "Add More" button.
struct ImageAttachmentPicker: View {
    /// The array of selected images. Parent views read this to upload.
    @Binding var selectedImages: [UIImage]

    /// Maximum number of images allowed.
    var maxImages: Int = 10

    /// Called when images change (optional callback for parent views).
    var onImagesChanged: (([UIImage]) -> Void)?

    // MARK: - Private State

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingImages = false
    @State private var hapticTrigger = false

    private let photoService = PhotoService()

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.pink)
                Text("Photo Attachments")
                    .font(.headline)
                Spacer()
                Text("\(selectedImages.count)/\(maxImages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Thumbnail Grid
            if !selectedImages.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        thumbnailView(image: image, index: index)
                    }
                }
            }

            // Add More / Pick Photos Button
            if selectedImages.count < maxImages {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: maxImages - selectedImages.count,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 10) {
                        if isLoadingImages {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading photos...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: selectedImages.isEmpty ? "photo.badge.plus" : "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.pink)
                            Text(selectedImages.isEmpty ? "Add Photos" : "Add More")
                                .font(.subheadline.bold())
                                .foregroundStyle(.pink)
                        }
                        Spacer()
                        if !selectedImages.isEmpty && !isLoadingImages {
                            Text("up to \(maxImages - selectedImages.count) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
                .disabled(isLoadingImages)
            }

            // Clear All button
            if selectedImages.count > 1 {
                Button(role: .destructive) {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        selectedImages.removeAll()
                        selectedPhotos.removeAll()
                        onImagesChanged?([])
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Remove All")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await loadSelectedPhotos(newItems)
            }
        }
    }

    // MARK: - Thumbnail View

    private func thumbnailView(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 100)
                .clipShape(.rect(cornerRadius: 10))

            // Remove button
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    if index < selectedImages.count {
                        selectedImages.remove(at: index)
                        onImagesChanged?(selectedImages)
                    }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(4)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    // MARK: - Load Photos

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingImages = true
        defer {
            isLoadingImages = false
            // Clear selection so the user can pick the same photos again if needed
            selectedPhotos.removeAll()
        }

        for item in items {
            guard selectedImages.count < maxImages else { break }

            if let image = await photoService.loadImage(from: item) {
                selectedImages.append(image)
            }
        }

        onImagesChanged?(selectedImages)
    }
}
