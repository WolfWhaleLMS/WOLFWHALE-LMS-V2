import SwiftUI
import VisionKit
import Vision
import CoreImage
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Scan Status

nonisolated enum ScanStatus: String, Sendable {
    case idle
    case scanning
    case processing
    case complete
}

// MARK: - Scanned Page

nonisolated struct ScannedPage: Identifiable, Hashable, Sendable {
    let id: UUID
    let pageNumber: Int
    let extractedText: String
    /// PNG-encoded image data (UIImage is not Sendable).
    let imageData: Data

    init(pageNumber: Int, extractedText: String, imageData: Data) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.extractedText = extractedText
        self.imageData = imageData
    }
}

// MARK: - Scanned Document

nonisolated struct ScannedDocument: Identifiable, Sendable {
    let id: UUID
    let pages: [ScannedPage]
    let extractedText: String
    let pdfData: Data?
    let scanDate: Date

    init(pages: [ScannedPage], extractedText: String, pdfData: Data?, scanDate: Date = Date()) {
        self.id = UUID()
        self.pages = pages
        self.extractedText = extractedText
        self.pdfData = pdfData
        self.scanDate = scanDate
    }
}

// MARK: - Image Quality Result

nonisolated struct ImageQualityResult: Sendable {
    let isAcceptable: Bool
    let brightness: CGFloat
    let message: String
}

// MARK: - Document Scanner Service

@MainActor
@Observable
final class DocumentScannerService {

    // MARK: - Public State

    var scannedPages: [ScannedPage] = []
    var scanStatus: ScanStatus = .idle
    var extractedText: String = ""
    var pdfData: Data?
    var scannedDocument: ScannedDocument?
    var error: String?
    var isLoading = false
    var processingProgress: Double = 0

    // MARK: - Handle Scanned Images

    /// Receives raw `UIImage` pages from the VNDocumentCameraViewController
    /// delegate, converts to PNG data, runs OCR, and stores results.
    func processScannedImages(_ images: [UIImage]) async {
        guard !images.isEmpty else {
            error = "No pages were scanned."
            return
        }

        scanStatus = .processing
        isLoading = true
        error = nil
        processingProgress = 0

        var pages: [ScannedPage] = []
        var allText = ""

        for (index, image) in images.enumerated() {
            // Convert UIImage to PNG data for Sendable storage
            guard let pngData = image.pngData() else {
                error = "Failed to encode page \(index + 1) as image data."
                isLoading = false
                scanStatus = .idle
                return
            }

            // Validate image quality
            let quality = Self.validateImageQuality(image)
            if !quality.isAcceptable {
                error = "Page \(index + 1): \(quality.message)"
                isLoading = false
                scanStatus = .idle
                return
            }

            // OCR text extraction
            let pageText = await Self.extractText(from: image)

            let page = ScannedPage(
                pageNumber: index + 1,
                extractedText: pageText,
                imageData: pngData
            )
            pages.append(page)

            if !pageText.isEmpty {
                if !allText.isEmpty {
                    allText += "\n\n--- Page \(index + 1) ---\n\n"
                }
                allText += pageText
            }

            processingProgress = Double(index + 1) / Double(images.count)
        }

        // Generate combined PDF
        let pdf = Self.generatePDF(from: images)

        scannedPages = pages
        extractedText = allText
        pdfData = pdf

        scannedDocument = ScannedDocument(
            pages: pages,
            extractedText: allText,
            pdfData: pdf
        )

        scanStatus = .complete
        isLoading = false
        processingProgress = 1.0
    }

    // MARK: - Delete Page

    /// Removes a single scanned page by its ID and rebuilds the document.
    func deletePage(_ pageId: UUID) {
        scannedPages.removeAll { $0.id == pageId }
        rebuildDocument()
    }

    // MARK: - Reorder Pages

