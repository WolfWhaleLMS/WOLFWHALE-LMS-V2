import SwiftUI

struct ThreadDetailView: View {
    let thread: DiscussionThread
    let course: Course
    let viewModel: AppViewModel
    @State private var replyText = ""
    @State private var moderationWarning: String?
    @State private var hapticTrigger = false
    @FocusState private var isReplyFocused: Bool

    private var replies: [DiscussionReply] {
        viewModel.discussionReplies
            .filter { $0.threadId == thread.id }
            .sorted { $0.createdDate < $1.createdDate }
    }

    private var isTeacher: Bool {
        guard let user = viewModel.currentUser else { return false }
        return user.role == .teacher || user.role == .admin || user.role == .superAdmin
    }

    /// Live thread from viewModel so pinned state stays current.
    private var liveThread: DiscussionThread {
        viewModel.discussionThreads.first(where: { $0.id == thread.id }) ?? thread
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    originalPost
                    repliesSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))

            replyBar
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isTeacher {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticTrigger.toggle()
                        viewModel.pinThread(threadId: thread.id)
                    } label: {
                        Label(
                            liveThread.isPinned ? "Unpin" : "Pin",
                            systemImage: liveThread.isPinned ? "pin.slash.fill" : "pin.fill"
                        )
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel(liveThread.isPinned ? "Unpin thread" : "Pin thread")
                    .accessibilityHint("Double tap to \(liveThread.isPinned ? "unpin" : "pin") this thread")
                }
            }
        }
        .onAppear {
            viewModel.loadReplies(threadId: thread.id)
        }
        .alert("Reply Not Sent", isPresented: .constant(moderationWarning != nil)) {
            Button("OK") { moderationWarning = nil }
        } message: {
            Text(moderationWarning ?? "")
        }
    }

    // MARK: - Original Post

    private var originalPost: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                authorAvatar(thread.authorName)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(thread.authorName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(.label))
                        if liveThread.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(thread.createdDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(thread.title)
                .font(.title3.bold())
                .foregroundStyle(Color(.label))

            Text(thread.content)
                .font(.body)
                .foregroundStyle(Color(.label))

            Divider()

            HStack(spacing: 4) {
                Image(systemName: "bubble.left.fill")
                    .font(.caption)
                Text("\(liveThread.replyCount) \(liveThread.replyCount == 1 ? "reply" : "replies")")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Replies Section

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !replies.isEmpty {
                Text("Replies")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .padding(.top, 4)

                ForEach(replies) { reply in
                    replyCard(reply)
                }
            }
        }
    }

    private func replyCard(_ reply: DiscussionReply) -> some View {
        HStack(alignment: .top, spacing: 10) {
            authorAvatar(reply.authorName)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(reply.authorName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text(reply.createdDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(reply.content)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reply.authorName) said: \(reply.content)")
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        HStack(spacing: 10) {
            TextField("Write a reply...", text: $replyText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                .focused($isReplyFocused)

            Button {
                // COPPA content moderation check
                let moderation = ContentModerationService.shared.moderateContent(replyText)
                if !moderation.isClean {
                    moderationWarning = moderation.flaggedReason
                    return
                }

                hapticTrigger.toggle()
                viewModel.replyToThread(threadId: thread.id, content: replyText)
                replyText = ""
                isReplyFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accent)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send reply")
            .accessibilityHint("Double tap to send your reply")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func authorAvatar(_ name: String) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        let color = avatarColor(for: name)
        return Text(initial)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color, in: Circle())
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .orange, .teal, .pink, .mint, .cyan]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}
