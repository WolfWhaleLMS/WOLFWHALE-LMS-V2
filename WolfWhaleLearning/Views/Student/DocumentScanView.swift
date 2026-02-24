import SwiftUI
import VisionKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Document Camera Representable

/// Wraps `VNDocumentCameraViewController` for use in SwiftUI via the coordinator pattern.
struct DocumentCameraRepresentable: UIViewControllerRepresentable {

    /// Called when the user finishes scanning and we have one or more images.
    let onScanComplete: ([UIImage]) -> Void
    /// Called when the user cancels or the scanner encounters an error.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete, onCancel: onCancel)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScanComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanComplete = onScanComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: pageIndex))
            }
            controller.dismiss(animated: true) { [onScanComplete] in
                onScanComplete(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [onCancel] in
                onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) { [onCancel] in
                onCancel()
            }
        }
    }
}

// MARK: - Document Scan View

struct DocumentScanView: View {
    let assignment: Assignment
    let viewModel: AppViewModel

    @State private var scannerService = DocumentScannerService()
    @State private var showScanner = false
    @State private var selectedPage: ScannedPage?
    @State private var showPageDetail = false
    @State private var showExtractedText = false
    @State private var isSubmitting = false
    @State private var showSubmitSuccess = false
    @State private var showError = false
    @State private var hapticTrigger = false
    @State private var editMode: EditMode = .inactive
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        assignmentHeader
                        scanActionSection

                        if !scannerService.scannedPages.isEmpty {
                            pagesGridSection
                            extractedTextSection
                            submitSection
                        } else if scannerService.scanStatus == .idle {
                            emptyStateView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }

                // Processing overlay
                if scannerService.isLoading {
                    processingOverlay
                }
            }
            .navigationTitle("Scan Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }

                if !scannerService.scannedPages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentCameraRepresentable(
                    onScanComplete: { images in
                        showScanner = false
                        Task {
                            await scannerService.processScannedImages(images)
                        }
                    },
                    onCancel: {
                        showScanner = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPageDetail) {
                if let page = selectedPage {
                    PageDetailView(page: page)
                }
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerService.error ?? "An unknown error occurred.")
            }
            .alert("Submitted!", isPresented: $showSubmitSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your scanned homework has been submitted successfully.")
            }
            .onChange(of: scannerService.error) { _, newValue in
                if newValue != nil {
                    showError = true
                }
            }
        }
    }

    // MARK: - Assignment Header

    private var assignmentHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(assignment.title)
                .font(.title3.bold())

            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.blue)
                Text(assignment.courseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundStyle(assignment.isOverdue ? .red : .orange)
                    Text(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                    Text("\(assignment.points) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if assignment.isOverdue {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("This assignment is past due")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Scan Action Section

    private var scanActionSection: some View {
        VStack(spacing: 12) {
            Button {
                hapticTrigger.toggle()
                scannerService.scanStatus = .scanning
                showScanner = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title3)
                    Text(scannerService.scannedPages.isEmpty ? "Scan Document" : "Scan More Pages")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            if scannerService.scanStatus == .complete {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(scannerService.scannedPages.count) page\(scannerService.scannedPages.count == 1 ? "" : "s") scanned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Pages Grid Section

    private var pagesGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scanned Pages")
                    .font(.headline)
                Spacer()
                Text("\(scannerService.scannedPages.count) page\(scannerService.scannedPages.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(scannerService.scannedPages) { page in
                    pageCard(for: page)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func pageCard(for page: ScannedPage) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 6) {
                // Thumbnail
                if let uiImage = UIImage(data: page.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 100, height: 130)
                        .overlay {
                            Image(systemName: "doc.questionmark")
                                .foregroundStyle(.secondary)
                        }
                }

                Text("Page \(page.pageNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                selectedPage = page
                showPageDetail = true
            }

            // Delete button in edit mode
            if editMode == .active {
                Button {
                    withAnimation {
                        scannerService.deletePage(page.id)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    // MARK: - Extracted Text Section

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showExtractedText.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "text.viewfinder")
                        .foregroundStyle(.blue)
                    Text("Extracted Text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showExtractedText ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if showExtractedText {
                if scannerService.extractedText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "text.badge.xmark")
                            .foregroundStyle(.orange)
                        Text("No text could be extracted from the scanned pages.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemGray6), in: .rect(cornerRadius: 10))
                } else {
                    ScrollView {
                        Text(scannerService.extractedText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(12)
                    .background(Color(UIColor.systemGray6), in: .rect(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        VStack(spacing: 12) {
            Button {
                hapticTrigger.toggle()
                Task {
                    await submitHomework()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Submit as Homework")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isSubmitting || assignment.isSubmitted)
            .hapticFeedback(.success, trigger: showSubmitSuccess)

            if assignment.isSubmitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Already submitted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(role: .destructive) {
                withAnimation {
                    scannerService.reset()
                    editMode = .inactive
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clear All Pages")
                        .font(.subheadline)
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Pages Scanned")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text("Use the scanner to capture pages of your homework. The app will extract text and create a PDF automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: scannerService.processingProgress) {
                    Text("Processing scanned pages...")
                        .font(.subheadline.bold())
                }
                .progressViewStyle(.linear)
                .tint(.blue)

                Text("Running OCR text extraction")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(scannerService.processingProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Submission Logic

    private func submitHomework() async {
        isSubmitting = true
        defer { isSubmitting = false }

        // Build submission text from extracted OCR content
        var submissionContent = ""

        if !scannerService.extractedText.isEmpty {
            submissionContent = scannerService.extractedText
        } else {
            submissionContent = "[Scanned Document: \(scannerService.scannedPages.count) page(s) — no text extracted]"
        }

        viewModel.submitAssignment(assignment, text: submissionContent)
        showSubmitSuccess = true
    }
}

// MARK: - Page Detail View

/// Full-screen view for inspecting a single scanned page.
private struct PageDetailView: View {
    let page: ScannedPage
    @State private var showText = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Full-size image
                        if let uiImage = UIImage(data: page.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.rect(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                                .padding(.horizontal, 8)
                        }

                        // Page text toggle
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showText.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "text.viewfinder")
                                        .foregroundStyle(.blue)
                                    Text("Extracted Text")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: showText ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)

                            if showText {
                                if page.extractedText.isEmpty {
                                    Text("No text extracted from this page.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(UIColor.systemGray6), in: .rect(cornerRadius: 10))
                                } else {
                                    Text(page.extractedText)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(UIColor.systemGray6), in: .rect(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Page \(page.pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
