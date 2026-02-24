import SwiftUI

struct ParentMessagingView: View {
    @Bindable var viewModel: AppViewModel
    let child: ChildInfo

    @State private var selectedTeacher: ProfileDTO?
    @State private var showConversation = false
    @State private var isCreatingConversation = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    // MARK: - Computed Properties

    private var teacherProfiles: [ProfileDTO] {
        let teacherRole = "teacher"
        let courseNames = child.courses.map(\.courseName)

        // Find teachers from allUsers whose courses match the child's courses.
        // We match by checking if any course taught maps to the child's enrolled courses.
        let teachers = viewModel.allUsers.filter { profile in
            profile.role.lowercased() == teacherRole
        }

        // Match teachers who teach the child's enrolled courses.
        // Since ProfileDTO does not carry course info directly, we check
        // if any viewModel.courses with matching names has a teacherName
        // that matches the profile name.
        if !courseNames.isEmpty {
            return teachers.filter { profile in
                let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return viewModel.courses.contains { course in
                    courseNames.contains(course.title) && course.teacherName == fullName
                }
            }
        }

        // No courses enrolled — return empty list instead of all teachers
        return []
    }

    private var parentConversations: [Conversation] {
        guard let userName = viewModel.currentUser?.fullName else { return viewModel.conversations }
        return viewModel.conversations.filter { conversation in
            conversation.participantNames.contains(userName)
        }
    }

    private func courseForTeacher(_ teacher: ProfileDTO) -> String? {
        let fullName = "\(teacher.firstName ?? "") \(teacher.lastName ?? "")"
        return viewModel.courses.first { course in
            course.teacherName == fullName &&
            child.courses.contains(where: { $0.courseName == course.title })
        }?.title
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    childHeader
                    teacherContactsSection
                    existingConversationsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Message Teachers")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if teacherProfiles.isEmpty && parentConversations.isEmpty {
                    ContentUnavailableView(
                        "No Teachers Found",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Teacher contacts will appear here once your child is enrolled in courses.")
                    )
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Child Header

    private var childHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: child.avatarSystemName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.headline)
                Text("\(child.grade) - \(child.courses.count) courses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Teacher Contacts

    private var teacherContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Teachers", systemImage: "person.crop.rectangle.fill")
                    .font(.headline)
                Spacer()
            }

            if teacherProfiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No teachers found for your children's courses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(teacherProfiles) { teacher in
                    teacherCard(teacher)
                }
            }
        }
    }

    private func teacherCard(_ teacher: ProfileDTO) -> some View {
        let fullName = "\(teacher.firstName ?? "") \(teacher.lastName ?? "")"
        let courseName = courseForTeacher(teacher)

        return HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.crop.rectangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(fullName)
                    .font(.subheadline.bold())
                if let courseName {
                    Text(courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                hapticTrigger.toggle()
                startConversation(with: teacher)
            } label: {
                Label("Message", systemImage: "message.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isCreatingConversation)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Existing Conversations

    private var existingConversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !parentConversations.isEmpty {
                HStack {
                    Label("Recent Conversations", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                    Spacer()
                }

                ForEach(parentConversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let conversation = viewModel.conversations.first(where: { $0.id == id }) {
                EnhancedConversationView(conversation: conversation, viewModel: viewModel)
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Image(systemName: conversation.avatarSystemName)
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.subheadline.bold())
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastMessageDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.pink, in: Circle())
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Actions

    private func startConversation(with teacher: ProfileDTO) {
        isCreatingConversation = true
        errorMessage = nil

        let teacherName = "\(teacher.firstName ?? "") \(teacher.lastName ?? "")"
        let courseName = courseForTeacher(teacher) ?? "General"
        let title = "Re: \(child.name) - \(courseName)"

        // Check if a conversation already exists with this teacher
        if let existing = viewModel.conversations.first(where: { conversation in
            conversation.participantNames.contains(teacherName) &&
            conversation.title == title
        }) {
            // Navigate to existing conversation
            isCreatingConversation = false
            showConversation = true
            _ = existing
            return
        }

        guard let currentUser = viewModel.currentUser else {
            isCreatingConversation = false
            errorMessage = "You must be logged in to send messages."
            return
        }

        Task {
            let participants: [(userId: UUID, userName: String)] = [
                (userId: currentUser.id, userName: currentUser.fullName),
                (userId: teacher.id, userName: teacherName)
            ]
            await viewModel.createConversation(
                title: title,
                participantIds: participants
            )
            isCreatingConversation = false
        }
    }
}
