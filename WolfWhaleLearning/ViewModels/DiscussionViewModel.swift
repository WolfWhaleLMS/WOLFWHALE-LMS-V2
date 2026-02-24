import Foundation
import Supabase

// MARK: - DiscussionViewModel
/// Manages discussion forum state and logic: threads, replies, pinning.
/// Extracted from AppViewModel+Discussion.swift to reduce god-class complexity.

@Observable
@MainActor
class DiscussionViewModel {

    // MARK: - Data

    /// All loaded discussion threads across courses.
    var discussionThreads: [DiscussionThread] = []

    /// All loaded discussion replies across threads.
    var discussionReplies: [DiscussionReply] = []

    /// Error surfaced to the UI.
    var dataError: String?

    // MARK: - Load Threads

    func loadThreads(courseId: UUID, isDemoMode: Bool, currentUser: User?) {
        if isDemoMode {
            if !discussionThreads.contains(where: { $0.courseId == courseId }) {
                let now = Date()
                let t1Id = UUID()
                let sampleThreads: [DiscussionThread] = [
                    DiscussionThread(
                        id: t1Id, courseId: courseId,
                        authorId: UUID(), authorName: "Ms. Thompson",
                        title: "Welcome to the Discussion Board",
                        content: "Use this space to ask questions and share ideas about the course material. Be respectful and constructive in your posts.",
                        createdDate: now.addingTimeInterval(-86400 * 3),
                        replyCount: 2, isPinned: true
                    ),
                    DiscussionThread(
                        id: UUID(), courseId: courseId,
                        authorId: UUID(), authorName: "Alex Rivera",
                        title: "Study group for upcoming quiz?",
                        content: "Anyone want to form a study group for the quiz next week? I was thinking we could meet in the library after school on Wednesday.",
                        createdDate: now.addingTimeInterval(-86400),
                        replyCount: 4, isPinned: false
                    ),
                    DiscussionThread(
                        id: UUID(), courseId: courseId,
                        authorId: UUID(), authorName: "Jordan Chen",
                        title: "Question about Module 2 reading",
                        content: "I'm confused about the concept in the second reading. Can someone explain how this works in simpler terms?",
                        createdDate: now.addingTimeInterval(-3600 * 5),
                        replyCount: 1, isPinned: false
                    )
                ]
                discussionThreads.append(contentsOf: sampleThreads)
                discussionReplies.append(contentsOf: [
                    DiscussionReply(
                        id: UUID(), threadId: t1Id,
                        authorId: UUID(), authorName: "Sam Wilson",
                        content: "Thanks for setting this up! Looking forward to great discussions.",
                        createdDate: now.addingTimeInterval(-86400 * 2)
                    ),
                    DiscussionReply(
                        id: UUID(), threadId: t1Id,
                        authorId: UUID(), authorName: "Taylor Kim",
                        content: "Excited to use this! Quick question -- can we share links to helpful resources here?",
                        createdDate: now.addingTimeInterval(-86400)
                    )
                ])
            }
            return
        }

        Task {
            do {
                struct ThreadDTO: Decodable {
                    let id: UUID
                    let courseId: UUID
                    let authorId: UUID
                    let authorName: String
                    let title: String
                    let content: String
                    let createdAt: String
                    let replyCount: Int
                    let isPinned: Bool

                    enum CodingKeys: String, CodingKey {
                        case id
                        case courseId = "course_id"
                        case authorId = "author_id"
                        case authorName = "author_name"
                        case title, content
                        case createdAt = "created_at"
                        case replyCount = "reply_count"
                        case isPinned = "is_pinned"
                    }
                }

                let dtos: [ThreadDTO] = try await supabaseClient
                    .from("discussion_threads")
                    .select()
                    .eq("course_id", value: courseId.uuidString)
                    .order("is_pinned", ascending: false)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                let formatter = ISO8601DateFormatter()
                let threads = dtos.map { dto in
                    DiscussionThread(
                        id: dto.id, courseId: dto.courseId,
                        authorId: dto.authorId, authorName: dto.authorName,
                        title: dto.title, content: dto.content,
                        createdDate: formatter.date(from: dto.createdAt) ?? Date(),
                        replyCount: dto.replyCount, isPinned: dto.isPinned
                    )
                }

                discussionThreads.removeAll { $0.courseId == courseId }
                discussionThreads.append(contentsOf: threads)
            } catch {
                #if DEBUG
                print("[DiscussionViewModel] loadThreads failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Create Thread

    func createThread(courseId: UUID, title: String, content: String, isDemoMode: Bool, currentUser: User?) {
        guard let user = currentUser else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else {
            dataError = "Title and content are required."
            return
        }

        let newThread = DiscussionThread(
            id: UUID(), courseId: courseId,
            authorId: user.id, authorName: user.fullName,
            title: trimmedTitle, content: trimmedContent,
            createdDate: Date(), replyCount: 0, isPinned: false
        )
        discussionThreads.insert(newThread, at: 0)

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("discussion_threads")
                        .insert([
                            "id": newThread.id.uuidString,
                            "course_id": courseId.uuidString,
                            "author_id": user.id.uuidString,
                            "author_name": user.fullName,
                            "title": trimmedTitle,
                            "content": trimmedContent,
                            "reply_count": "0",
                            "is_pinned": "false"
                        ])
                        .execute()
                } catch {
                    discussionThreads.removeAll { $0.id == newThread.id }
                    dataError = "Failed to create thread. Please try again."
                    #if DEBUG
                    print("[DiscussionViewModel] createThread failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Reply to Thread

    func replyToThread(threadId: UUID, content: String, isDemoMode: Bool, currentUser: User?) {
        guard let user = currentUser else { return }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            dataError = "Reply content cannot be empty."
            return
        }

        let newReply = DiscussionReply(
            id: UUID(), threadId: threadId,
            authorId: user.id, authorName: user.fullName,
            content: trimmedContent, createdDate: Date()
        )
        discussionReplies.append(newReply)

        if let idx = discussionThreads.firstIndex(where: { $0.id == threadId }) {
            discussionThreads[idx].replyCount += 1
        }

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("discussion_replies")
                        .insert([
                            "id": newReply.id.uuidString,
                            "thread_id": threadId.uuidString,
                            "author_id": user.id.uuidString,
                            "author_name": user.fullName,
                            "content": trimmedContent
                        ])
                        .execute()

                    if let thread = discussionThreads.first(where: { $0.id == threadId }) {
                        try await supabaseClient
                            .from("discussion_threads")
                            .update(["reply_count": thread.replyCount])
                            .eq("id", value: threadId.uuidString)
                            .execute()
                    }
                } catch {
                    discussionReplies.removeAll { $0.id == newReply.id }
                    if let idx = discussionThreads.firstIndex(where: { $0.id == threadId }) {
                        discussionThreads[idx].replyCount = max(0, discussionThreads[idx].replyCount - 1)
                    }
                    dataError = "Failed to post reply. Please try again."
                    #if DEBUG
                    print("[DiscussionViewModel] replyToThread failed: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Load Replies

    func loadReplies(threadId: UUID, isDemoMode: Bool) {
        if isDemoMode { return }

        Task {
            do {
                struct ReplyDTO: Decodable {
                    let id: UUID
                    let threadId: UUID
                    let authorId: UUID
                    let authorName: String
                    let content: String
                    let createdAt: String

                    enum CodingKeys: String, CodingKey {
                        case id
                        case threadId = "thread_id"
                        case authorId = "author_id"
                        case authorName = "author_name"
                        case content
                        case createdAt = "created_at"
                    }
                }

                let dtos: [ReplyDTO] = try await supabaseClient
                    .from("discussion_replies")
                    .select()
                    .eq("thread_id", value: threadId.uuidString)
                    .order("created_at", ascending: true)
                    .execute()
                    .value

                let formatter = ISO8601DateFormatter()
                let replies = dtos.map { dto in
                    DiscussionReply(
                        id: dto.id, threadId: dto.threadId,
                        authorId: dto.authorId, authorName: dto.authorName,
                        content: dto.content,
                        createdDate: formatter.date(from: dto.createdAt) ?? Date()
                    )
                }

                discussionReplies.removeAll { $0.threadId == threadId }
                discussionReplies.append(contentsOf: replies)
            } catch {
                #if DEBUG
                print("[DiscussionViewModel] loadReplies failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Pin Thread

    func pinThread(threadId: UUID, isDemoMode: Bool, currentUser: User?) {
        guard let user = currentUser,
              user.role == .teacher || user.role == .admin || user.role == .superAdmin else {
            dataError = "Only teachers can pin threads."
            return
        }

        guard let idx = discussionThreads.firstIndex(where: { $0.id == threadId }) else { return }
        let newPinnedState = !discussionThreads[idx].isPinned
        discussionThreads[idx].isPinned = newPinnedState

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("discussion_threads")
                        .update(["is_pinned": newPinnedState])
                        .eq("id", value: threadId.uuidString)
                        .execute()
                } catch {
                    if let idx = discussionThreads.firstIndex(where: { $0.id == threadId }) {
                        discussionThreads[idx].isPinned = !newPinnedState
                    }
                    dataError = "Failed to update pin status."
                    #if DEBUG
                    print("[DiscussionViewModel] pinThread failed: \(error)")
                    #endif
                }
            }
        }
    }
}
