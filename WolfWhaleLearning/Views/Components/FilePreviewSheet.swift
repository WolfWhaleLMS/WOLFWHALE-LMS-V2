import SwiftUI

/// A sheet that previews any file type with appropriate viewer.
/// PDFs use PDFViewerView, images support pinch-to-zoom, text files display
/// with monospaced font, and unsupported types show a placeholder.
struct FilePreviewSheet: View {
    let file: FileItem
    let fileData: Data?
    let onDismiss: () -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if let data = fileData {
                    previewContent(data: data)
                } else {
                    loadingOrUnavailable
                }
            }
            .navigationTitle(file.fileName + "." + file.fileExtension)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        hapticTrigger.toggle()
                        onDismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }

                ToolbarItem(placement: .primaryAction) {
                    if let data = fileData {
                        ShareLink(
                            item: FileDataTransferable(
                                data: data,
                                fileName: file.fileName + "." + file.fileExtension
                            ),
                            preview: SharePreview(
                                file.fileName,
                                image: Image(systemName: file.iconName)
                            )
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Content Router

    @ViewBuilder
    private func previewContent(data: Data) -> some View {
        switch file.fileType {
        case .pdf:
            pdfPreview(data: data)
        case .image:
            imagePreview(data: data)
        case .text:
            textPreview(data: data)
        default:
            unsupportedPreview
        }
    }

    // MARK: - PDF Preview

    private func pdfPreview(data: Data) -> some View {
        PDFViewerView(data: data)
            .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Image Preview (Zoomable)

    @ViewBuilder
    private func imagePreview(data: Data) -> some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            GeometryReader { geometry in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let delta = value.magnification / lastZoomScale
                                lastZoomScale = value.magnification
                                zoomScale = min(max(zoomScale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastZoomScale = 1.0
                                if zoomScale < 1.0 {
                                    withAnimation(.snappy) {
                                        zoomScale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if zoomScale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) {
                            if zoomScale > 1.0 {
                                zoomScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                zoomScale = 2.5
                            }
                        }
                    }
            }
        } else {
            unsupportedPreview
        }
        #else
        unsupportedPreview
        #endif
    }

    // MARK: - Text Preview

    private func textPreview(data: Data) -> some View {
        ScrollView {
            if let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Unable to decode text content.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
    }

    // MARK: - Unsupported Preview

    private var unsupportedPreview: some View {
        VStack(spacing: 20) {
            Image(systemName: file.iconName)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Preview not available")
                .font(.title3.bold())

            Text("This file type cannot be previewed in the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(file.formattedSize)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
    }

    // MARK: - Loading / Unavailable

    private var loadingOrUnavailable: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading file...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - File Data Transferable

struct FileDataTransferable: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { item in
            item.data
        }
    }
}
