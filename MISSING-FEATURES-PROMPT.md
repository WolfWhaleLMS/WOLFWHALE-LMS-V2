# WOLFWHALE LMS V2 — Missing Features Build Prompt

Use this prompt to build every missing essential feature needed for a fully working, shippable LMS app.

---

This is a SwiftUI iOS school LMS at the project root. It targets iOS 26+, uses Supabase as backend,
and follows these patterns:
- **Services**: `@MainActor @Observable final class` with `var error: String?`, `var isLoading = false`
- **Models**: `nonisolated struct: Identifiable, Hashable, Sendable` with `let id: UUID`
- **Views**: `struct XView: View { let viewModel: AppViewModel }`, uses `.sensoryFeedback`, `.ultraThinMaterial`, indigo/purple theme
- **Lazy init**: All services use lazy `private var _service / var service` pattern in AppViewModel
- **Platform guards**: `#if canImport(UIKit)` and `#if os(iOS)` for platform-specific code

Read every file referenced before making changes. Do NOT remove existing features or change the visual design.
Launch parallel agents for independent work. Commit and push when done.

---

## **PHASE 1 — CRITICAL (App Won't Function Without These)**

---

### Agent 1: Navigation Wiring & Deep Linking

**Problem**: 110+ views exist but many new SDK views (DocumentScanView, DrawingCanvasView, SpeechToTextView, WellnessView, SharePlayView, RecommendationsView) may not be reachable from any tab or navigation link.

**Read first**:
- `WolfWhaleLearning/Views/Student/StudentDashboardView.swift`
- `WolfWhaleLearning/Views/ContentView.swift` (or main tab view)
- All tab bar / sidebar navigation files

**Tasks**:

1.1 — **Audit every view file** and confirm it is reachable via at least one navigation path. List any orphaned views.

1.2 — **Add navigation links** in the Student tab/dashboard for these views if missing:
- "Document Scanner" → `DocumentScanView` (under Assignments or Tools section)
- "Drawing Canvas" → `DrawingCanvasView` (under Tools or Notes section)
- "Speech to Text" → `SpeechToTextView` (under Accessibility or Tools)
- "Wellness" → `WellnessView` (as its own tab or dashboard card)
- "Study Group (SharePlay)" → `SharePlayView` (under Social or Study Tools)
- "AI Recommendations" → `RecommendationsView` (as dashboard card or dedicated section)
- "Flashcards" → `FlashcardCreatorView`
- "AR Library" → `ARLibraryView`

1.3 — **Add a "Tools" or "Resources" section** on the student dashboard that acts as a launchpad for all learning tools (scanner, drawing, speech, flashcards, spelling bee, math quiz, typing tutor, etc). Use a LazyVGrid with icon cards.

1.4 — **Wire deep links** from push notifications and widgets. Read `WolfWhaleWidgets/SharedWidgetData.swift` for `WidgetDeepLink` URLs. Ensure the main app's `.onOpenURL` handler routes:
- `wolfwhale://assignments` → Assignments tab
- `wolfwhale://grades` → Grades tab
- `wolfwhale://schedule` → Schedule/Calendar tab
- `wolfwhale://course/{id}` → CourseDetailView

1.5 — **Wire Spotlight deep links**. Read `SpotlightService.swift` for identifier format (`course:{uuid}`, `assignment:{uuid}`, `quiz:{uuid}`). Handle `NSUserActivity` with `CSSearchableItemActionType` to navigate to the correct view.

---

### Agent 2: Real-Time Messaging

**Problem**: Conversation and message models exist. `RealtimeService.swift` exists. But live message streaming (new messages appearing instantly without refresh) is likely not wired end-to-end.

**Read first**:
- `WolfWhaleLearning/Services/RealtimeService.swift`
- `WolfWhaleLearning/Services/SupabaseService.swift` (message-related methods)
- `WolfWhaleLearning/Views/Messaging/ConversationView.swift`
- `WolfWhaleLearning/Views/Messaging/EnhancedConversationView.swift`
- `WolfWhaleLearning/Views/Messaging/MessagesListView.swift`

**Tasks**:

