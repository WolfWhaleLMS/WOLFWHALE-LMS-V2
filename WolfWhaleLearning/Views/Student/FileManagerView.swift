import SwiftUI
import QuickLook
import UniformTypeIdentifiers

// MARK: - FileManagerView

struct FileManagerView: View {
    let viewModel: AppViewModel
    @State private var fileService = FileManagerService()
    @State private var selectedTab: FileTab = .byCourse
    @State private var searchText = ""
    @State private var showDocumentPicker = false
    @State private var selectedCourseForImport: Course?
    @State private var showCoursePickerForImport = false
    @State private var previewFile: LMSFile?
    @State private var showQuickLook = false
    @State private var expandedCourses: Set<String> = []
    @State private var hapticTrigger = false
    @State private var showDeleteConfirmation = false
    @State private var fileToDelete: LMSFile?

    enum FileTab: String, CaseIterable {
        case byCourse = "By Course"
        case allFiles = "All Files"
        case recent = "Recent"
    }

    // MARK: - Filtered Files

    private var filteredAllFiles: [LMSFile] {
        let all = fileService.getAllFiles()
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.courseName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var recentFiles: [LMSFile] {
        let all = fileService.getAllFiles()
        let filtered: [LMSFile]
        if searchText.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.courseName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return Array(filtered.prefix(10))
    }

    private var filteredCourseIds: [String] {
        let ids = fileService.courseFiles.keys.sorted()
        guard !searchText.isEmpty else { return ids }
        return ids.filter { courseId in
            let files = fileService.courseFiles[courseId] ?? []
            return files.contains {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.courseName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func filteredFiles(for courseId: String) -> [LMSFile] {
        let files = fileService.getFiles(for: courseId)
        guard !searchText.isEmpty else { return files }
        return files.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.courseName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                storageBar
                tabPicker
                fileContent
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Files")
        .searchable(text: $searchText, prompt: "Search files...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticTrigger.toggle()
                    showCoursePickerForImport = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.bold())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Import file")
                .accessibilityHint("Double tap to import a file from the Files app")
            }
        }
        .sheet(isPresented: $showCoursePickerForImport) {
            coursePickerSheet
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let course = selectedCourseForImport {
                    fileService.importFile(
                        from: url,
                        courseId: course.id.uuidString,
                        courseName: course.title
                    )
                }
            }
        }
        .sheet(isPresented: $showQuickLook) {
            if let file = previewFile {
                QuickLookPreview(url: file.fileURL)
                    .ignoresSafeArea()
            }
        }
        .alert("Delete File", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    withAnimation {
                        fileService.deleteFile(file)
                    }
                    fileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete \"\(file.name)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Storage Bar

    private var storageBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Text("Storage Used")
                    .font(.subheadline.bold())
                Spacer()
                Text(fileService.totalStorageUsed)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Visual storage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: storageBarWidth(totalWidth: geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                let totalFiles = fileService.getAllFiles().count
                let courseCount = fileService.courseFiles.keys.count
                Text("\(totalFiles) file\(totalFiles == 1 ? "" : "s") across \(courseCount) course\(courseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Storage used: \(fileService.totalStorageUsed)")
    }

    /// Computes the storage bar fill width. Caps at a visual maximum of 5 GB.
    private func storageBarWidth(totalWidth: CGFloat) -> CGFloat {
        let totalBytes = fileService.getAllFiles().reduce(Int64(0)) { $0 + $1.fileSize }
        let maxBytes: Int64 = 5 * 1024 * 1024 * 1024 // 5 GB visual cap
        let fraction = min(Double(totalBytes) / Double(maxBytes), 1.0)
        return max(totalWidth * fraction, totalBytes > 0 ? 4 : 0)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(FileTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - File Content

    @ViewBuilder
    private var fileContent: some View {
        switch selectedTab {
        case .byCourse:
            byCourseContent
        case .allFiles:
            allFilesContent
        case .recent:
            recentContent
        }
    }

    // MARK: - By Course Content

    private var byCourseContent: some View {
        VStack(spacing: 12) {
            if filteredCourseIds.isEmpty {
                emptyState(
                    icon: "folder.fill.badge.questionmark",
                    title: "No Files Yet",
                    message: "Tap + to import documents from the Files app."
                )
            } else {
                ForEach(filteredCourseIds, id: \.self) { courseId in
                    courseSection(courseId: courseId)
                }
            }
        }
    }

    private func courseSection(courseId: String) -> some View {
        let files = filteredFiles(for: courseId)
        let courseName = files.first?.courseName ?? courseId
        let isExpanded = expandedCourses.contains(courseId)

        return VStack(spacing: 0) {
            // Course header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedCourses.remove(courseId)
                    } else {
                        expandedCourses.insert(courseId)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(courseName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(courseName), \(files.count) files")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")

            // Expanded file list
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(files) { file in
                        fileRow(file)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - All Files Content

    private var allFilesContent: some View {
        VStack(spacing: 2) {
            if filteredAllFiles.isEmpty {
                emptyState(
                    icon: "doc.fill",
                    title: "No Files",
                    message: searchText.isEmpty
                        ? "Tap + to import your first document."
                        : "No files match your search."
                )
            } else {
                ForEach(filteredAllFiles) { file in
                    fileRow(file)
                }
            }
        }
    }

    // MARK: - Recent Content

    private var recentContent: some View {
        VStack(spacing: 2) {
            if recentFiles.isEmpty {
                emptyState(
                    icon: "clock.fill",
                    title: "No Recent Files",
                    message: "Recently added files will appear here."
                )
            } else {
                ForEach(recentFiles) { file in
                    fileRow(file)
                }
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ file: LMSFile) -> some View {
        Button {
            previewFile = file
            showQuickLook = true
        } label: {
            HStack(spacing: 12) {
                // File type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fileService.fileColor(for: file.fileType).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: fileService.fileIcon(for: file.fileType))
                        .font(.body)
                        .foregroundStyle(fileService.fileColor(for: file.fileType))
                }

                // File info
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("--")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)

                        Text(file.dateAdded, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                fileService.exportToFilesApp(file)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                fileToDelete = file
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                fileToDelete = file
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                fileService.exportToFilesApp(file)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name), \(file.formattedSize), added \(file.dateAdded.formatted(.dateTime.month(.abbreviated).day().year()))")
        .accessibilityHint("Double tap to preview. Use context menu for more options.")
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Course Picker Sheet

    private var coursePickerSheet: some View {
        NavigationStack {
            List {
                if viewModel.courses.isEmpty {
                    ContentUnavailableView(
                        "No Courses",
                        systemImage: "book.closed.fill",
                        description: Text("You need to be enrolled in at least one course to import files.")
                    )
                } else {
                    Section {
                        ForEach(viewModel.courses) { course in
                            Button {
                                selectedCourseForImport = course
                                showCoursePickerForImport = false
                                // Small delay so the sheet dismiss animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    showDocumentPicker = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: course.iconSystemName)
                                        .font(.title3)
                                        .foregroundStyle(Theme.courseColor(course.colorName))
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text(course.teacherName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    let count = fileService.getFiles(for: course.id.uuidString).count
                                    if count > 0 {
                                        Text("\(count) file\(count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select a course for the imported file")
                    }
                }
            }
            .navigationTitle("Import File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCoursePickerForImport = false
                    }
                }
            }
        }
    }
}

// MARK: - DocumentPickerView

/// A UIViewControllerRepresentable wrapping UIDocumentPickerViewController for importing files.
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    /// Content types supported for import.
    private let contentTypes: [UTType] = [
        .pdf,
        .jpeg,
        .png,
        .image,
        .plainText,
        .rtf,
        .spreadsheet,
        .presentation,
        .data,
        UTType("com.microsoft.word.doc") ?? .data,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType("com.microsoft.excel.xls") ?? .data,
        UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
        UTType("com.microsoft.powerpoint.ppt") ?? .data,
        UTType("org.openxmlformats.presentationml.presentation") ?? .data
    ]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - QuickLookPreview

/// A UIViewControllerRepresentable wrapping QLPreviewController for previewing files.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let controller = uiViewController.viewControllers.first as? QLPreviewController {
            controller.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
