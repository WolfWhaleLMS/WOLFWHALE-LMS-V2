import SwiftUI

struct ContentView: View {
    @Environment(WatchConnectivityService.self) private var connectivity

    var body: some View {
        TabView {
            AssignmentListView(assignments: connectivity.assignments)
                .tag(0)

            ScheduleView(entries: connectivity.schedule)
                .tag(1)

            GradesSummaryView(grades: connectivity.grades)
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}