2.1 — **Subscribe to Supabase Realtime** for the `messages` table. When a new row is inserted where `conversation_id` matches the currently open conversation, append it to the message list in real time. Use Supabase Realtime's `.channel()` with `.on(.insert)` filter.

```swift
// Pattern:
let channel = supabaseClient.channel("messages:\(conversationId)")
channel.on("postgres_changes", filter: .init(
    event: .insert,
    schema: "public",
    table: "messages",
    filter: "conversation_id=eq.\(conversationId)"
)) { payload in
    // Parse and append new message
}
await channel.subscribe()
```

2.2 — **Update the conversation list in real time**. When any message arrives for any of the user's conversations, update the "last message" preview and bump it to the top of the list. Subscribe to all user's conversation IDs.

2.3 — **Add typing indicators**. Use Supabase Realtime's broadcast feature to send/receive typing status between conversation participants.

2.4 — **Add read receipts**. When user opens a conversation, mark all messages as read via a Supabase update. Show read/unread status with a blue dot on the conversation list.

2.5 — **Add message sending with optimistic UI**. When user taps send:
- Immediately show the message in the UI (with a "sending" indicator)
- POST to Supabase
- On success, update to "sent" status
- On failure, show "failed to send" with retry button

2.6 — **Unsubscribe from channels** when leaving a conversation view and on logout. Store channel references and call `channel.unsubscribe()`.

---

### Agent 3: File Manager & Submission Viewer

**Problem**: `FileUploadService.swift` handles uploads to Supabase Storage, but there's no UI for browsing uploaded files, and teachers can't view/download student submissions.

**Read first**:
- `WolfWhaleLearning/Services/FileUploadService.swift`
- `WolfWhaleLearning/Views/Student/SubmitAssignmentView.swift`
- `WolfWhaleLearning/Views/Teacher/StudentSubmissionsView.swift`
- `WolfWhaleLearning/Models/` — Submission/Assignment DTOs

**Tasks**:

3.1 — **Create `FileManagerView.swift`** in `Views/Student/`. This view lets students:
- See all their uploaded files grouped by course/assignment
- Preview files inline (images, PDFs via `PDFKit`, text)
- Delete files they've uploaded
- See upload date and file size
- Share files via `ShareLink`

3.2 — **Enhance `StudentSubmissionsView.swift`** for teachers:
- Show file attachments for each submission with download/preview buttons
- Add inline PDF viewer using `PDFKit` (`PDFKitRepresentable` UIViewRepresentable)
- Add image viewer for image submissions
- Add "Download All" button that creates a zip of all submissions
- Show submission timestamp, late status, and file metadata

3.3 — **Create `PDFViewerView.swift`** as a reusable component:
```swift
struct PDFViewerView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { ... }
}
```

3.4 — **Add file type icons** — show appropriate SF Symbols based on file extension (.pdf → doc.fill, .jpg → photo.fill, .txt → doc.text.fill, etc.)

---

### Agent 4: Video Content & Lesson Playback

**Problem**: Lessons and modules exist but there's no video player for lecture content. Most LMS platforms need embedded video.

**Read first**:
- `WolfWhaleLearning/Views/Student/LessonView.swift`
- `WolfWhaleLearning/Models/` — Lesson/Module models
- `WolfWhaleLearning/Services/SupabaseService.swift` — lesson fetch methods

**Tasks**:

4.1 — **Create `VideoPlayerView.swift`** in `Views/Components/`:
```swift
import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let url: URL
    let title: String
    @State private var player: AVPlayer?
    // Support: streaming URLs, local file URLs, Supabase Storage URLs
    // Features: play/pause, scrubber, AirPlay, PiP, playback speed (0.5x, 1x, 1.25x, 1.5x, 2x)
}
```

4.2 — **Integrate into LessonView**. If a lesson has a `videoURL` field, show the video player at the top of the lesson content. If no video, show lesson text/content as-is.

4.3 — **Add video progress tracking**. Save the last playback position so students can resume where they left off. Store in UserDefaults keyed by lesson ID:
```swift
UserDefaults.standard.set(currentTime, forKey: "video_progress_\(lessonId)")
```

