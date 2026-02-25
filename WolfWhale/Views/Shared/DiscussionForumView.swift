import SwiftUI

struct DiscussionForumView: View {
    let course: Course
    let viewModel: AppViewModel
    @State private var showNewThread = false
    @State private var newThreadTitle = ""
    @State private var newThreadContent = ""
    @State private var moderationWarning: String?
    @State private var hapticTrigger = false

    private var threads: [DiscussionThread] {
        viewModel.discussionThreads
            .filter { $0.courseId == course.id }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.createdDate > rhs.createdDate
            }
    }

    private var isTeacher: Bool {
        guard let user = viewModel.currentUser else { return false }
        return user.role == .teacher || user.role == .admin || user.role == .superAdmin
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if threads.isEmpty {
                        emptyState
                    } else {
                        ForEach(threads) { thread in
                            NavigationLink(value: thread) {
                                threadCard(thread)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))

            Button {
                hapticTrigger.toggle()
                newThreadTitle = ""
                newThreadContent = ""
                showNewThread = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .padding(20)
            .accessibilityLabel("New thread")
            .accessibilityHint("Double tap to create a new discussion thread")
        }
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DiscussionThread.self) { thread in
            ThreadDetailView(thread: thread, course: course, viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadThreads(courseId: course.id)
        }
        .sheet(isPresented: $showNewThread) {
            newThreadSheet
        }
    }

    // MARK: - Thread Card

    private func threadCard(_ thread: DiscussionThread) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                authorAvatar(thread.authorName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.authorName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text(thread.createdDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if thread.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
            }

            Text(thread.title)
                .font(.headline)
                .foregroundStyle(Color(.label))
                .lineLimit(2)

            Text(thread.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label("\(thread.replyCount)", systemImage: "bubble.left.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title) by \(thread.authorName), \(thread.replyCount) replies\(thread.isPinned ? ", pinned" : "")")
        .accessibilityHint("Double tap to open thread")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No discussions yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a conversation by tapping the + button below.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - New Thread Sheet

    private var newThreadSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    TextField("Thread title", text: $newThreadTitle)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    TextEditor(text: $newThreadContent)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewThread = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        // COPPA content moderation check on title and content
                        let titleCheck = ContentModerationService.shared.moderateContent(newThreadTitle)
                        if !titleCheck.isClean {
                            moderationWarning = titleCheck.flaggedReason
                            return
                        }
                        let contentCheck = ContentModerationService.shared.moderateContent(newThreadContent)
                        if !contentCheck.isClean {
                            moderationWarning = contentCheck.flaggedReason
                            return
                        }

                        hapticTrigger.toggle()
                        viewModel.createThread(courseId: course.id, title: newThreadTitle, content: newThreadContent)
                        showNewThread = false
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                    .disabled(
                        newThreadTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        newThreadContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.large])
        .alert("Post Not Allowed", isPresented: .constant(moderationWarning != nil)) {
            Button("OK") { moderationWarning = nil }
        } message: {
            Text(moderationWarning ?? "")
        }
    }

    // MARK: - Helpers

    private func authorAvatar(_ name: String) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        let color = avatarColor(for: name)
        return Text(initial)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: Circle())
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .orange, .teal, .red, .mint, .cyan]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
