import SwiftUI

/// A photo filter picker UI styled like Instagram's filter strip.
///
/// Shows a large preview of the current image with the selected filter applied,
/// a horizontally scrollable row of filter thumbnails at the bottom, and
/// "Reset" / "Apply" action buttons.
struct PhotoFilterView: View {

    /// The image to filter (bound to the parent so the original can be preserved).
    @Binding var image: UIImage?

    /// Called when the user taps "Apply" with the final filtered image.
    var onApply: (UIImage) -> Void

    /// Called when the user dismisses the filter view without applying.
    var onCancel: (() -> Void)?

    // MARK: - Private State

    @State private var filterService = ImageFilterService()
    @State private var previews: [PhotoFilter: UIImage] = [:]
    @State private var previewImage: UIImage?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark photo-editing background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer(minLength: 12)

                // Large preview
                mainPreview
                    .padding(.horizontal, 16)

                Spacer(minLength: 16)

                // Horizontal filter strip
                filterStrip
                    .padding(.bottom, 8)

                // Action buttons
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            // Full-screen loading overlay
            if filterService.isProcessing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Applying filter...")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
            }
        }
        .task {
            guard let image else { return }
            filterService.originalImage = image
            filterService.filteredImage = image
            previewImage = image

            // Generate thumbnails for the filter strip
            previews = await filterService.generateAllPreviews(for: image)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onCancel?()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .contentShape(Circle())
            }

            Spacer()

            Text("Filters")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            // Invisible spacer matching close button width for centering
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Main Preview

    private var mainPreview: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Thumbnail Strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(PhotoFilter.allCases) { filter in
                    filterThumbnail(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterThumbnail(for filter: PhotoFilter) -> some View {
        let isSelected = filterService.selectedFilter == filter

        return Button {
            guard filterService.selectedFilter != filter else { return }
            filterService.selectedFilter = filter
            applySelectedFilter(filter)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let thumb = previews[filter] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.6)
                            }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )

                Text(filter.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Reset button
            Button {
                filterService.selectedFilter = .none
                previewImage = filterService.originalImage
                filterService.filteredImage = filterService.originalImage
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }

            // Apply button
            Button {
                if let result = filterService.filteredImage {
                    onApply(result)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Apply")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.orange, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
        }
    }

    // MARK: - Helpers

    private func applySelectedFilter(_ filter: PhotoFilter) {
        guard let original = filterService.originalImage else { return }

        if filter == .none {
            previewImage = original
            filterService.filteredImage = original
            return
        }

        filterService.isProcessing = true
        Task {
            let result = await filterService.applyFilter(filter, to: original)
            previewImage = result ?? original
            filterService.filteredImage = result ?? original
            filterService.isProcessing = false
        }
    }
}
