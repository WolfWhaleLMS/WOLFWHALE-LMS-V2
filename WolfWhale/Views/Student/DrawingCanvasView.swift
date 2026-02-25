import SwiftUI
import PencilKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PencilKit Canvas Representable

/// Wraps `PKCanvasView` for SwiftUI via `UIViewRepresentable`. The coordinator
/// manages the `PKToolPicker` and drawing-change delegate callbacks.
struct PencilCanvasRepresentable: UIViewRepresentable {

    /// Binding to the current PKDrawing so SwiftUI and UIKit stay in sync.
    @Binding var drawing: PKDrawing

    /// The PencilKit tool to apply when the canvas updates.
    let tool: PKTool

    /// Whether the built-in PKToolPicker should be visible.
    let showToolPicker: Bool

    /// Called each time the drawing changes (e.g. a stroke is completed).
    let onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.tool = tool
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.alwaysBounceVertical = true
        canvasView.contentSize = CGSize(width: 2000, height: 3000)

        // Configure the system tool picker
        context.coordinator.canvasView = canvasView
        let picker = PKToolPicker()
        context.coordinator.toolPicker = picker
        picker.addObserver(canvasView)
        picker.setVisible(showToolPicker, forFirstResponder: canvasView)
        if showToolPicker {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Only update the drawing if it actually differs (avoid infinite loop)
        if canvasView.drawing.dataRepresentation() != drawing.dataRepresentation() {
            canvasView.drawing = drawing
        }
        canvasView.tool = tool

        if let picker = context.coordinator.toolPicker {
            picker.setVisible(showToolPicker, forFirstResponder: canvasView)
            if showToolPicker {
                canvasView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, onDrawingChanged: onDrawingChanged)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        let onDrawingChanged: () -> Void
        var canvasView: PKCanvasView?
        var toolPicker: PKToolPicker?

        init(drawing: Binding<PKDrawing>, onDrawingChanged: @escaping () -> Void) {
            self._drawing = drawing
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self] in
                self?.drawing = canvasView.drawing
                self?.onDrawingChanged()
            }
        }
    }
}

// MARK: - Canvas Background Renderer

/// Draws repeating background patterns (lines, grid, dots) behind the canvas.
struct CanvasBackgroundView: View {
    let background: CanvasBackground

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                switch background {
                case .blank:
                    break

                case .lined:
                    let spacing: CGFloat = 32
                    var y: CGFloat = spacing
                    while y < size.height {
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
                        y += spacing
                    }

                case .grid:
                    let spacing: CGFloat = 32
                    // Horizontal lines
                    var y: CGFloat = spacing
                    while y < size.height {
                        let hPath = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(hPath, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                        y += spacing
                    }
                    // Vertical lines
                    var x: CGFloat = spacing
                    while x < size.width {
                        let vPath = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        context.stroke(vPath, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                        x += spacing
                    }

                case .dotted:
                    let spacing: CGFloat = 28
                    let dotRadius: CGFloat = 1.5
                    var y: CGFloat = spacing
                    while y < size.height {
                        var x: CGFloat = spacing
                        while x < size.width {
                            let dot = Path(ellipseIn: CGRect(
                                x: x - dotRadius,
                                y: y - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            ))
                            context.fill(dot, with: .color(.gray.opacity(0.25)))
                            x += spacing
                        }
                        y += spacing
                    }
                }
            }
            .frame(width: geometry.size.width, height: max(geometry.size.height, 3000))
        }
    }
}

// MARK: - Drawing Canvas View

/// Full-screen PencilKit canvas for assignment note-taking and sketching.
///
/// Provides a custom toolbar with tool selection, background templates,
/// undo/redo, save, export, and assignment submission capabilities.
struct DrawingCanvasView: View {
    let assignment: Assignment
    let viewModel: AppViewModel

