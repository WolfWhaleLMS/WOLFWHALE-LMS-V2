import WidgetKit
import SwiftUI

/// Entry point for the WolfWhale LMS widget extension.
/// Registers all available widgets that users can add to their home screen.
@main
struct WolfWhaleWidgets: WidgetBundle {
    var body: some Widget {
        GradesWidget()
        ScheduleWidget()
        AssignmentsWidget()
    }
}
