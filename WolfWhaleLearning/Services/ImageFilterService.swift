import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - PhotoFilter

/// Available photo filter presets for profile photos and assignment attachments.
enum PhotoFilter: String, CaseIterable, Identifiable, Sendable {
    case none
    case vivid
    case warm
    case cool
    case noir
    case chrome
    case fade
    case mono
    case sharp
    case bloom

    var id: String { rawValue }

    /// Human-readable display name for the filter.
    var displayName: String {
        switch self {
        case .none:   "Original"
        case .vivid:  "Vivid"
        case .warm:   "Warm"
        case .cool:   "Cool"
        case .noir:   "Noir"
        case .chrome: "Chrome"
        case .fade:   "Fade"
        case .mono:   "Mono"
        case .sharp:  "Sharp"
        case .bloom:  "Bloom"
        }
    }
}

// MARK: - ImageFilterService

/// Applies Core Image filters to photos for profile images and assignment attachments.
///
/// Uses a shared `CIContext` for efficient GPU-backed rendering. All filter
/// processing happens off the main actor via `Task.detached` so the UI stays
/// responsive while heavy filters (e.g. bloom) are computed.
@Observable
@MainActor
final class ImageFilterService {

    // MARK: - Public State

    /// Whether a filter is currently being applied.
    var isProcessing: Bool = false

    /// The original, unfiltered image.
    var originalImage: UIImage?

    /// The result after applying the selected filter.
    var filteredImage: UIImage?

    /// The currently selected filter preset.
    var selectedFilter: PhotoFilter = .none

    // MARK: - Private

    /// Reusable Core Image context (expensive to create; kept for the lifetime of the service).
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Apply Filter

    /// Applies a `PhotoFilter` to the given image and returns the result.
    ///
    /// Processing runs on a background thread so the caller can `await` without
    /// blocking the main actor.
    ///
    /// - Parameters:
    ///   - filter: The filter preset to apply.
    ///   - image: The source `UIImage`.
    /// - Returns: The filtered `UIImage`, or `nil` if rendering failed.
    func applyFilter(_ filter: PhotoFilter, to image: UIImage) async -> UIImage? {
        guard filter != .none else { return image }

        let context = ciContext
        let result: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let ciImage = CIImage(image: image) else { return nil }
            guard let outputImage = Self.applyCI(filter, to: ciImage) else { return nil }

            let outputExtent = outputImage.extent
            guard let cgImage = context.createCGImage(outputImage, from: outputExtent) else {
                return nil
            }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }.value

        return result
    }

    // MARK: - Generate All Previews

    /// Generates thumbnail previews for every filter at a reduced size.
    ///
    /// Thumbnails are rendered at `thumbnailSize` (default 100x100) so the
    /// horizontal preview strip loads quickly.
    ///
    /// - Parameters:
    ///   - image: The source `UIImage`.
    ///   - thumbnailSize: The edge length for square thumbnails. Defaults to 100.
    /// - Returns: A dictionary mapping each `PhotoFilter` to its thumbnail `UIImage`.
    func generateAllPreviews(
        for image: UIImage,
        thumbnailSize: CGFloat = 100
    ) async -> [PhotoFilter: UIImage] {
        let context = ciContext
        let size = thumbnailSize

        let previews: [PhotoFilter: UIImage] = await Task.detached(priority: .userInitiated) {
            // Create a small thumbnail first to speed up filter processing
            let thumb = Self.resizedImage(image, to: CGSize(width: size, height: size))
            guard let baseCIImage = CIImage(image: thumb) else { return [:] }

            var results: [PhotoFilter: UIImage] = [:]

            for filter in PhotoFilter.allCases {
                if filter == .none {
                    results[filter] = thumb
                    continue
                }

                guard let outputCI = Self.applyCI(filter, to: baseCIImage),
                      let cgImage = context.createCGImage(outputCI, from: outputCI.extent) else {
                    continue
                }
                results[filter] = UIImage(cgImage: cgImage)
            }

            return results
        }.value

        return previews
    }

    // MARK: - Core Image Filter Application (static, non-isolated)

    /// Builds and applies the CIFilter chain for a given preset. Runs off the main actor.
    private static func applyCI(_ filter: PhotoFilter, to input: CIImage) -> CIImage? {
        switch filter {
        case .none:
            return input

        case .vivid:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = input
            colorControls.saturation = 1.5
            colorControls.contrast = 1.1
            guard let saturated = colorControls.outputImage else { return nil }

            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = saturated
            vibrance.amount = 0.8
            return vibrance.outputImage

        case .warm:
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = input
            temp.neutral = CIVector(x: 6500, y: 0)
            temp.targetNeutral = CIVector(x: 4500, y: 0)
            return temp.outputImage

        case .cool:
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = input
            temp.neutral = CIVector(x: 6500, y: 0)
            temp.targetNeutral = CIVector(x: 9000, y: 0)
            return temp.outputImage

        case .noir:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = input
            return noir.outputImage

        case .chrome:
            let chrome = CIFilter.photoEffectChrome()
            chrome.inputImage = input
            return chrome.outputImage

        case .fade:
            let fade = CIFilter.photoEffectFade()
            fade.inputImage = input
            return fade.outputImage

        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = input
            return mono.outputImage

        case .sharp:
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = input
            sharpen.sharpness = 0.8
            sharpen.radius = 1.6
            return sharpen.outputImage

        case .bloom:
            let bloom = CIFilter.bloom()
            bloom.inputImage = input
            bloom.radius = 10
            bloom.intensity = 0.7
            return bloom.outputImage
        }
    }

    // MARK: - Resize Helper

    /// Resizes a `UIImage` to fit within the given size, preserving aspect ratio.
    private static func resizedImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
