import SwiftUI

struct AnnouncementsView: View {
    let viewModel: AppViewModel
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.announcements) { announcement in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if announcement.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(announcement.title)
                                .font(.headline)
                        }
                        Text(announcement.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Label(announcement.authorName, systemImage: "person.fill")
                            Spacer()
                            Text(announcement.date, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Announcements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New", systemImage: "plus") {
                        showCreate = true
                    }
                }
            }
            .overlay {
                if viewModel.announcements.isEmpty {
                    ContentUnavailableView("No Announcements", systemImage: "megaphone", description: Text("Create your first announcement"))
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateAnnouncementSheet(viewModel: viewModel)
            }
            .refreshable {
                viewModel.refreshData()
            }
        }
    }
}
