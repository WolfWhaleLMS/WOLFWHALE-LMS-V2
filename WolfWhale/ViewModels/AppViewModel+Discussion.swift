import Foundation
import Supabase

// MARK: - Discussion Forum (Delegating to DiscussionViewModel)

extension AppViewModel {

    // MARK: - Forwarding Properties
    // These forward to the sub-ViewModel's arrays so existing views
    // that access `appViewModel.discussionThreads` continue to work.
    // The sub-ViewModel holds the canonical state; these are two-way bridges.

    func syncDiscussionState() {
        // Push AppViewModel state into the sub-ViewModel
        discussionsVM.discussionThreads = discussionThreads
        discussionsVM.discussionReplies = discussionReplies
    }

    private func pullDiscussionState() {
        // Pull sub-ViewModel state back into AppViewModel
        discussionThreads = discussionsVM.discussionThreads
        discussionReplies = discussionsVM.discussionReplies
        if let error = discussionsVM.dataError {
            dataError = error
        }
    }

    // MARK: - Delegating Methods

    func loadThreads(courseId: UUID) {
        syncDiscussionState()
        if isDemoMode {
            discussionsVM.loadThreads(courseId: courseId, isDemoMode: isDemoMode, currentUser: currentUser)
            pullDiscussionState()
        } else {
            Task {
                await discussionsVM.fetchThreads(courseId: courseId)
                pullDiscussionState()
            }
        }
    }

    func createThread(courseId: UUID, title: String, content: String) {
        syncDiscussionState()
        discussionsVM.createThread(courseId: courseId, title: title, content: content, isDemoMode: isDemoMode, currentUser: currentUser)
        pullDiscussionState()
    }

    func replyToThread(threadId: UUID, content: String) {
        syncDiscussionState()
        discussionsVM.replyToThread(threadId: threadId, content: content, isDemoMode: isDemoMode, currentUser: currentUser)
        pullDiscussionState()
    }

    func loadReplies(threadId: UUID) {
        syncDiscussionState()
        if isDemoMode {
            discussionsVM.loadReplies(threadId: threadId, isDemoMode: isDemoMode)
            pullDiscussionState()
        } else {
            Task {
                await discussionsVM.fetchReplies(threadId: threadId)
                pullDiscussionState()
            }
        }
    }

    func pinThread(threadId: UUID) {
        syncDiscussionState()
        discussionsVM.pinThread(threadId: threadId, isDemoMode: isDemoMode, currentUser: currentUser)
        pullDiscussionState()
    }
}