4.4 — **Add Picture-in-Picture** support so students can take notes while watching.

4.5 — **Add a `videoURL: String?` field** to the Lesson model/DTO if it doesn't exist. Teachers should be able to paste a video URL when creating a lesson (in `CreateLessonView`).

---

### Agent 5: Quiz Builder Enhancement

**Problem**: `CreateQuizView.swift` exists but may lack a full question builder with add/remove questions, set correct answers, point values, time limits, and question types.

**Read first**:
- `WolfWhaleLearning/Views/Teacher/CreateQuizView.swift`
- `WolfWhaleLearning/Models/` — Quiz, QuizQuestion, QuizOption models
- `WolfWhaleLearning/Services/SupabaseService.swift` — quiz creation methods

**Tasks**:

5.1 — **Ensure CreateQuizView has these features** (add any that are missing):
- Quiz title, description, course assignment
- Time limit picker (no limit, 15min, 30min, 45min, 60min, 90min, 120min)
- Points per question (default + per-question override)
- Passing score threshold (percentage)
- Number of allowed attempts (1, 2, 3, unlimited)
- Shuffle questions toggle
- Shuffle answer options toggle
- Show results immediately vs after due date toggle

5.2 — **Question builder** — for each question:
- Question text (multiline)
- Question type picker: Multiple Choice, True/False, Short Answer, Fill in the Blank
- For Multiple Choice: Add/remove options (2-6), mark correct answer(s), support multiple correct
- For True/False: Auto-generate True and False options
- For Short Answer: Add acceptable answer(s) with case-insensitive matching
- Point value per question
- Reorder questions via drag handles
- Delete question with confirmation
- Duplicate question button

5.3 — **Question preview** — "Preview Quiz" button that shows the quiz exactly as students will see it.

5.4 — **Quiz bank** — ability to save questions to a bank and reuse across quizzes. Store in a `quiz_question_bank` concept (can be local or Supabase table).

---

### Agent 6: Grade Calculation Engine

**Problem**: `GradebookView.swift` exists but there may not be actual weighted grade calculation logic (assignments vs quizzes vs participation with configurable weights).

**Read first**:
- `WolfWhaleLearning/Views/Teacher/GradebookView.swift`
- `WolfWhaleLearning/Views/Student/GradesView.swift`
- `WolfWhaleLearning/Views/Student/ReportCardView.swift`
- `WolfWhaleLearning/Models/` — Grade, GradeEntry models
- `WolfWhaleLearning/ViewModels/AppViewModel.swift` — grade-related computed properties

**Tasks**:

6.1 — **Create `GradeCalculationService.swift`** in `Services/`:
```swift
@MainActor @Observable
final class GradeCalculationService {
    // Grade category weights (configurable per course)
    struct GradeWeights: Codable {
        var assignments: Double = 0.40   // 40%
        var quizzes: Double = 0.30       // 30%
        var participation: Double = 0.10  // 10%
        var midterm: Double = 0.10       // 10%
        var final: Double = 0.10         // 10%
    }

    func calculateCourseGrade(grades: [GradeEntry], weights: GradeWeights) -> Double
    func calculateGPA(courseGrades: [Double]) -> Double  // 4.0 scale
    func letterGrade(from percentage: Double) -> String  // A+, A, A-, B+...
    func gradeColor(from percentage: Double) -> Color    // Green > Yellow > Orange > Red
}
```

6.2 — **Allow teachers to configure grade weights** per course. Add a "Grade Settings" button in the teacher's course view that opens a weight configuration sheet.

6.3 — **Show weighted grade breakdown** in GradesView for students — pie chart or bar showing how much each category contributes.

6.4 — **GPA calculation** — calculate cumulative GPA across all courses on a 4.0 scale. Show on student dashboard and in ReportCardView.

6.5 — **Grade trend line** — show a simple line indicating if the student's grade is trending up or down over the last 5 entries per course.

---

### Agent 7: Enrollment Flow

**Problem**: Students need a way to browse available courses and enroll. There may be no course catalog or enrollment request/approval flow.

