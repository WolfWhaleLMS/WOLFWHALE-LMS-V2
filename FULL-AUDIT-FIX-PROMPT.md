# WOLFWHALE LMS V2 — Full Audit Fix Prompt

Use this prompt with Claude Code to fix every issue found in the comprehensive audit.

---

This is a SwiftUI iOS school LMS at /Users/rylanddupre/WOLFWHALE-LMS-V2/. It targets iOS 26+.
Fix every performance, reliability, security, and architecture issue found in the audit below.
Launch parallel agents for each phase.

IMPORTANT: Read the actual code before making changes. Do NOT remove features. Do NOT change
the app's visual design. Only fix the underlying architecture, performance, and reliability
issues. Every change must compile. Commit and push when done.

---

## **Agent 1 — SupabaseService Pagination & Query Optimization**

Read: `WolfWhaleLearning/Services/SupabaseService.swift` (the entire file, it's large)

### Fix 1.1: Add cursor-based pagination to ALL fetch methods

Every fetch method currently has hardcoded limits with no way to load more. Add `offset` and
`limit` parameters with defaults to every fetch function:

- `fetchCourses()` — currently `limit(100)`. Add `offset: Int = 0, limit: Int = 50` params.
  Return a struct with `items: [Course]` and `hasMore: Bool`.
- `fetchAssignments()` — currently `limit(50)`. Same pagination pattern.
- `fetchQuizzes()` — currently `limit(50)`. Same.
- `fetchConversations()` — currently `limit(50)`. Same.
- `fetchAchievements()` — currently `limit(100)`. Same.
- `fetchAttendance()` — currently `limit(50)`. Same.
- `fetchAllUsers()` — currently loads ALL users. Add pagination. The comment on ~line 1102
  already says "NOTE: This should be paginated for very large deployments with 1000+ users" —
  implement it.

### Fix 1.2: Fix fetchSchoolMetrics() memory explosion

`fetchSchoolMetrics()` (~line 1142-1229) loads ALL enrollments, ALL grades, and ALL assignments
into memory to calculate aggregate stats. At 10K users this is 1M+ records in RAM.

Fix: Replace client-side aggregation with Supabase RPC calls or paginated aggregation:
- Calculate student count with `.select("id", head: true, count: .exact)` instead of loading
  all profiles
- Calculate average GPA with a server-side function or paginated sampling
- Calculate course/enrollment counts with count queries, not loading full arrays
- Remove `Array(profiles.filter { ... }.prefix(200))` — this arbitrarily caps at 200 students
  making GPA inaccurate

### Fix 1.3: Fix message loading

`fetchConversations()` uses `min(30 * convIds.count, 300)` which arbitrarily caps total
messages. Replace with per-conversation message loading:
- Load only the LAST message per conversation for the list view
- Load messages per-conversation with cursor pagination when user opens a conversation
- Add `fetchMessages(conversationId:, before: Date?, limit: Int = 30)` method

### Fix 1.4: Fix fetchAllUsers tenant_memberships query

~Line 1103-1108: Fetches ALL tenant_memberships to look up roles, even when paginating user
profiles. Instead, join the role lookup into the profiles query or fetch memberships only for
the current page of users.

### Fix 1.5: Fix EnrollmentRateLimiter memory leak

~Line 1123-1141: The `attempts` array in EnrollmentRateLimiter is cleaned with
`removeAll { $0.time < cutoff }` but old entries accumulate. Also make it actor-isolated
instead of using NSLock, since this is used in async context.

### Fix 1.6: Add retry logic with exponential backoff

No queries have retry logic. Add a generic retry wrapper:
```swift
func withRetry<T>(maxAttempts: Int = 3, _ operation: () async throws -> T) async throws -> T
```
Apply it to all network-dependent fetch methods.

### Fix 1.7: Add graceful partial failure handling

`fetchCourses()` makes 4+ sequential queries. If query 3 fails, everything fails. Instead,
use TaskGroup and return partial results with an error flag, so users see courses even if
enrollment counts fail to load.

### Fix 1.8: Remove @unchecked Sendable from DataService

Line 13: `struct DataService: @unchecked Sendable` is unsafe — it hides potential data races.
Either make it truly Sendable (no mutable state) or convert to an actor.

---

## **Agent 2 — AppViewModel Refactor & State Management**

Read: `WolfWhaleLearning/ViewModels/AppViewModel.swift` (entire file)

### Fix 2.1: Break up the monolithic AppViewModel

AppViewModel holds ALL app state in one object (~lines 16-27):
- courses, assignments, quizzes, grades, attendance, achievements, leaderboard,
  conversations, announcements, children, schoolMetrics, allUsers

This causes every @Published change to trigger re-renders across the entire app.

Split into domain-specific ViewModels:
- `CourseViewModel` — courses, enrollment
- `AssignmentViewModel` — assignments, submissions
- `GradeViewModel` — grades, GPA
- `MessageViewModel` — conversations, messages
- `AdminViewModel` — allUsers, schoolMetrics, announcements
- `AuthViewModel` — login state, user profile, biometric auth

Each should be injected via @Environment where needed, not passed through every view.

### Fix 2.2: Remove allUsers from memory

~Line 493-500: `allUsers = try? await self.dataService.fetchAllUsers(...)` loads every user
in the school into an array. For 10K users this is catastrophic.

Replace with:
- Paginated loading (load 20 at a time)
- Server-side search (pass search query to Supabase `.ilike()` filter)
- Only load users that are currently visible in the list

### Fix 2.3: Add pagination state management

Each paginated data source needs:
```swift
struct PaginatedState<T> {
    var items: [T] = []
    var isLoading = false
    var hasMore = true
    var currentOffset = 0

    mutating func appendPage(_ newItems: [T], pageSize: Int) {
        items.append(contentsOf: newItems)
        currentOffset += newItems.count
        hasMore = newItems.count >= pageSize
    }
}
```

Apply this pattern to courses, assignments, grades, conversations, users, achievements.

### Fix 2.4: Add search debouncing

Add a debounce utility and apply it everywhere search/filter happens:
```swift
func debounce(delay: Duration = .milliseconds(300), action: @escaping () async -> Void) -> ...
```

Apply to: CoursesListView search, UserManagementView search, MessagesListView search,
AssignmentsView filter, any other text-driven filtering.

### Fix 2.5: Fix loadData() to not fetch everything at once

~Lines 440-500: `loadData()` fires ALL data fetches concurrently on login. For a student,
it fetches courses AND assignments AND quizzes AND grades AND attendance AND achievements AND
leaderboard AND conversations AND announcements all at once.

Instead:
- Load only what the first visible tab needs (dashboard summary)
- Lazy-load other data when user navigates to that tab
- Use `.task` modifier on each tab's root view, not on login

---

## **Agent 3 — View Pagination & Performance**

Read: All views that display lists of data

### Fix 3.1: Add infinite scroll to all list views

These views currently render ALL items with no pagination:
- `GradesView.swift` (~line 91-147) — renders all 1500 grades
- `AssignmentsView.swift` (~line 25-51) — renders all assignments
- `UserManagementView.swift` — renders all users
- `CoursesListView.swift` — renders all courses
- `MessagesListView.swift` — renders all conversations
- `LeaderboardView.swift` — renders all entries
- `AttendanceHistoryView.swift` — renders all records

For each: Add `.onAppear` on the last item to trigger loading the next page. Use LazyVStack
instead of VStack where ScrollView is used.

### Fix 3.2: Fix computed property filtering

These computed properties recalculate on every render:
- `CoursesListView.filteredCourses` (~line 13-19)
- `UserManagementView.filteredUsers` (~line 13-21)
- `AssignmentsView` filtered assignments
- `GradesView` filtered grades

Move server-side where possible. For client-side filtering, cache the result with @State
and only recalculate when the filter input changes (use `.onChange(of: searchText)`).

### Fix 3.3: Use LazyVStack everywhere

Search all dashboard views for `VStack` inside `ScrollView` and replace with `LazyVStack`
where the VStack contains a `ForEach`. This prevents rendering off-screen items.

Files to check:
- StudentDashboardView.swift
- TeacherDashboardView.swift
- AdminDashboardView.swift
- SuperAdminDashboardView.swift
- ParentDashboardView.swift
- All list/grid views

---

## **Agent 4 — Security & Data Isolation Fixes**

Read: OfflineStorageService.swift, BiometricAuthService.swift, PushNotificationService.swift,
LoginView.swift, all Auth views

### Fix 4.1: Fix cross-user offline cache data leak (CRITICAL SECURITY)

`OfflineStorageService.swift` (~line 277-291): If `currentUserId` is nil, all users write to
the same shared `OfflineCache/` directory. User A's grades/assignments could be visible to
User B.

Fix:
- REFUSE to read/write cache if `currentUserId` is nil — return empty data
- On logout, call `clearCurrentUserCache()` to wipe the previous user's data
- Add a guard at the top of every read/write method:
  `guard currentUserId != nil else { return [] }`

### Fix 4.2: Fix PushNotificationService multi-device token handling

`PushNotificationService.swift` (~line 78-119): When user logs in on Device B, it DELETES
the token for Device A, so Device A stops receiving push notifications.

Fix: Use upsert with device-specific identifier instead of delete+insert:
```swift
try await supabaseClient.from("device_tokens")
    .upsert([
        "user_id": userId.uuidString,
        "device_id": UIDevice.current.identifierForVendor?.uuidString,
        "token": tokenString,
        "platform": "ios"
    ], onConflict: "user_id,device_id")
    .execute()
```

### Fix 4.3: Add biometric auth timeout

`BiometricAuthService.swift` (~line 58-81): No timeout on Face ID prompt. Add a timeout:
```swift
let result = try await withThrowingTaskGroup(of: Bool.self) { group in
    group.addTask { try await context.evaluatePolicy(...) }
    group.addTask { try await Task.sleep(for: .seconds(30)); throw BiometricError.timeout }
    let first = try await group.next()!
    group.cancelAll()
    return first
}
```

### Fix 4.4: Clear sensitive data on logout

When user logs out, ensure:
- All cached data is cleared (offline storage)
- Audio services are stopped
- Realtime subscriptions are unsubscribed
- Push notification token is NOT deleted (they'll need it when they log back in)
- All @Published arrays are emptied
- Any keychain-stored tokens are cleared

---

## **Agent 5 — Service Lifecycle & Resource Management**

Read: MusicService.swift, RadioService.swift, RealtimeService.swift, NotificationService.swift,
CalendarService.swift, CacheService.swift, NetworkMonitor.swift, all services

### Fix 5.1: Fix MusicService audio session leak

`MusicService.swift` (~line 7-19): Audio continues playing after logout. The service has no
lifecycle management.

Fix:
- Add a `stopAll()` method that stops playback AND deactivates the audio session
- Call `stopAll()` on logout from AppViewModel
- Ensure RadioView's mini player stops when RadioView disappears AND user navigates away

### Fix 5.2: Fix RealtimeService reconnection

`RealtimeService.swift` (~line 41-106): No reconnection logic when network drops.

Fix:
- Listen to NetworkMonitor status changes
- When network comes back online, automatically resubscribe to channels
- Add exponential backoff for reconnection attempts
- Properly clean up old channel before creating new one

### Fix 5.3: Fix NotificationService over-scheduling

`NotificationService.swift` (~line 114-155): Schedules 2 notifications per assignment
(24h and 1h before). 50 assignments = 100 local notifications.

Fix:
- Cap at 10 upcoming assignment reminders (iOS has a 64 pending notification limit)
- Only schedule for assignments due in the next 7 days
- Remove old notifications before scheduling new ones:
  `UNUserNotificationCenter.current().removeAllPendingNotificationRequests()`

### Fix 5.4: Optimize CacheService eviction

`CacheService.swift` (~line 20-30): Uses `.min()` O(n) scan for eviction.

Fix: Either:
- Use an ordered data structure (sorted array by expiry)
- Or simply evict 10% of oldest entries at once when full, instead of one at a time

### Fix 5.5: Add connection quality detection to NetworkMonitor

`NetworkMonitor.swift`: Only detects online/offline. Add:
- `isExpensive` (cellular) detection
- `isConstrained` (Low Data Mode) detection
- Expose connection type (wifi/cellular/none)
- Let views adapt (e.g., don't auto-load images on cellular)

### Fix 5.6: Fix RadioService/MusicService search debouncing

`MusicService.swift` (~line 47-67): Search requests to Apple Music API are not debounced.
Typing "study music" fires 11 API requests.

Fix: Add 300ms debounce on search input before making API call.

---

## **Agent 6 — Model & Data Layer Cleanup**

Read: All files in Models/, SupabaseService.swift date handling

### Fix 6.1: Make models Codable directly

`Course`, `Assignment`, `Quiz`, etc. don't conform to Codable. The OfflineStorageService
uses separate `CodableCourse`, `CodableAssignment` wrapper types for serialization. This
doubles the model surface area.

Fix: Add Codable conformance directly to the primary model types. Remove the
Codable wrapper types and update OfflineStorageService to use the models directly.

### Fix 6.2: Fix inconsistent date parsing

`SupabaseService.swift` (~line 22-35): Has custom DateFormatter instances alongside
ISO8601DateFormatter. Standardize on one approach.

### Fix 6.3: Create a PaginatedResponse generic

```swift
struct PaginatedResponse<T> {
    let items: [T]
    let totalCount: Int
    let hasMore: Bool
    let nextOffset: Int
}
```

Use this as the return type for all paginated fetch methods across the entire data layer.

---

## **Agent 7 — LoginView & Compiler Diagnostic Fixes**

Read: LoginView.swift, check all SourceKit errors across the project

### Fix 7.1: Fix LoginView SourceKit errors

Current diagnostics show these issues in LoginView.swift:
- Line ~131: `Initializer 'init(_:)' requires that 'SeparatorShapeStyle' conform to
  'Hashable'` — The `.strokeBorder(... Color(.separator) ...)` usage is incompatible.
  Fix: Use `Color.gray.opacity(0.3)` instead of `Color(.separator)`.
- Check that `.glassEffect()` usage compiles with the `.fill(.clear)` pattern — if not,
  remove the `.fill(.clear)` and apply `.glassEffect()` directly to the container.

### Fix 7.2: Audit all views for deprecated iOS 26 APIs

The build output showed deprecation warnings:
- `ClassroomFinderView.swift` lines 93, 123: `MKPlacemark` deprecated in iOS 26.
  Fix: Use `MKMapItem(location:address:)` instead.
- `NFCAttendanceView.swift` lines 294, 302, 310, 318: Redundant `case nil, .none` —
  remove the `.none` cases.

### Fix 7.3: Remove unused LoginAudioService import/references

The `LoginAudioService` was removed from LoginView but the service file still exists.
Check if LoginAudioService.swift is used anywhere else. If not, delete the file.

---

## For ALL agents:
- Read the actual code before changing it
- Do NOT remove any features or UI
- Do NOT change the visual design (Liquid Glass styling, colors, layout)
- Every change must compile for iOS 26 on iPhone 17 Pro simulator
- Add brief inline comments only where the fix is non-obvious
- After all agents complete, do a final build verification
- Commit with message describing the fixes and push
