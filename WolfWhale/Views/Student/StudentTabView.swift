import SwiftUI

struct StudentTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var showRadio = false
    @State private var radioHaptic = false
    private let radioService = RadioService.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.tabHome, systemImage: "house.fill", value: 0) {
                StudentDashboardView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabHome)
            .accessibilityHint("Double tap to view your dashboard")
            Tab(L10n.courses, systemImage: "text.book.closed.fill", value: 1) {
                CoursesListView(viewModel: viewModel)
                    .task { viewModel.loadAssignmentsIfNeeded() }
            }
            .accessibilityLabel(L10n.courses)
            .accessibilityHint("Double tap to view your courses")
            Tab(L10n.tabResources, systemImage: "books.vertical.fill", value: 2) {
                ResourceLibraryView(viewModel: viewModel)
            }
            .accessibilityLabel(L10n.tabResources)
            .accessibilityHint("Double tap to explore learning resources")
            Tab(L10n.messages, systemImage: "message.fill", value: 3) {
                MessagesListView(viewModel: viewModel)
                    .task { viewModel.loadConversationsIfNeeded() }
            }
            .badge(viewModel.totalUnreadMessages)
            .accessibilityLabel(L10n.messages)
            .accessibilityHint("Double tap to view your messages")
            Tab(L10n.tabProfile, systemImage: "person.crop.circle.fill", value: 4) {
                StudentProfileView(viewModel: viewModel)
                    .task { viewModel.loadGradesIfNeeded() }
            }
            .accessibilityLabel(L10n.tabProfile)
            .accessibilityHint("Double tap to view your profile")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .tint(.accentColor)
        .overlay(alignment: .top) {
            OfflineBannerView(isConnected: viewModel.networkMonitor.isConnected)
        }
        // Floating radio button
        .overlay(alignment: .bottomTrailing) {
            floatingRadioButton
                .padding(.trailing, 16)
                .padding(.bottom, 90)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: radioHaptic)
        // Deep-link handling: navigate to the correct tab when a notification is tapped
        .onChange(of: viewModel.notificationService.deepLinkAssignmentId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab shows upcoming assignments
                // Clear after a brief delay to allow navigation to settle
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkAssignmentId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkConversationId) { _, newValue in
            if newValue != nil {
                selectedTab = 3 // Messages tab
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkConversationId = nil
                }
            }
        }
        .onChange(of: viewModel.notificationService.deepLinkGradeId) { _, newValue in
            if newValue != nil {
                selectedTab = 0 // Home tab (grades accessible from profile/dashboard)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.notificationService.deepLinkGradeId = nil
                }
            }
        }
    }

    // MARK: - Floating Radio Button

    private var floatingRadioButton: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Expanded panel
            if showRadio {
                VStack(spacing: 0) {
                    // Station list
                    ForEach(Array(RadioService.RadioStation.allStations.filter { $0.streamURL != nil }.enumerated()), id: \.element.id) { index, station in
                        Button {
                            radioHaptic.toggle()
                            if radioService.currentStation?.id == station.id && radioService.isPlaying {
                                radioService.pause()
                            } else {
                                radioService.play(station: station)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: station.iconName)
                                    .font(.body)
                                    .foregroundStyle(Theme.courseColor(station.color))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(station.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if radioService.currentStation?.id == station.id {
                                    Image(systemName: radioService.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.courseColor(station.color))
                                        .symbolEffect(.variableColor.iterative, isActive: radioService.isPlaying)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if index < RadioService.RadioStation.allStations.filter({ $0.streamURL != nil }).count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }

                    // Stop button (if playing)
                    if radioService.isPlaying {
                        Divider()
                        Button {
                            radioHaptic.toggle()
                            radioService.stop()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.caption)
                                Text("Stop")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .frame(width: 260)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity)
                ))
            }

            // Floating button
            Button {
                radioHaptic.toggle()
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    showRadio.toggle()
                }
            } label: {
                ZStack {
                    Image(systemName: radioService.isPlaying ? "radio.fill" : "radio")
                        .font(.title3)
                        .foregroundStyle(radioService.isPlaying ? Theme.brandPurple : .primary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 52, height: 52)
                .glassEffect(.regular, in: Circle())
                .shadow(color: radioService.isPlaying ? Theme.brandPurple.opacity(0.4) : .black.opacity(0.1), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}
