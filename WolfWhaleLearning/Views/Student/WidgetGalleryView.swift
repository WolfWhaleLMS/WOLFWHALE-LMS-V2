import SwiftUI

struct WidgetGalleryView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header explaining widgets
                    VStack(spacing: 8) {
                        Image(systemName: "apps.iphone")
                            .font(.system(size: 40))
                            .foregroundStyle(.purple)
                        Text("Home Screen Widgets")
                            .font(.title2.bold())
                        Text("Preview how your widgets will look. Add them from your home screen by long-pressing and tapping +.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Study Pet Widget
                    sectionHeader("Study Pet", icon: "heart.fill", color: .orange)
                    StudyPetWidget(
                        petName: viewModel.currentUser?.firstName ?? "Buddy",
                        petLevel: 1,
                        petMood: determinePetMood(),
                        streak: viewModel.currentUser?.streak ?? 0,
                        lastStudyDate: Date()
                    )
                    .padding(.horizontal)

                    // Calendar Widget
                    sectionHeader("Schedule", icon: "calendar", color: .blue)
                    CalendarWidget(
                        events: CalendarWidget.CalendarEvent.sampleEvents,
                        currentDate: Date()
                    )
                    .padding(.horizontal)

                    // Dashboard Widget
                    sectionHeader("Dashboard", icon: "chart.bar.fill", color: .purple)
                    DashboardAnalyticsWidget(
                        gpa: viewModel.gpa,
                        attendanceRate: viewModel.attendance.isEmpty ? 0 : Double(viewModel.attendance.filter { $0.status == .present }.count) / Double(viewModel.attendance.count),
                        assignmentsCompleted: viewModel.assignments.filter { $0.isSubmitted }.count,
                        totalAssignments: viewModel.assignments.count,
                        coursesEnrolled: viewModel.courses.count,
                        currentStreak: viewModel.currentUser?.streak ?? 0
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }

    private func determinePetMood() -> StudyPetWidget.PetMood {
        guard let user = viewModel.currentUser else { return .neutral }
        if user.streak >= 7 { return .excited }
        if user.streak >= 3 { return .happy }
        if user.streak > 0 { return .neutral }
        return .sad
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.horizontal)
    }
}
