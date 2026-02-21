import SwiftUI

struct AnnouncementsView: View {
    let viewModel: AppViewModel
    @State private var showCreate = false
    @State private var hapticTrigger = false

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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(announcement.isPinned ? "Pinned: " : "")\(announcement.title), \(announcement.content), by \(announcement.authorName)")
                }
            }
            .navigationTitle("Announcements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New", systemImage: "plus") {
                        hapticTrigger.toggle()
                        showCreate = true
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("New announcement")
                    .accessibilityHint("Double tap to create a new announcement")
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
