import SwiftUI

struct AuditLogView: View {
    let viewModel: AppViewModel

    // MARK: - State

    @State private var logs: [AuditLogDTO] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    // MARK: - Filters

    @State private var selectedAction: String?
    @State private var userIdFilter: String = ""
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var showFilters = false
    @State private var hapticTrigger = false

    private let actionOptions: [(label: String, value: String)] = [
        ("All", ""),
        ("Login", AuditAction.login),
        ("Logout", AuditAction.logout),
        ("Create", AuditAction.create),
        ("Read", AuditAction.read),
        ("Update", AuditAction.update),
        ("Delete", AuditAction.delete),
        ("Grade Change", AuditAction.gradeChange),
        ("Export", AuditAction.export)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && logs.isEmpty {
                    loadingView
                } else if let error = loadError, logs.isEmpty {
                    errorView(error)
                } else if logs.isEmpty {
                    emptyView
                } else {
                    logList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Audit Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) { showFilters.toggle() }
                    } label: {
                        Label("Filters", systemImage: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .task {
                await loadLogs(reset: true)
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    // MARK: - Log List

    private var logList: some View {
        List {
            if showFilters {
                filterSection
            }

            Section {
                ForEach(logs) { entry in
                    logRow(entry)
                        .onAppear {
                            if entry.id == logs.last?.id, hasMore, !isLoading {
                                Task { await loadLogs(reset: false) }
                            }
                        }
                }
            } header: {
                Text("\(logs.count) entr\(logs.count == 1 ? "y" : "ies") loaded")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            if isLoading && !logs.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
                .listRowBackground(Color.clear)
            }

            if !hasMore && !logs.isEmpty {
                HStack {
                    Spacer()
                    Text("End of log")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadLogs(reset: true)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        Section("Filters") {
            // Action filter
            HStack {
                Label("Action", systemImage: "bolt.fill")
                    .foregroundStyle(Color(.label))
                Spacer()
                Menu {
                    ForEach(actionOptions, id: \.value) { option in
                        Button {
                            selectedAction = option.value.isEmpty ? nil : option.value
                            Task { await loadLogs(reset: true) }
                        } label: {
                            if (selectedAction ?? "") == (option.value.isEmpty ? nil : option.value) ?? "" {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Text(selectedAction.flatMap { action in actionOptions.first(where: { $0.value == action })?.label } ?? "All")
                        .foregroundStyle(.blue)
                }
            }

            // User ID filter
            HStack {
                Label("User ID", systemImage: "person.fill")
                    .foregroundStyle(Color(.label))
                TextField("Filter by user ID", text: $userIdFilter)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        Task { await loadLogs(reset: true) }
                    }
            }

            // Date range
            DatePicker("From", selection: $startDate, displayedComponents: .date)
                .foregroundStyle(Color(.label))
                .onChange(of: startDate) { _, _ in
                    Task { await loadLogs(reset: true) }
                }

            DatePicker("To", selection: $endDate, displayedComponents: .date)
                .foregroundStyle(Color(.label))
                .onChange(of: endDate) { _, _ in
                    Task { await loadLogs(reset: true) }
                }

            // Clear filters button
            Button {
                hapticTrigger.toggle()
                selectedAction = nil
                userIdFilter = ""
                startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                endDate = Date()
                Task { await loadLogs(reset: true) }
            } label: {
                Label("Clear Filters", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    // MARK: - Log Row

    private func logRow(_ entry: AuditLogDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconForAction(entry.action))
                    .font(.subheadline)
                    .foregroundStyle(colorForAction(entry.action))
                    .frame(width: 24, height: 24)

                Text(entry.action.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))

                Spacer()

                Text(actionBadge(entry.action))
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorForAction(entry.action).opacity(0.12), in: Capsule())
                    .foregroundStyle(colorForAction(entry.action))
            }

            HStack(spacing: 16) {
                if let entityType = entry.entityType as String? {
                    Label(entityType.capitalized, systemImage: iconForEntityType(entityType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let entityId = entry.entityId, !entityId.isEmpty {
                    Text(String(entityId.prefix(8)) + "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            if let userId = entry.userId, !userId.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(userId.prefix(8)) + "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if let details = entry.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let timestamp = entry.timestamp ?? entry.createdAt {
                Text(formatTimestamp(timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.action.replacingOccurrences(of: "_", with: " ")) on \(entry.entityType), \(formatTimestamp(entry.timestamp ?? entry.createdAt ?? ""))")
    }

    // MARK: - Loading / Error / Empty States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading audit logs...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Failed to Load Logs")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await loadLogs(reset: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Audit Entries")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Audit log entries will appear here as users interact with the system.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadLogs(reset: Bool) async {
        if reset {
            offset = 0
            hasMore = true
        }
        guard hasMore, !isLoading else { return }

        isLoading = true
        loadError = nil

        do {
            let auditService = AuditLogService()
            let results = try await auditService.fetchLogs(
                action: selectedAction,
                userId: userIdFilter.isEmpty ? nil : userIdFilter.trimmingCharacters(in: .whitespaces),
                startDate: startDate,
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: endDate),
                offset: offset,
                limit: pageSize
            )

            if reset {
                logs = results
            } else {
                logs.append(contentsOf: results)
            }

            offset += results.count
            hasMore = results.count >= pageSize
        } catch {
            loadError = error.localizedDescription
            #if DEBUG
            print("[AuditLogView] Failed to load logs: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func iconForAction(_ action: String) -> String {
        switch action {
        case AuditAction.login: return "arrow.right.circle.fill"
        case AuditAction.logout: return "arrow.left.circle.fill"
        case AuditAction.create: return "plus.circle.fill"
        case AuditAction.read: return "eye.fill"
        case AuditAction.update: return "pencil.circle.fill"
        case AuditAction.delete: return "trash.fill"
        case AuditAction.gradeChange: return "checkmark.seal.fill"
        case AuditAction.export: return "square.and.arrow.up.fill"
        default: return "doc.fill"
        }
    }

    private func colorForAction(_ action: String) -> Color {
        switch action {
        case AuditAction.login: return .green
        case AuditAction.logout: return .orange
        case AuditAction.create: return .blue
        case AuditAction.read: return .teal
        case AuditAction.update: return .purple
        case AuditAction.delete: return .red
        case AuditAction.gradeChange: return .indigo
        case AuditAction.export: return .mint
        default: return .gray
        }
    }

    private func actionBadge(_ action: String) -> String {
        action.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private func iconForEntityType(_ entityType: String) -> String {
        switch entityType {
        case AuditEntityType.course: return "book.fill"
        case AuditEntityType.assignment: return "doc.text.fill"
        case AuditEntityType.grade: return "checkmark.seal.fill"
        case AuditEntityType.user: return "person.fill"
        case AuditEntityType.enrollment: return "person.badge.plus"
        case AuditEntityType.quiz: return "questionmark.circle.fill"
        case AuditEntityType.message: return "message.fill"
        case AuditEntityType.announcement: return "megaphone.fill"
        default: return "doc.fill"
        }
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso.date(from: timestamp) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        // Fallback: try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: timestamp) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        return timestamp
    }
}