**Read first**:
- `WolfWhaleLearning/Services/SupabaseService.swift` — enrollment methods
- `WolfWhaleLearning/Views/Student/CoursesListView.swift`
- `WolfWhaleLearning/Models/` — Enrollment, Course models

**Tasks**:

7.1 — **Create `CourseCatalogView.swift`** in `Views/Student/`:
- Show all courses available at the student's school (tenant)
- Filter by: subject, grade level, teacher, schedule
- Search by course name or description
- Each course card shows: name, teacher, schedule, description, enrollment count, capacity
- "Enroll" button on each course

7.2 — **Enrollment logic**:
- If open enrollment: student taps "Enroll" → immediately enrolled → confirmation
- If approval required: student taps "Request Enrollment" → status becomes "pending" → teacher/admin approves
- Show enrollment status on each course: "Enrolled", "Pending", "Available", "Full"
- Prevent duplicate enrollment

7.3 — **Teacher approval view** — in the teacher's course management, show pending enrollment requests with Approve/Deny buttons.

7.4 — **Drop course** — students can drop a course (with confirmation dialog). Add a "Drop Course" button in CourseDetailView. Optionally require admin approval for drops after a certain date.

7.5 — **Enrollment capacity** — courses should have a `maxEnrollment` field. When full, show "Waitlist" instead of "Enroll". Implement a basic waitlist (first-come-first-served when a spot opens).

---

### Agent 8: Password Reset & Auth Hardening

**Problem**: `ForgotPasswordView.swift` exists but may not be wired to Supabase Auth. Also missing: session refresh, token expiry handling, account deletion.

**Read first**:
- `WolfWhaleLearning/Views/Auth/ForgotPasswordView.swift`
- `WolfWhaleLearning/Views/Auth/LoginView.swift`
- `WolfWhaleLearning/Views/Auth/SignUpView.swift`
- `WolfWhaleLearning/ViewModels/AppViewModel.swift` — auth methods
- `WolfWhaleLearning/Services/SupabaseService.swift` — auth calls

**Tasks**:

8.1 — **Wire ForgotPasswordView** to Supabase Auth:
```swift
try await supabaseClient.auth.resetPasswordForEmail(email)
```
Show success message: "Check your email for a password reset link."

8.2 — **Handle the reset callback**. When user clicks the email link, the app should open via deep link and present a "Set New Password" view. Use `.onOpenURL` to catch the Supabase redirect.

8.3 — **Add session refresh**. Check if the auth token is expired on app launch and refresh it:
```swift
try await supabaseClient.auth.refreshSession()
```
If refresh fails, redirect to login.

8.4 — **Add "Change Password" functionality**. Read `Views/Settings/ChangePasswordView.swift` — wire it to:
```swift
try await supabaseClient.auth.update(user: .init(password: newPassword))
```

8.5 — **Add account deletion** (required by App Store). Add "Delete Account" button in settings that:
- Shows confirmation alert with consequences
- Calls Supabase to delete user data
- Signs out and returns to login
- This is REQUIRED by Apple for App Store approval

8.6 — **Add email verification check**. After signup, if Supabase requires email confirmation, show a "Verify your email" screen instead of logging in directly.

---

## **PHASE 2 — HIGH PRIORITY (Expected by Users)**

---

### Agent 9: Push Notification Backend Triggers

**Problem**: The app handles receiving push notifications, but nothing triggers them when events happen (new assignment posted, grade entered, message received).

**Read first**:
- `WolfWhaleLearning/Services/PushNotificationService.swift`
- `WolfWhaleLearning/Services/NotificationService.swift`

**Tasks**:

