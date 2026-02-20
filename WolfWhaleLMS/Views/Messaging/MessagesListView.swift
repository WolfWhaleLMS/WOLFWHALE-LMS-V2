import SwiftUI

struct MessagesListView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        conversationRow(conversation)
                    }
                }
            }
            .navigationTitle("Messages")
            .overlay {
                if viewModel.conversations.isEmpty {
                    ContentUnavailableView("No Messages", systemImage: "message", description: Text("Conversations will appear here"))
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let conversation = viewModel.conversations.first(where: { $0.id == id }) {
                    ConversationView(conversation: conversation, viewModel: viewModel)
                }
            }
            .refreshable {
                viewModel.refreshData()
            }
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
        .padding(.vertical, 2)
    }
}
