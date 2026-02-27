import PencilKit
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Drawing Tool

/// Available PencilKit drawing tool presets for the canvas toolbar.
nonisolated enum DrawingTool: String, CaseIterable, Sendable, Identifiable {
    case pen, pencil, marker, eraser

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen:     "Pen"
        case .pencil:  "Pencil"
        case .marker:  "Marker"
        case .eraser:  "Eraser"
        }
    }

    var iconName: String {
        switch self {
        case .pen:     "pencil.tip"
        case .pencil:  "pencil"
        case .marker:  "highlighter"
        case .eraser:  "eraser.fill"
        }
    }
}

// MARK: - Canvas Background

/// Background template options for the drawing canvas.
nonisolated enum CanvasBackground: String, CaseIterable, Sendable, Identifiable {
    case blank, lined, grid, dotted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blank:  "Blank"
        case .lined:  "Lined"
        case .grid:   "Grid"
        case .dotted: "Dotted"
        }
    }

    var iconName: String {
        switch self {
        case .blank:  "rectangle"
        case .lined:  "line.3.horizontal"
        case .grid:   "grid"
        case .dotted: "circle.grid.3x3"
        }
    }
}

// MARK: - Saved Drawing

/// Represents a persisted PencilKit drawing associated with an assignment.
nonisolated struct SavedDrawing: Identifiable, Sendable {
    let id: UUID
    let assignmentId: UUID
    let drawingData: Data
    let lastModified: Date
    let thumbnailData: Data?
}

// MARK: - Drawing Service

/// Manages PencilKit drawing persistence, export, and tool preferences for
/// assignment note-taking and sketching.
///
/// Drawings are stored in the app's documents directory as serialized
/// `PKDrawing` data, keyed by assignment UUID. Tool preferences and
/// background template are persisted via `UserDefaults`.
@MainActor
@Observable
final class DrawingService {

    // MARK: - Public State

    /// The current PencilKit drawing loaded in memory.
    var currentDrawing: PKDrawing = PKDrawing()

    /// The assignment UUID for the drawing currently in memory.
    var currentAssignmentId: UUID?

    /// The currently selected drawing tool.
    private var _selectedTool: DrawingTool = .pen
    var selectedTool: DrawingTool {
        get { _selectedTool }
        set { _selectedTool = newValue; persistToolPreference() }
    }

    /// The currently selected canvas background template.
    private var _selectedBackground: CanvasBackground = .blank
    var selectedBackground: CanvasBackground {
        get { _selectedBackground }
        set { _selectedBackground = newValue; persistBackgroundPreference() }
    }

    /// The current stroke color (persisted as hex string).
    private var _strokeColor: UIColor = .label
    var strokeColor: UIColor {
        get { _strokeColor }
        set { _strokeColor = newValue; persistStrokeColor() }
    }

    /// The current stroke width.
    var strokeWidth: CGFloat = 3.0

    /// Number of available undo actions (tracked externally; PencilKit handles actual undo).
    var undoCount: Int = 0

    /// Number of available redo actions (tracked externally; PencilKit handles actual redo).
    var redoCount: Int = 0

    /// Whether the service is performing an async operation.
    var isLoading = false

    /// Human-readable error message, if any.
    var error: String?

    /// All saved drawings discovered on disk.
    var savedDrawings: [SavedDrawing] = []

    // MARK: - Private

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    private static let toolKey = "drawingService.selectedTool"
    private static let backgroundKey = "drawingService.selectedBackground"
    private static let strokeColorKey = "drawingService.strokeColorHex"

    // MARK: - Initializer

    init() {
        restorePreferences()
    }

    // MARK: - Save Drawing