9.1 — **Create Supabase Edge Functions** (or document what's needed) for these triggers:
- `on_assignment_created` → push to all enrolled students: "New assignment: {title} in {course}"
- `on_grade_entered` → push to student: "New grade posted for {assignment} in {course}"
- `on_message_sent` → push to conversation members: "New message from {sender}"
- `on_announcement_created` → push to all school users: "Announcement: {title}"
- `on_enrollment_approved` → push to student: "You've been enrolled in {course}"

9.2 — **Create the Edge Function template** at `supabase/functions/send-push/index.ts`:
```typescript
// Listens to Supabase webhook triggers
// Reads device_tokens for target users
// Sends APNs push via fetch to Apple's push endpoint
// Includes: title, body, badge count, deep link URL, sound
```

9.3 — **Schedule local notification reminders** from the app side:
- When assignments are loaded, schedule "Due in 24 hours" and "Due in 1 hour" reminders
- Cap at 20 most urgent assignments (iOS 64 notification limit)
- Clear old reminders before scheduling new ones
- Store scheduled notification IDs to avoid duplicates

9.4 — **Add notification preferences**. Let users toggle on/off:
- Assignment reminders
- Grade notifications
- Message notifications
- Announcement notifications
- Store preferences in UserDefaults and respect them when scheduling.

---

### Agent 10: Localization / Internationalization

**Problem**: All 110+ view files have hardcoded English strings. A real LMS needs at minimum English and French (given the app already has French speech recognition).

**Read first**:
- Scan 5-6 representative view files to understand the scope of hardcoded strings

**Tasks**:

10.1 — **Create `Localizable.xcstrings`** (String Catalog) in the project with English as the development language and French as the first additional language.

10.2 — **Extract all user-facing strings** from these critical views and replace with `String(localized:)`:
- LoginView, SignUpView, ForgotPasswordView
- StudentDashboardView, TeacherDashboardView, ParentDashboardView, AdminDashboardView
- CoursesListView, CourseDetailView
- AssignmentsView, SubmitAssignmentView
- GradesView, ReportCardView
- MessagesListView, ConversationView
- AppSettingsView
- All tab labels, button titles, section headers, empty states, error messages

Pattern:
```swift
// Before:
Text("No upcoming assignments")

// After:
Text(String(localized: "assignments.empty", defaultValue: "No upcoming assignments"))
```

10.3 — **Add French translations** for all extracted strings. Use natural French (not Google Translate quality).

10.4 — **Localize date/time formatting**. Replace any hardcoded DateFormatter format strings with locale-aware formatting:
```swift
// Before:
formatter.dateFormat = "MMM d, h:mm a"

// After:
formatter.dateStyle = .medium
formatter.timeStyle = .short
// OR use .formatted() with explicit locale
```

10.5 — **Add language picker** in AppSettingsView. Let users override the system language with: English, French. Store in UserDefaults.

---

### Agent 11: Report Card / Transcript PDF Export

**Problem**: `ReportCardView.swift` exists but students/parents can't export an actual PDF transcript.

**Read first**:
- `WolfWhaleLearning/Views/Student/ReportCardView.swift`
- `WolfWhaleLearning/Models/` — Grade models

**Tasks**:

11.1 — **Create `TranscriptPDFGenerator.swift`** in `Services/`:
```swift
@MainActor
final class TranscriptPDFGenerator {
    /// Generates a formatted PDF transcript for a student.
    /// Includes: student name, school, date, all courses with grades, GPA, attendance summary.
    func generateTranscript(
        student: User,
        courses: [Course],
        grades: [GradeEntry],
        attendance: [AttendanceRecord]
    ) -> Data  // PDF data
}
```

11.2 — **PDF layout** using UIGraphicsPDFRenderer:
- Header: School logo placeholder, "Official Transcript", date generated
- Student info: Name, Student ID, Grade Level, School Year
- Table: Course Name | Teacher | Grade | Letter Grade | Credits
- Footer: Cumulative GPA, Total Credits, Attendance Rate (%)
- Page numbers if multi-page
- Styled with the app's indigo/purple theme colors

11.3 — **Add "Export PDF" button** in ReportCardView:
```swift
ShareLink(item: pdfData, preview: SharePreview("Transcript", image: ...)) {
    Label("Export Transcript", systemImage: "arrow.down.doc.fill")
}
```

11.4 — **Add "Email to Parent" option** — pre-fill a `MFMailComposeViewController` with the PDF attached and the parent's email address.

---

### Agent 12: Progress Tracking Dashboard

**Problem**: Students need visual progress indicators per course — how many lessons completed, assignments submitted, current grade trend.

**Read first**:
- `WolfWhaleLearning/Views/Student/StudentDashboardView.swift`
- `WolfWhaleLearning/Views/Student/CourseDetailView.swift`
- `WolfWhaleLearning/Models/` — LessonCompletion, Submission models

**Tasks**:

12.1 — **Create `CourseProgressCard.swift`** in `Views/Components/`:
- Circular progress ring showing % of lessons completed
- Text: "12 of 20 lessons completed"
- Mini bar chart: assignment submission rate
- Current grade with letter and color
- "Continue" button that navigates to the next uncompleted lesson

12.2 — **Add progress cards to StudentDashboardView** — show a horizontal scroll of CourseProgressCards for all enrolled courses.

12.3 — **Add progress bar to CourseDetailView** — at the top, show:
- Overall completion percentage (lessons completed + assignments submitted)
- Breakdown: Lessons (X/Y), Assignments (X/Y), Quizzes (X/Y)
- Estimated time remaining based on average lesson duration

12.4 — **Create `ProgressService.swift`** in `Services/`:
```swift
@MainActor @Observable
final class ProgressService {
    func courseCompletion(courseId: UUID, lessons: [Lesson], completions: [LessonCompletion]) -> Double
    func assignmentCompletion(courseId: UUID, assignments: [Assignment], submissions: [Submission]) -> Double
    func overallProgress(courseId: UUID) -> CourseProgress  // struct with all metrics
    func studyStreak(completions: [LessonCompletion]) -> Int  // consecutive days
}
```

12.5 — **Weekly progress summary** — on the dashboard, show "This week: X lessons completed, Y assignments submitted, Z quizzes taken" with comparison to last week (up/down arrows).

---

### Agent 13: Due Date Reminders (Local Notifications)

**Problem**: `NotificationService.swift` exists but assignment due date reminders may not actually be scheduled when assignments are loaded.

**Read first**:
- `WolfWhaleLearning/Services/NotificationService.swift`
- `WolfWhaleLearning/ViewModels/AppViewModel.swift` — loadData() method

**Tasks**:

13.1 — **Schedule reminders automatically** when assignments are loaded. In AppViewModel's `loadData()` or wherever assignments are fetched, call:
```swift
await notificationService.scheduleAssignmentReminders(assignments)
```

13.2 — **The reminder scheduling method** should:
- Remove all previously scheduled assignment reminders first
- For each assignment due in the next 7 days:
  - Schedule "24 hours before" reminder: "{assignment} is due tomorrow in {course}"
  - Schedule "1 hour before" reminder: "{assignment} is due in 1 hour!"
- Cap at 20 assignments (40 notifications) to stay under iOS 64 limit
- Skip assignments that are already past due
- Skip assignments that have already been submitted

13.3 — **Add reminder preferences** in NotificationSettingsView:
- Toggle: Assignment reminders on/off
- Picker: Remind me (24h before, 12h before, 6h before, 1h before) — multi-select
- Toggle: Grade notifications
- Toggle: Message notifications
- Store all in UserDefaults

13.4 — **Re-schedule on app foreground**. When app comes to foreground (`scenePhase == .active`), refresh reminders in case assignments changed.

---

### Agent 14: Universal In-App Search

**Problem**: Spotlight indexes content for system search, but there's no unified in-app search bar that searches across courses, assignments, messages, and people.

**Read first**:
- `WolfWhaleLearning/Services/SpotlightService.swift`
- All list views with search functionality

**Tasks**:

14.1 — **Create `UniversalSearchView.swift`** in `Views/`:
- Single search bar at the top
- As user types (debounced 300ms), search across:
  - Courses (name, description)
  - Assignments (title, description)
  - Messages (content, sender name)
  - People (name, email)
  - Lessons (title, content)
- Results grouped by category with section headers
- Tapping a result navigates to the appropriate detail view

14.2 — **Create `SearchService.swift`** in `Services/`:
```swift
@MainActor @Observable
final class SearchService {
    struct SearchResult: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let category: SearchCategory
        let icon: String  // SF Symbol name
        let destination: SearchDestination
    }

    enum SearchCategory: String, CaseIterable {
        case courses, assignments, messages, people, lessons
    }

    func search(query: String, in categories: Set<SearchCategory>) async -> [SearchResult]
}
```

14.3 — **Add search to the main tab bar** — magnifying glass icon that presents UniversalSearchView as a sheet or full-screen cover.

14.4 — **Recent searches** — store last 10 search queries in UserDefaults and show as suggestions when the search field is empty.

14.5 — **Search suggestions** — as user types, show autocomplete suggestions below the search bar based on indexed content.

---

## **PHASE 3 — POLISH FOR LAUNCH**

---

### Agent 15: Onboarding Flow Completion

**Read first**: `WolfWhaleLearning/Views/Onboarding/OnboardingView.swift`

**Tasks**:

15.1 — **Ensure onboarding covers**:
- Welcome screen with app logo and tagline
- Role selection (if not pre-assigned): Student, Teacher, Parent
- Enable notifications permission prompt
- Enable biometric auth prompt
- For students: select grade level, interests
- For parents: link to child's account (enter child's student ID or email)
- "Get Started" button that dismisses onboarding and sets `hasCompletedOnboarding` in UserDefaults

