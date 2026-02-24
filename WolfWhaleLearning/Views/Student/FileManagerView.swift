import SwiftUI

/// A view showing all files uploaded by the current student, grouped by course.
/// Supports searching, previewing, sharing, and deleting files.
struct FileManagerView: View {
    let viewModel: AppViewModel

    @State private var fileService = FileManagerService()
    @State private var searchText = ""
    @State private var selectedFile: FileItem?
    @State private var previewData: Data?
    @State private var isLoadingPreview = false
    @State private var showPreview = false
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: FileItem?
    @State private var hapticTrigger = false

    // MARK: - Filtered & Grouped

    private var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return fileService.files
        }
        let query = searchText.lowercased()
        return fileService.files.filter { file in
            file.fileName.lowercased().contains(query)
                || file.fileExtension.lowercased().contains(query)
                || (file.courseName?.lowercased().contains(query) ?? false)
                || (file.assignmentName?.lowercased().contains(query) ?? false)
        }
    }

    private var groupedByCourse: [(courseName: String, files: [FileItem])] {
        let grouped = Dictionary(grouping: filteredFiles) { $0.courseName ?? "Uncategorized" }
        return grouped
            .map { (courseName: $0.key, files: $0.value) }
            .sorted { $0.courseName.localizedStandardCompare($1.courseName) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if fileService.isLoading && fileService.files.isEmpty {
                loadingState
            } else if fileService.files.isEmpty {
                emptyState
            } else if filteredFiles.isEmpty {
                noResultsState
            } else {
                fileListContent
            }
        }
        .navigationTitle("My Files")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search files...")
        .refreshable {
            await loadFiles()
        }
        .task {
            await loadFiles()
        }
        .sheet(isPresented: $showPreview) {
            if let file = selectedFile {
                FilePreviewSheet(
                    file: file,
                    fileData: previewData,
                    onDismiss: {
                        showPreview = false
                        selectedFile = nil
                        previewData = nil
                    }
                )
            }
        }
        .alert("Delete File", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    hapticTrigger.toggle()
                    Task {
                        _ = await fileService.deleteFile(
                            fileId: file.id,
                            storagePath: extractStoragePath(from: file.storageURL)
                        )
                    }
                    fileToDelete = nil
                }
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete \"\(file.fileName).\(file.fileExtension)\"? This cannot be undone.")
            }
        }
        .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    // MARK: - File List Content

    private var fileListContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats header
                statsHeader

                // Grouped files
                ForEach(groupedByCourse, id: \.courseName) { group in
                    courseSection(courseName: group.courseName, files: group.files)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(label: "Total Files", value: "\(fileService.files.count)", color: .indigo)
            statCard(label: "Courses", value: "\(groupedByCourse.count)", color: .purple)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Course Section

    private func courseSection(courseName: String, files: [FileItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.indigo)
                Text(courseName)
                    .font(.headline)
                Spacer()
                Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            // File rows
            ForEach(files) { file in
                fileRow(file)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - File Row

    private func fileRow(_ file: FileItem) -> some View {
        Button {
            hapticTrigger.toggle()
            openPreview(for: file)
        } label: {
            HStack(spacing: 12) {
                // File icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(fileColor(for: file.fileType).opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: file.iconName)
                            .font(.title3)
                            .foregroundStyle(fileColor(for: file.fileType))
                    }

                // File info
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(file.fileName).\(file.fileExtension)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if file.fileSize > 0 {
                            Text(file.formattedSize)
                        }
                        Text(file.uploadDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let assignmentName = file.assignmentName {
                        Text(assignmentName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Loading indicator or chevron
                if isLoadingPreview && selectedFile?.id == file.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                fileToDelete = file
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                openPreview(for: file)
            } label: {
                Label("Preview", systemImage: "eye")
            }

            Button(role: .destructive) {
                fileToDelete = file
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your files...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("No Files Yet")
                .font(.title3.bold())

            Text("Files you upload with your assignment submissions will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Results")
                .font(.title3.bold())

            Text("No files match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func loadFiles() async {
        guard let user = viewModel.currentUser else { return }
        await fileService.fetchUserFiles(userId: user.id)
    }

    private func openPreview(for file: FileItem) {
        selectedFile = file
        isLoadingPreview = true
        Task {
            let data = await fileService.getFilePreviewData(for: file)
            previewData = data
            isLoadingPreview = false
            showPreview = true
        }
    }

    private func fileColor(for type: FileItem.FileType) -> Color {
        switch type {
        case .pdf: return .red
        case .image: return .blue
        case .document: return .indigo
        case .spreadsheet: return .green
        case .presentation: return .orange
        case .text: return .purple
        case .other: return .gray
        }
    }

    private func extractStoragePath(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "" }
        let components = url.pathComponents
        if let bucketIndex = components.firstIndex(of: FileUploadService.Bucket.assignmentSubmissions) {
            let pathComponents = components[(bucketIndex + 1)...]
            return pathComponents.joined(separator: "/")
        }
        return url.lastPathComponent
    }
}