    /// Serializes the current `PKDrawing` and writes it to the documents
    /// directory for the given assignment.
    ///
    /// - Parameter assignmentId: The assignment UUID to key the saved file.
    func saveDrawing(for assignmentId: UUID) {
        error = nil

        do {
            let data = currentDrawing.dataRepresentation()
            let fileURL = drawingFileURL(for: assignmentId)

            // Ensure the drawings directory exists
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try data.write(to: fileURL, options: .atomic)
            currentAssignmentId = assignmentId

            // Generate and persist a thumbnail alongside the drawing
            saveThumbnail(for: assignmentId)
        } catch {
            self.error = "Failed to save drawing: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Drawing

    /// Loads a previously saved `PKDrawing` from disk for the given assignment.
    ///
    /// - Parameter assignmentId: The assignment UUID whose drawing to load.
    /// - Returns: `true` if a saved drawing was found and loaded.
    @discardableResult
    func loadDrawing(for assignmentId: UUID) -> Bool {
        error = nil
        let fileURL = drawingFileURL(for: assignmentId)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            currentDrawing = PKDrawing()
            currentAssignmentId = assignmentId
            undoCount = 0
            redoCount = 0
            return false
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let drawing = try PKDrawing(data: data)
            currentDrawing = drawing
            currentAssignmentId = assignmentId
            undoCount = 0
            redoCount = 0
            return true
        } catch {
            self.error = "Failed to load drawing: \(error.localizedDescription)"
            currentDrawing = PKDrawing()
            currentAssignmentId = assignmentId
            return false
        }
    }

    // MARK: - Delete Drawing

    /// Removes a saved drawing and its thumbnail from disk.
    ///
    /// - Parameter assignmentId: The assignment UUID whose drawing to delete.
    func deleteDrawing(for assignmentId: UUID) {
        error = nil
        let fileURL = drawingFileURL(for: assignmentId)
        let thumbURL = thumbnailFileURL(for: assignmentId)

        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: thumbURL)

        if currentAssignmentId == assignmentId {
            currentDrawing = PKDrawing()
            undoCount = 0
            redoCount = 0
        }

        savedDrawings.removeAll { $0.assignmentId == assignmentId }
    }

    // MARK: - Clear Canvas

    /// Resets the in-memory drawing to a blank canvas (does NOT delete saved file).
    func clearCanvas() {
        currentDrawing = PKDrawing()
        undoCount = 0
        redoCount = 0
    }

    // MARK: - Has Saved Drawing

    /// Checks whether a saved drawing file exists for the given assignment.
    func hasSavedDrawing(for assignmentId: UUID) -> Bool {
        fileManager.fileExists(atPath: drawingFileURL(for: assignmentId).path)
    }

    // MARK: - Load All Saved Drawings

    /// Scans the drawings directory and populates `savedDrawings` with metadata.
    func loadAllSavedDrawings() {
        error = nil
        isLoading = true
        defer { isLoading = false }

        let directory = drawingsDirectory()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            savedDrawings = []
            return
        }

        var drawings: [SavedDrawing] = []

        for fileURL in contents where fileURL.pathExtension == "pkdrawing" {
            let stem = fileURL.deletingPathExtension().lastPathComponent
            guard let assignmentId = UUID(uuidString: stem) else { continue }

            let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date()

            let data = (try? Data(contentsOf: fileURL)) ?? Data()

            let thumbURL = thumbnailFileURL(for: assignmentId)
            let thumbData = try? Data(contentsOf: thumbURL)

            drawings.append(SavedDrawing(
                id: assignmentId,
                assignmentId: assignmentId,
                drawingData: data,
                lastModified: modDate,
                thumbnailData: thumbData
            ))
        }