15.2 — **Show onboarding only once** — check UserDefaults on app launch. If `hasCompletedOnboarding` is false, show onboarding before the main app.

15.3 — **Add a "What's New" screen** that shows after app updates (compare stored version with current bundle version).

---

### Agent 16: Error States & Empty States

**Read first**: Scan all major list views and dashboard views.

**Tasks**:

16.1 — **Create `EmptyStateView.swift`** in `Views/Components/`:
```swift
struct EmptyStateView: View {
    let icon: String        // SF Symbol
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?
}
```

16.2 — **Add empty states** to every list view:
- Courses: "No courses yet" + "Browse Course Catalog" button (for students) or "Create Course" (for teachers)
- Assignments: "No assignments due" with celebration icon
- Grades: "No grades yet — complete assignments to see grades here"
- Messages: "No conversations yet" + "Start a Conversation" button
- Attendance: "No attendance records"
- Leaderboard: "Leaderboard is empty — earn XP to appear here"

16.3 — **Create `ErrorStateView.swift`** in `Views/Components/`:
```swift
struct ErrorStateView: View {
    let message: String
    let retryAction: () async -> Void
    // Shows error icon, message, and "Try Again" button
}
```

16.4 — **Add error states** to every view that loads data. When `viewModel.error != nil`, show ErrorStateView instead of content.

