import ActivityKit
import SwiftUI

// MARK: - Activity Attributes

nonisolated struct ClassSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: Int // minutes
        var currentTopic: String
        var progress: Double // 0.0 to 1.0
    }

    var courseName: String
    var teacherName: String
    var startTime: Date
    var endTime: Date
    var courseColor: String
}

nonisolated struct AssignmentDueAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var hoursRemaining: Int
        var isSubmitted: Bool
    }

    var assignmentTitle: String
    var courseName: String
    var dueDate: Date
    var totalPoints: Int
}

// MARK: - Live Activity Service

@MainActor
@Observable
class LiveActivityService {
    var activeClassActivity: Activity<ClassSessionAttributes>?
    var activeAssignmentActivity: Activity<AssignmentDueAttributes>?

    var isClassSessionActive: Bool { activeClassActivity != nil }

    func startClassSession(courseName: String, teacherName: String, duration: Int, topic: String, color: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ClassSessionAttributes(
            courseName: courseName,
            teacherName: teacherName,
            startTime: Date(),
            endTime: Date().addingTimeInterval(TimeInterval(duration * 60)),
            courseColor: color
        )

        let state = ClassSessionAttributes.ContentState(
            timeRemaining: duration,
            currentTopic: topic,
            progress: 0.0
        )

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(TimeInterval(duration * 60)))

        do {
            activeClassActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("[LiveActivity] Failed to start: \(error)")
            #endif
        }
    }

    func updateClassSession(timeRemaining: Int, topic: String, progress: Double) {
        guard let activity = activeClassActivity else { return }
        let state = ClassSessionAttributes.ContentState(
            timeRemaining: timeRemaining,
            currentTopic: topic,
            progress: progress
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endClassSession() {
        guard let activity = activeClassActivity else { return }
        let finalState = ClassSessionAttributes.ContentState(
            timeRemaining: 0,
            currentTopic: "Class Ended",
            progress: 1.0
        )
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 60))
            activeClassActivity = nil
        }
    }

    func startAssignmentReminder(title: String, courseName: String, dueDate: Date, points: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = AssignmentDueAttributes(
            assignmentTitle: title,
            courseName: courseName,
            dueDate: dueDate,
            totalPoints: points
        )

        let hoursLeft = Int(dueDate.timeIntervalSinceNow / 3600)
        let state = AssignmentDueAttributes.ContentState(
            hoursRemaining: max(0, hoursLeft),
            isSubmitted: false
        )

        do {
            activeAssignmentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: dueDate),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("[LiveActivity] Assignment reminder failed: \(error)")
            #endif
        }
    }

    func markAssignmentSubmitted() {
        guard let activity = activeAssignmentActivity else { return }
        let state = AssignmentDueAttributes.ContentState(hoursRemaining: 0, isSubmitted: true)
        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 30))
            activeAssignmentActivity = nil
        }
    }
}
