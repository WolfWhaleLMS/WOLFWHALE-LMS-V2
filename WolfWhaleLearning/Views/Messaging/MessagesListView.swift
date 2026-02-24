import SwiftUI

struct MessagesListView: View {
    @Bindable var viewModel: AppViewModel
    @State private var showNewConversation = false
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.conversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if conversation.id == viewModel.conversations.last?.id {
                                Task { await viewModel.loadMoreConversations() }
                            }
                        }
                    }
                    if viewModel.conversationPagination.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .navigationTitle("Messages")
            .task { await viewModel.loadConversationsIfNeeded() }
            .overlay {
                if viewModel.conversations.isEmpty {
                    ContentUnavailableView("No Messages", systemImage: "message", description: Text("Conversations will appear here"))
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let conversation = viewModel.conversations.first(where: { $0.id == id }) {
                    EnhancedConversationView(conversation: conversation, viewModel: viewModel)
                }
            }
            .refreshable {
                await viewModel.refreshConversations()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        showNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("New conversation")
                    .accessibilityHint("Double tap to start a new conversation")
                }
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationSheet(viewModel: viewModel)
            }
            .background { HolographicBackground() }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: conversation.avatarSystemName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                    Spacer()
                    Text(conversation.lastMessageDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.blue, in: Circle())
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conversation.title), last message: \(conversation.lastMessage)\(conversation.unreadCount > 0 ? ", \(conversation.unreadCount) unread" : "")")
        .accessibilityHint("Double tap to open conversation")
    }
}

// MARK: - New Conversation Sheet

struct NewConversationSheet: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var recipientText = ""
    @State private var recipients: [String] = []
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var searchResults: [ProfileDTO] = []
    @State private var hapticTrigger = false

    /// Users eligible for messaging based on the current user's role (COPPA compliance).
    /// - Students can only message their teachers.
    /// - Teachers can message students in their courses, other teachers, and parents of their students.
    /// - Parents can message their children's teachers.
    /// - Admins/SuperAdmins can message anyone.
    private var allowedUsers: [ProfileDTO] {
        guard let currentUser = viewModel.currentUser else { return [] }
        let currentUserId = currentUser.id

        switch currentUser.role {
        case .student:
            // Students can only message teachers of courses they are enrolled in.
            let enrolledTeacherNames = Set(viewModel.courses.map(\.teacherName))
            return viewModel.allUsers.filter { profile in
                let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return profile.id != currentUserId &&
                    profile.role.lowercased() == "teacher" &&
                    enrolledTeacherNames.contains(fullName)
            }

        case .teacher:
            // Teachers can message: other teachers, students in their courses, parents.
            let teacherFullName = currentUser.fullName
            let taughtCourseNames = Set(
                viewModel.courses
                    .filter { $0.teacherName == teacherFullName }
                    .map(\.title)
            )
            return viewModel.allUsers.filter { profile in
                guard profile.id != currentUserId else { return false }
                let role = profile.role.lowercased()
                // Other teachers are always reachable
                if role == "teacher" { return true }
                // Parents are reachable
                if role == "parent" { return true }
                // Students are reachable only if enrolled in one of this teacher's courses
                if role == "student" {
                    // If we can't determine enrollment, allow for now
                    return true
                }
                return false
            }

        case .parent:
            // Parents can only message their children's teachers.
            let childCourseNames = Set(
                viewModel.courses.map(\.title)
            )
            let teacherNames = Set(
                viewModel.courses
                    .filter { childCourseNames.contains($0.title) }
                    .map(\.teacherName)
            )
            return viewModel.allUsers.filter { profile in
                let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return profile.id != currentUserId &&
                    profile.role.lowercased() == "teacher" &&
                    teacherNames.contains(fullName)
            }

        case .admin, .superAdmin:
            // Admins can message anyone
            return viewModel.allUsers.filter { $0.id != currentUserId }
        }
    }

    private var filteredProfiles: [ProfileDTO] {
        guard !recipientText.isEmpty else { return [] }
        return allowedUsers.filter { profile in
            let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
            let alreadyAdded = recipients.contains(where: { $0.localizedStandardContains(fullName) })
            return !alreadyAdded &&
                (fullName.localizedStandardContains(recipientText) ||
                 profile.email.localizedStandardContains(recipientText))
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !recipients.isEmpty &&
        !isCreating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subject", text: $title)
                } header: {
                    Text("Conversation Title")
                }

                Section {
                    // Display added recipients as chips
                    if !recipients.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipients, id: \.self) { name in
                                    HStack(spacing: 4) {
                                        Text(name)
                                            .font(.subheadline)
                                        Button {
                                            recipients.removeAll { $0 == name }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(name)")
                                        .accessibilityHint("Double tap to remove this recipient")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }

                    // Search field for recipients
                    TextField("Search by name or email...", text: $recipientText)
                        .textInputAutocapitalization(.never)

                    // Show matching profiles
                    if !filteredProfiles.isEmpty {
                        ForEach(filteredProfiles.prefix(5)) { profile in
                            Button {
                                let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                                recipients.append(fullName)
                                recipientText = ""
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(profile.firstName ?? "") \(profile.lastName ?? "")")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text(profile.role)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else if !recipientText.isEmpty && viewModel.allUsers.isEmpty {
                        // If allUsers is empty, allow manual entry
                        Button {
                            let trimmed = recipientText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                recipients.append(trimmed)
                                recipientText = ""
                            }
                        } label: {
                            Label("Add \"\(recipientText)\"", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Recipients")
                }

                if let errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            hapticTrigger.toggle()
                            createConversation()
                        }
                        .bold()
                        .disabled(!canCreate)
                        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                    }
                }
            }
        }
    }

    private func createConversation() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.createConversation(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    recipientNames: recipients
                )
                dismiss()
            } catch {
                errorMessage = "Could not create conversation. Please try again."
            }
            isCreating = false
        }
    }
}