16.5 — **Add loading skeletons** — when data is loading for the first time (empty array + isLoading), show shimmer/skeleton placeholder views instead of a spinner. Create a `SkeletonView` modifier:
```swift
.redacted(reason: .placeholder)
.shimmer()  // custom shimmer animation modifier
```

---

### Agent 17: Pull-to-Refresh

**Tasks**:

17.1 — **Add `.refreshable`** to every scrollable list view:
- StudentDashboardView
- CoursesListView
- AssignmentsView
- GradesView
- MessagesListView
- AttendanceHistoryView
- LeaderboardView
- TeacherDashboardView (all teacher list views)
- ParentDashboardView
- AdminDashboardView

Pattern:
```swift
ScrollView {
    // content
}
.refreshable {
    await viewModel.refreshCourses()  // or appropriate refresh method
}
```

17.2 — **Add refresh methods** to AppViewModel (or domain ViewModels) that re-fetch only the relevant data, not everything.

---

### Agent 18: Image Caching

**Read first**: Any views that display profile photos or course images.

**Tasks**:

18.1 — **Create `CachedAsyncImage.swift`** in `Views/Components/`:
```swift
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image

    // Uses URLCache or NSCache to store downloaded images
    // Shows placeholder while loading
    // Handles errors gracefully (shows placeholder)
    // Supports profile photos (circular clip) and course banners (rounded rect)
}
```

18.2 — **Replace all raw `AsyncImage`** calls with `CachedAsyncImage` throughout the app. Search for `AsyncImage` in all view files.

18.3 — **Set a cache size limit** (50MB in memory, 200MB on disk) to prevent memory bloat.

