import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - CachedAsyncImage

/// A drop-in replacement for `AsyncImage` that adds in-memory and disk caching
/// via ``ImageCacheService``.
///
/// The loading flow:
/// 1. Check in-memory cache (instant).
/// 2. Check disk cache and promote to memory if found.
/// 3. Download from the network, store in both caches.
/// 4. Show the placeholder while any of the above is in progress.
///
/// Usage:
/// ```swift
/// CachedAsyncImage(url: imageURL) {
///     ProgressView()
/// }
/// .frame(width: 200, height: 200)
/// .clipShape(RoundedRectangle(cornerRadius: 12))
/// ```
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    /// Maximum pixel dimension for downsampled images.
    /// Avatars typically use 100; general images use 400.
    let maxDimension: CGFloat

    @State private var image: Image?
    @State private var isLoading = false

    init(url: URL?, maxDimension: CGFloat = 400, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxDimension = maxDimension
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true

        defer { isLoading = false }

        // 1. Check in-memory + disk cache
        if let cached = ImageCacheService.shared.getImage(for: url) {
            self.image = cached
            return
        }

        // 2. Download from network
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Only cache valid image responses
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return
            }

            #if canImport(UIKit)
            // Perform CPU-heavy downsampling off the main thread to avoid hitches.
            let maxDim = maxDimension
            let cachedURL = url
            let result: Image? = await Task.detached(priority: .userInitiated) {
                if let downsampledImage = ImageCacheService.shared.setDownsampledImage(
                    data: data, for: cachedURL, maxDimension: maxDim
                ) {
                    return downsampledImage
                } else if let uiImage = UIImage(data: data) {
                    let swiftUIImage = Image(uiImage: uiImage)
                    ImageCacheService.shared.setImage(swiftUIImage, data: data, for: cachedURL)
                    return swiftUIImage
                }
                return nil
            }.value

            if let result {
                self.image = result
            }
            #endif
        } catch {
            // Silently fail; the placeholder remains visible
        }
    }
}

// MARK: - Convenience Init (Default Placeholder)

extension CachedAsyncImage where Placeholder == Color {
    /// Creates a `CachedAsyncImage` with a subtle gray placeholder.
    init(url: URL?, maxDimension: CGFloat = 400) {
        self.init(url: url, maxDimension: maxDimension) {
            Color.gray.opacity(0.2)
        }
    }
}