        savedDrawings = drawings.sorted { $0.lastModified > $1.lastModified }
    }

    // MARK: - Export as UIImage

    /// Renders the current drawing to a `UIImage`.
    ///
    /// - Parameter scale: The rendering scale. Defaults to the main screen scale.
    /// - Returns: The rendered image, or `nil` on failure.
    @MainActor func exportAsImage(scale: CGFloat = UITraitCollection.current.displayScale) -> UIImage? {
        let bounds = currentDrawing.bounds
        guard !bounds.isEmpty else {
            error = "Nothing to export. The canvas is empty."
            return nil
        }

        // Add some padding around the drawing content
        let padding: CGFloat = 20
        let exportRect = bounds.insetBy(dx: -padding, dy: -padding)
        let image = currentDrawing.image(from: exportRect, scale: scale)
        return image
    }

    // MARK: - Export as PDF

    /// Renders the current drawing into a single-page PDF and returns the raw data.
    ///
    /// - Parameter pageSize: The PDF page size. Defaults to US Letter (612x792).
    /// - Returns: The PDF data, or `nil` on failure.
    func exportAsPDF(pageSize: CGSize = CGSize(width: 612, height: 792)) -> Data? {
        let bounds = currentDrawing.bounds
        guard !bounds.isEmpty else {
            error = "Nothing to export. The canvas is empty."
            return nil
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            error = "Failed to create PDF consumer."
            return nil
        }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            error = "Failed to create PDF context."
            return nil
        }

        pdfContext.beginPage(mediaBox: &mediaBox)

        // Scale and center the drawing within the page
        let padding: CGFloat = 36
        let availableWidth = pageSize.width - padding * 2
        let availableHeight = pageSize.height - padding * 2

        let drawingBounds = bounds
        let scaleX = availableWidth / drawingBounds.width
        let scaleY = availableHeight / drawingBounds.height
        let fitScale = min(scaleX, scaleY, 1.0)

        let scaledWidth = drawingBounds.width * fitScale
        let scaledHeight = drawingBounds.height * fitScale
        let offsetX = padding + (availableWidth - scaledWidth) / 2
        let offsetY = padding + (availableHeight - scaledHeight) / 2

        let drawingImage = currentDrawing.image(from: drawingBounds, scale: 2.0)
        if let cgImage = drawingImage.cgImage {
            let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
            pdfContext.draw(cgImage, in: drawRect)
        }

        pdfContext.endPage()
        pdfContext.closePDF()

        return pdfData as Data
    }

    // MARK: - Undo / Redo Tracking

    /// Called by the canvas coordinator whenever the drawing changes, to keep
    /// undo/redo counts in sync with the `UndoManager`.
    func updateUndoRedoCounts(undoManager: UndoManager?) {
        undoCount = undoManager?.canUndo == true ? undoCount + 1 : 0
        redoCount = undoManager?.canRedo == true ? redoCount + 1 : 0
    }

    /// Increments the undo count (call when the user makes a stroke).
    func recordStroke() {
        undoCount += 1
        redoCount = 0
    }

    /// Decrements undo count and increments redo count.
    func recordUndo() {
        if undoCount > 0 { undoCount -= 1 }
        redoCount += 1
    }

    /// Decrements redo count and increments undo count.
    func recordRedo() {
        if redoCount > 0 { redoCount -= 1 }
        undoCount += 1
    }

    // MARK: - Build PKInkingTool

    /// Returns a configured `PKInkingTool` matching the current tool, color,
    /// and width settings. Returns `nil` for the eraser (handled separately).
    func currentInkingTool() -> PKInkingTool? {
        switch selectedTool {
        case .pen:
            return PKInkingTool(.pen, color: strokeColor, width: strokeWidth)
        case .pencil:
            return PKInkingTool(.pencil, color: strokeColor, width: strokeWidth)
        case .marker:
            return PKInkingTool(.marker, color: strokeColor, width: strokeWidth * 3)
        case .eraser:
            return nil
        }
    }

    /// Returns the appropriate `PKTool` for the current selection.
    func currentPKTool() -> PKTool {
        if selectedTool == .eraser {
            return PKEraserTool(.vector)
        }
        return currentInkingTool() ?? PKInkingTool(.pen, color: strokeColor, width: strokeWidth)
    }

    // MARK: - File Paths

    private func drawingsDirectory() -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate document directory")
        }
        return docs.appendingPathComponent("Drawings", isDirectory: true)
    }

    private func drawingFileURL(for assignmentId: UUID) -> URL {
        drawingsDirectory().appendingPathComponent("\(assignmentId.uuidString).pkdrawing")
    }

    private func thumbnailFileURL(for assignmentId: UUID) -> URL {
        drawingsDirectory().appendingPathComponent("\(assignmentId.uuidString)_thumb.png")
    }

    // MARK: - Thumbnail Generation

    /// Generates and saves a small thumbnail image for the current drawing.
    private func saveThumbnail(for assignmentId: UUID) {
        let bounds = currentDrawing.bounds
        guard !bounds.isEmpty else { return }

        let thumbnailSize: CGFloat = 200
        let scale = min(thumbnailSize / bounds.width, thumbnailSize / bounds.height, 1.0)
        let renderWidth = bounds.width * scale
        let renderHeight = bounds.height * scale

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: renderWidth, height: renderHeight))
        let thumbImage = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: renderWidth, height: renderHeight)))
            let drawingImage = currentDrawing.image(from: bounds, scale: scale)
            drawingImage.draw(in: CGRect(origin: .zero, size: CGSize(width: renderWidth, height: renderHeight)))
        }

        if let pngData = thumbImage.pngData() {
            let thumbURL = thumbnailFileURL(for: assignmentId)
            try? pngData.write(to: thumbURL, options: .atomic)
        }
    }

    // MARK: - Preference Persistence

    private func persistToolPreference() {
        defaults.set(_selectedTool.rawValue, forKey: Self.toolKey)
    }

    private func persistBackgroundPreference() {
        defaults.set(_selectedBackground.rawValue, forKey: Self.backgroundKey)
    }

    private func persistStrokeColor() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        _strokeColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        defaults.set(hex, forKey: Self.strokeColorKey)
    }

    private func restorePreferences() {
        if let toolRaw = defaults.string(forKey: Self.toolKey),
           let tool = DrawingTool(rawValue: toolRaw) {
            _selectedTool = tool
        }

        if let bgRaw = defaults.string(forKey: Self.backgroundKey),
           let bg = CanvasBackground(rawValue: bgRaw) {
            _selectedBackground = bg
        }

        if let hex = defaults.string(forKey: Self.strokeColorKey) {
            _strokeColor = Self.colorFromHex(hex)
        }
    }

    // MARK: - Hex Color Utility

    nonisolated private static func colorFromHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return .label }

        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