---

### Agent 19: Rate Limiting & Double-Tap Prevention

**Tasks**:

19.1 — **Create a `SubmitButton.swift`** component:
```swift
struct SubmitButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    @State private var isSubmitting = false

    // Disables itself while action is in-flight
    // Shows progress indicator while submitting
    // Prevents double-tap
}
```

19.2 — **Replace all submission buttons** in these views:
- SubmitAssignmentView ("Submit" button)
- CreateQuizView ("Create Quiz" button)
- GradeSubmissionView ("Submit Grade" button)
- ConversationView ("Send" button)
- SignUpView ("Create Account" button)
- LoginView ("Log In" button)
- Any "Save", "Create", "Submit", "Send" buttons

19.3 — **Add debounce to all search fields** — 300ms delay before firing the search. Apply to:
- CoursesListView search
- UserManagementView search
- MessagesListView search
- Any view with a `.searchable()` modifier

---

### Agent 20: App Store Compliance

**Tasks**:

20.1 — **Privacy Nutrition Labels** — Read `PrivacyInfo.xcprivacy` and ensure it declares ALL data types collected:
- Name, email (account creation)
- Health data (HealthKit)
- Location (geofencing)
- Contacts (if accessing)
- Photos (photo picker)
- Usage data (analytics)

20.2 — **Age Gate** — If this is a K-12 LMS, it likely needs COPPA compliance:
- Add age verification during signup (date of birth)
- If under 13, require parent email and consent
- Add parental consent flow

20.3 — **Account deletion** (REQUIRED by App Store since 2022):
- Add "Delete Account" in Settings
- Confirmation dialog explaining what will be deleted
- Actually delete user data from Supabase
- Sign out after deletion

20.4 — **Terms of Service & Privacy Policy** — `TermsOfServiceView.swift` and `PrivacyPolicyView.swift` exist. Ensure:
- They are shown during signup (checkbox: "I agree to Terms and Privacy Policy")
- They are accessible from Settings
- They contain real legal text (not placeholder)

20.5 — **Export compliance** — Add `ITSAppUsesNonExemptEncryption = NO` to Info.plist if using only standard HTTPS (which Supabase does). This prevents the export compliance questionnaire on every App Store submission.

---

## EXECUTION ORDER

**Build in this order (dependencies)**:

1. **Phase 1 first** (Agents 1-8) — these are blockers
   - Agent 1 (Navigation) has no dependencies — start immediately
   - Agent 2 (Messaging) has no dependencies — start immediately
   - Agent 3 (Files) has no dependencies — start immediately
   - Agent 4 (Video) has no dependencies — start immediately
   - Agent 5 (Quiz Builder) has no dependencies — start immediately
   - Agent 6 (Grades) has no dependencies — start immediately
   - Agent 7 (Enrollment) has no dependencies — start immediately
   - Agent 8 (Auth) has no dependencies — start immediately

2. **Phase 2 next** (Agents 9-14) — these depend on Phase 1 data being correct
   - Agent 9 (Push) depends on Agent 2 (messaging triggers)
   - Agent 10 (i18n) can start independently
   - Agent 11 (PDF Export) depends on Agent 6 (grade calculation)
   - Agent 12 (Progress) can start independently
   - Agent 13 (Reminders) can start independently
   - Agent 14 (Search) can start independently

3. **Phase 3 last** (Agents 15-20) — polish, can all run in parallel

---

## FOR ALL AGENTS:

- Read the actual code before changing it
- Follow the project's existing patterns (lazy services, @Observable, nonisolated models)
- Use `Color(UIColor.systemGroupedBackground)` not `Color(.systemGroupedBackground)`
- Wrap UIKit-only APIs in `#if canImport(UIKit)`
- Wrap iOS-only APIs in `#if os(iOS)`
- Add `.sensoryFeedback(.impact, trigger:)` on important button actions
- Use `.ultraThinMaterial` for overlay backgrounds
- Use indigo/purple theme colors consistent with existing views
- Every change must compile for iOS 26
- Do NOT delete or modify existing working features
- Commit all changes with descriptive message and push to git when done