    /// Moves a page from one index to another and rebuilds the document.
    func movePage(from source: IndexSet, to destination: Int) {
        scannedPages.move(fromOffsets: source, toOffset: destination)

        // Renumber pages sequentially
        var renumbered: [ScannedPage] = []
        for (index, page) in scannedPages.enumerated() {
            let updated = ScannedPage(
                pageNumber: index + 1,
                extractedText: page.extractedText,
                imageData: page.imageData
            )
            renumbered.append(updated)
        }
        scannedPages = renumbered
        rebuildDocument()
    }

    // MARK: - Reset

    /// Clears all scanned data and resets to idle.
    func reset() {
        scannedPages = []
        extractedText = ""
        pdfData = nil
        scannedDocument = nil
        scanStatus = .idle
        error = nil
        isLoading = false
        processingProgress = 0
    }

    // MARK: - Private Helpers

    /// Rebuilds extracted text and PDF from current pages array.
    private func rebuildDocument() {
        var allText = ""
        var images: [UIImage] = []

        for page in scannedPages {
            if !page.extractedText.isEmpty {
                if !allText.isEmpty {
                    allText += "\n\n--- Page \(page.pageNumber) ---\n\n"
                }
                allText += page.extractedText
            }
            if let uiImage = UIImage(data: page.imageData) {
                images.append(uiImage)
            }
        }

        extractedText = allText
        pdfData = Self.generatePDF(from: images)

        if scannedPages.isEmpty {
            scannedDocument = nil
            scanStatus = .idle
        } else {
            scannedDocument = ScannedDocument(
                pages: scannedPages,
                extractedText: allText,
                pdfData: pdfData
            )
        }
    }

    // MARK: - OCR Text Extraction (static, nonisolated)

    /// Runs VNRecognizeTextRequest on the provided image and returns the
    /// concatenated recognized strings. Executes off the main actor.
    nonisolated private static func extractText(from image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: "")
                return
            }

            let request = VNRecognizeTextRequest { request, requestError in
                guard requestError == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "fr-FR", "es-ES"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    // MARK: - PDF Generation (static, nonisolated)

    /// Renders an array of UIImages into a single PDF document and returns the
    /// raw `Data`. Each page is sized to the image dimensions at 72 DPI.
    nonisolated private static func generatePDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }

        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = CGRect.zero

        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        for image in images {
            let pageWidth = image.size.width
            let pageHeight = image.size.height
            var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

            pdfContext.beginPage(mediaBox: &pageRect)

            if let cgImage = image.cgImage {
                pdfContext.draw(cgImage, in: pageRect)
            }

            pdfContext.endPage()
        }

        pdfContext.closePDF()
        return pdfData as Data
    }

    // MARK: - Image Quality Validation (static, nonisolated)

    /// Evaluates whether the image has acceptable brightness for readable text.
    /// Returns a result struct with the brightness value and a human-readable message.
    nonisolated static func validateImageQuality(_ image: UIImage) -> ImageQualityResult {
        guard let cgImage = image.cgImage else {
            return ImageQualityResult(
                isAcceptable: false,
                brightness: 0,
                message: "Unable to analyze image quality."
            )
        }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        // Use CIAreaAverage to compute mean brightness
        let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(
                    x: extent.origin.x,
                    y: extent.origin.y,
                    z: extent.size.width,
                    w: extent.size.height
                )
            ]
        )

        guard let outputImage = filter?.outputImage else {
            return ImageQualityResult(isAcceptable: true, brightness: 0.5, message: "OK")
        }

        let context = CIContext(options: [.useSoftwareRenderer: true])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Perceived brightness: weighted average of RGB
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b

        if brightness < 0.08 {
            return ImageQualityResult(
                isAcceptable: false,
                brightness: brightness,
                message: "Image is too dark. Please ensure adequate lighting and try again."
            )
        }

        if brightness > 0.97 {
            return ImageQualityResult(
                isAcceptable: false,
                brightness: brightness,
                message: "Image is overexposed. Try reducing glare and scan again."
            )
        }

        return ImageQualityResult(
            isAcceptable: true,
            brightness: brightness,
            message: "Good image quality."
        )
    }
}