    @State private var drawingService = DrawingService()
    @State private var showBackgroundPicker = false
    @State private var showExportSheet = false
    @State private var showClearConfirmation = false
    @State private var showSubmitConfirmation = false
    @State private var showSubmitSuccess = false
    @State private var showError = false
    @State private var showColorPicker = false
    @State private var isSubmitting = false
    @State private var exportedImage: UIImage?
    @State private var hapticTrigger = false
    @State private var saveTrigger = false
    @State private var selectedColor: Color = .primary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    /// Whether the native PKToolPicker is shown (hidden by default; custom toolbar used).
    @State private var showSystemToolPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    assignmentHeader
                    toolBar
                    canvasArea
                    bottomBar
                }
            }
            .navigationTitle("Drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveTrigger.toggle()
                        drawingService.saveDrawing(for: assignment.id)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .sensoryFeedback(.success, trigger: saveTrigger)
                }
            }
            .onAppear {
                drawingService.loadDrawing(for: assignment.id)
            }
            .onDisappear {
                // Auto-save when leaving the canvas
                drawingService.saveDrawing(for: assignment.id)
            }
            .alert("Clear Canvas", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) {
                    drawingService.clearCanvas()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear the entire canvas? This cannot be undone.")
            }
            .alert("Submit Drawing", isPresented: $showSubmitConfirmation) {
                Button("Submit", role: .destructive) {
                    Task { await submitDrawing() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Submit this drawing as your assignment response for \"\(assignment.title)\"?")
            }
            .alert("Submitted!", isPresented: $showSubmitSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your drawing has been submitted successfully.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(drawingService.error ?? "An unknown error occurred.")
            }
            .onChange(of: drawingService.error) { _, newValue in
                if newValue != nil {
                    showError = true
                }
            }
            .sheet(isPresented: $showBackgroundPicker) {
                backgroundPickerSheet
            }
            .sheet(isPresented: $showExportSheet) {
                if let image = exportedImage {
                    DrawingShareSheetView(items: [image])
                }
            }
        }
    }

    // MARK: - Assignment Header

    private var assignmentHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(assignment.isOverdue ? .red : .orange)
                Text(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(assignment.points) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tool Bar

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Drawing tools
                ForEach(DrawingTool.allCases) { tool in
                    toolButton(for: tool)
                }

                Divider()
                    .frame(height: 28)

                // Color indicators
                ForEach(colorOptions, id: \.self) { color in
                    colorButton(for: color)
                }

                Divider()
                    .frame(height: 28)

                // Background template
                Button {
                    hapticTrigger.toggle()
                    showBackgroundPicker = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: drawingService.selectedBackground.iconName)
                            .font(.body)
                        Text("BG")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.systemGray5), in: .rect(cornerRadius: 10))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func toolButton(for tool: DrawingTool) -> some View {
        Button {
            hapticTrigger.toggle()
            drawingService.selectedTool = tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.iconName)
                    .font(.body)
                    .symbolVariant(drawingService.selectedTool == tool ? .fill : .none)
                Text(tool.displayName)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(drawingService.selectedTool == tool ? .white : .primary)
            .frame(width: 52, height: 48)
            .background(
                drawingService.selectedTool == tool
                    ? AnyShapeStyle(.indigo.gradient)
                    : AnyShapeStyle(Color(UIColor.systemGray5)),
                in: .rect(cornerRadius: 10)
            )
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    private var colorOptions: [UIColor] {
        [.label, .systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple]
    }

    private func colorButton(for color: UIColor) -> some View {
        Button {
            hapticTrigger.toggle()
            drawingService.strokeColor = color
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 28, height: 28)
                .overlay {
                    if drawingService.strokeColor == color {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                            .frame(width: 28, height: 28)
                        Circle()
                            .strokeBorder(Color(color), lineWidth: 1)
                            .frame(width: 32, height: 32)
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        ZStack {
            // Background template
            CanvasBackgroundView(background: drawingService.selectedBackground)
                .ignoresSafeArea(edges: .horizontal)

            // PencilKit canvas
            PencilCanvasRepresentable(
                drawing: $drawingService.currentDrawing,
                tool: drawingService.currentPKTool(),
                showToolPicker: showSystemToolPicker,
                onDrawingChanged: {
                    drawingService.recordStroke()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Undo
            Button {
                hapticTrigger.toggle()
                undoManager?.undo()
                drawingService.recordUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.bold())
            }
            .disabled(drawingService.undoCount == 0)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            // Redo
            Button {
                hapticTrigger.toggle()
                undoManager?.redo()
                drawingService.recordRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.body.bold())
            }
            .disabled(drawingService.redoCount == 0)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Divider()
                .frame(height: 24)

            // Clear canvas
            Button(role: .destructive) {
                hapticTrigger.toggle()
                showClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.body)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            Spacer()

            // Export as image
            Button {
                hapticTrigger.toggle()
                exportedImage = drawingService.exportAsImage()
                if exportedImage != nil {
                    showExportSheet = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                    Text("Export")
                        .font(.caption.bold())
                }
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            // Submit drawing
            Button {
                hapticTrigger.toggle()
                showSubmitConfirmation = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                    Text("Submit")
                        .font(.caption.bold())
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isSubmitting || assignment.isSubmitted)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Background Picker Sheet

    private var backgroundPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CanvasBackground.allCases) { bg in
                    Button {
                        drawingService.selectedBackground = bg
                        showBackgroundPicker = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: bg.iconName)
                                .font(.title3)
                                .foregroundStyle(.indigo)
                                .frame(width: 32)

                            Text(bg.displayName)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            if drawingService.selectedBackground == bg {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Canvas Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showBackgroundPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Submission Logic

    private func submitDrawing() async {
        isSubmitting = true
        defer { isSubmitting = false }

        // Save drawing to disk first
        drawingService.saveDrawing(for: assignment.id)

        // Build submission content from the drawing
        let strokeCount = drawingService.currentDrawing.strokes.count
        let submissionContent = "[PencilKit Drawing: \(strokeCount) stroke\(strokeCount == 1 ? "" : "s")]"

        viewModel.submitAssignment(assignment, text: submissionContent)
        showSubmitSuccess = true
    }
}

// MARK: - Share Sheet

/// Minimal `UIActivityViewController` wrapper for sharing exported images.
private struct DrawingShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
