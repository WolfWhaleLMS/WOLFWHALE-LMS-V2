import SwiftUI
import EventKit

struct CalendarSyncView: View {
    let viewModel: AppViewModel

    @State private var syncEnabled: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.calendarSyncEnabled)
    @State private var isSyncing = false
    @State private var showRemoveConfirmation = false
    @State private var showCalendarPicker = false
    @State private var hapticTrigger = false

    private var calendarService: CalendarService { viewModel.calendarService }

    var body: some View {
        List {
            permissionSection
            syncControlSection
            calendarPickerSection
            statusSection
            dangerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Calendar Sync")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Remove All Events",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All Events", role: .destructive) {
                calendarService.removeAllWolfWhaleEvents()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all WolfWhale LMS events from your calendar. This cannot be undone.")
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: calendarService.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(calendarService.isAuthorized ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendarService.isAuthorized ? "Calendar Access Granted" : "Calendar Access Required")
                        .font(.subheadline.bold())
                    Text(calendarService.isAuthorized
                         ? "WolfWhale LMS can add events to your calendar."
                         : "Grant access to sync assignments and schedule to your calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !calendarService.isAuthorized {
                    Button("Grant") {
                        hapticTrigger.toggle()
                        Task {
                            await calendarService.requestAccess()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        } header: {
            sectionHeader(title: "Permission", icon: "lock.shield.fill")
        }
    }

    // MARK: - Sync Controls

    private var syncControlSection: some View {
        Section {
            HStack {
                Label {
                    Text("Sync to Calendar")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.purple)
                }
                Spacer()
                Toggle("Sync to Calendar", isOn: $syncEnabled)
                    .labelsHidden()
                    .sensoryFeedback(.selection, trigger: syncEnabled)
                    .onChange(of: syncEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.calendarSyncEnabled)
                        if !newValue {
                            calendarService.removeAllWolfWhaleEvents()
                        }
                    }
            }
            .disabled(!calendarService.isAuthorized)

            Button {
                hapticTrigger.toggle()
                performSync()
            } label: {
                HStack {
                    Label {
                        Text("Sync Now")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(!calendarService.isAuthorized || isSyncing)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        } header: {
            sectionHeader(title: "Sync", icon: "calendar.badge.plus")
        }
    }

    // MARK: - Calendar Picker

    private var calendarPickerSection: some View {
        Section {
            if calendarService.isAuthorized {
                let calendars = calendarService.availableCalendars
                if calendars.count > 1 {
                    DisclosureGroup(isExpanded: $showCalendarPicker) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Button {
                                calendarService.selectCalendar(identifier: calendar.calendarIdentifier)
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 12, height: 12)
                                    Text(calendar.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if calendarService.selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.purple)
                                            .font(.subheadline.bold())
                                    }
                                }
                            }
                        }
                    } label: {
                        Label {
                            HStack {
                                Text("Target Calendar")
                                Spacer()
                                Text(calendarService.selectedCalendar?.title ?? "WolfWhale LMS")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(.indigo)
                        }
                    }
                } else {
                    HStack {
                        Label {
                            Text("Target Calendar")
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(.indigo)
                        }
                        Spacer()
                        Text("WolfWhale LMS")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Label {
                        Text("Target Calendar")
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.indigo)
                    }
                    Spacer()
                    Text("Grant access first")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            sectionHeader(title: "Calendar", icon: "calendar.circle")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack {
                Label {
                    Text("Synced Events")
                } icon: {
                    Image(systemName: "number.circle.fill")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text("\(calendarService.syncedEventCount)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label {
                    Text("Last Synced")
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                if let lastSync = calendarService.lastSyncDate {
                    Text(lastSync, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            sectionHeader(title: "Status", icon: "chart.bar.fill")
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                hapticTrigger.toggle()
                showRemoveConfirmation = true
            } label: {
                Label {
                    Text("Remove All Events")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .disabled(!calendarService.isAuthorized || calendarService.syncedEventCount == 0)
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
        } header: {
            sectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill")
        } footer: {
            Text("Removes all WolfWhale LMS events from your iOS calendar.")
        }
    }

    // MARK: - Helpers

    private func performSync() {
        guard calendarService.isAuthorized else { return }
        isSyncing = true

        // Ensure a calendar exists
        _ = calendarService.getOrCreateWolfWhaleCalendar()

        // Sync assignments
        calendarService.syncAllAssignments(assignments: viewModel.assignments)

        isSyncing = false
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
    }
}
