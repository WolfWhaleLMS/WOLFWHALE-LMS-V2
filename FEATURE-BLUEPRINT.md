# WolfWhale LMS v2 — Complete Feature Blueprint

**Platform:** iOS 17+ (SwiftUI) | **Backend:** Supabase
**Roles:** Student, Teacher, Parent, Admin, Super Admin
**Total Features:** ~106 | **Swift Files:** ~355 | **Lines of Code:** ~122K

---

## 1. Authentication & Security

| Feature | Roles | Description |
|---------|-------|-------------|
| Email/Password Auth | All | Sign-up with invite code, email verification, password reset, session auto-refresh |
| Biometric Auth | All | Face ID, Touch ID, Optic ID auto-lock on background/resume |
| Role-Based Access Control | All | RoleGuard ViewModifier + Supabase RLS on 42+ tables |
| Age Verification & COPPA | All | Date-of-birth age gate (min age 5), verifiable parental consent for under-13, annual renewal |
| Terms & Legal | All | Terms of Service, Privacy Policy, Data Privacy (FERPA/GDPR) acceptance flows |
| Certificate Pinning | All | TLS certificate validation on all Supabase connections |
| Audit Logging | Admin, SuperAdmin | Tracks login/logout/CRUD/grade changes/exports with IP, timestamp, entity type |

---

## 2. Onboarding

| Feature | Roles | Description |
|---------|-------|-------------|
| 5-Page Animated Onboarding | All | Animated gradient backgrounds, notification permission, biometric opt-in, skip on every page |
| What's New Screen | All | Version-based feature announcements after app updates |

---

## 3. Student Features

| Feature | Description |
|---------|-------------|
| **Dashboard** | Snapshot card (courses, due soon, GPA), course carousel, due-soon assignments, 7 quick links, floating radio button |
| **Course Management** | Browse enrolled courses, course detail (modules, lessons, progress ring), course catalog, enroll by class code, prerequisites checking |
| **Lessons & Content** | 4 lesson types (reading, video, activity, quiz), slide-based presentation, video progress tracking with resume, XP rewards on completion |
| **Assignments & Submissions** | View by course, calendar view, text + file submissions (10MB max), late submission support, 4 penalty types, resubmission with history |
| **Quizzes** | 5 question types (MC, T/F, fill-blank, matching, essay), timed quizzes, instant scoring, quiz review |
| **Grades & Records** | Weighted grade calculation, per-course breakdown, GPA on 4.0 scale, grade trend analysis, transcript PDF generation + export |
| **Progress & Goals** | Per-course progress tracking, weekly summary, study streak, set grade target goals per course, "next up" items |
| **Attendance History** | View records (present/absent/tardy/excused), filter by course, monthly view, attendance rate stats |
| **Schedule & Timetable** | Weekly timetable grid (8AM-4PM, Mon-Sat), color-coded course blocks, today highlighting |
| **Peer Review** | Review peer submissions with rubric scoring, feedback text, status tracking |
| **AI Study Assistant** | On-device AI via Apple FoundationModels, chat interface, session history, educational system prompt |
| **Learning Recommendations** | 8 recommendation types, 4 priority levels, student analytics (strong/weak subjects, predicted performance) |
| **School ID & Wallet** | Digital school ID card with barcode, Add to Apple Wallet via PassKit |
| **Student Profile** | Avatar, stats grid, offline mode toggle, achievements, streak counter, appearance settings |
| **File Manager** | Browse uploaded files, download/preview, delete, associated course/assignment display |

---

## 4. Interactive Learning Resources (~25 tools)

### Study Tools
- Flashcard Creator (decks, classic flip mode, quiz mode)
- Unit Converter
- Typing Tutor
- AI Study Assistant (Apple Intelligence)

### Mathematics
- Math Quiz
- Fraction Builder (visual manipulation)
- Geometry Explorer

### Science
- Interactive Periodic Table
- Human Body Explorer

### English
- Word Builder
- Spelling Bee
- Grammar Quest

### French
- French Vocabulary (categories, detail views, quiz mode)
- French Verbs (conjugation practice)

### Canadian Studies
- Canadian History Timeline
- Canadian Geography
- Indigenous Peoples

### Geography
- World Map Quiz

### AR Experiences
- AR Library (8 subject categories, 4 experience types, grade-level tagging)
- Human Cell AR Experience

### Games
- Chess (full implementation, 3 bot difficulties, also playable via iMessage)

### Learning Tools
- Document Scanner (VisionKit + Vision OCR, multi-page, PDF export)
- Drawing Canvas (PencilKit, 4 tools, 4 backgrounds)
- Speech to Text (6 languages, real-time transcription with confidence scores)

---

## 5. Gamification & Engagement

| Feature | Description |
|---------|-------------|
| **XP & Leveling** | XP per lesson/assignment/quiz, exponential level curve, 5 tiers (Beginner through Master) |
| **Achievements & Badges** | 10 badge types, 4 rarity levels (Common, Rare, Epic, Legendary), progress tracking |
| **Aquarium** | Virtual aquarium with animated fish unlocked by study streak, 6 rarity tiers, fish collection browser |
| **Study Pet Widget** | In-app study pet companion on dashboard |
| **Retro Sound Effects** | 7 8-bit sound types synthesized via AVAudioEngine, respects silent mode |

---

## 6. Media & Entertainment

| Feature | Description |
|---------|-------------|
| **Study Radio** | 4 stations (Classical, Lo-Fi, Ambient, School News), live streaming, volume control, 12-bar visualizer, lock screen controls |
| **Music Discovery** | MusicKit + Apple Music integration, study playlists, search, playback via ApplicationMusicPlayer |
| **Photo Filters** | 10 Core Image filters (Vivid, Warm, Cool, Noir, Chrome, etc.), GPU-accelerated |

---

## 7. Collaboration & Communication

| Feature | Roles | Description |
|---------|-------|-------------|
| **Real-Time Messaging** | All | Supabase Realtime WebSocket, typing indicators, unread counts, message status, content moderation (COPPA), auto-reconnect |
| **Discussion Forums** | Student, Teacher | Per-course threads, threaded replies |
| **SharePlay Study** | Student | FaceTime GroupActivities, synchronized pages/annotations, collaborative quiz mode |
| **Peer Study Groups** | Student | MultipeerConnectivity (Bonjour), encrypted P2P, real-time chat, share notes |
| **VoIP Calls** | Teacher, Parent | CallKit native call UI, mute/speaker toggle, call duration tracking |
| **iMessage Extension** | Student | WolfWhale sticker pack + iMessage Chess game |

---

## 8. Teacher Features

| Feature | Description |
|---------|-------------|
| **Dashboard** | 4 overview cards, enrollment requests banner, at-risk students, 6 quick actions, recent submissions, Live Activity banner |
| **Course Management** | Create/edit courses, icon + color picker, auto-generated class codes, module/lesson creation, student roster |
| **Gradebook** | Per-course gradebook, individual + bulk grading, grade export (CSV/PDF), grade curve, configurable weights |
| **Assignment & Quiz Creation** | Rich assignment editor, 4 late penalty types, resubmission config, rubric builder, enhanced quiz builder (5 types), standards alignment |
| **Attendance** | Manual per-class taking, NFC scanning (CoreNFC), attendance reports, CSV export, analytics charts |
| **Student Insights** | Per-student grade/attendance/trend, at-risk identification, sort/filter, private teacher notes |
| **Plagiarism Detection** | Cross-submission similarity comparison, 3 severity tiers, matching excerpts display |
| **Standards Mastery** | Common Core Math & ELA tracking (grades 6-8), link assignments to standards |
| **Enrollment Approval** | View/approve/deny enrollment requests, pending count badge |
| **Peer Review Setup** | Configure peer review, assign reviewers, set criteria |
| **Report Cards** | Generate per-student report cards with course entries, attendance, teacher comments |
| **Conferences** | Manage available slots, view/confirm/cancel parent requests |
| **Live Activity** | Class session + assignment due Dynamic Island/Lock Screen via ActivityKit |

---

## 9. Parent Features

| Feature | Description |
|---------|-------------|
| **Dashboard** | Server-verified parent-child links, 3 alert types (low grade, absence, upcoming due), child cards with GPA/attendance/grades |
| **Child Detail** | Course-by-course grades, attendance records, upcoming assignments |
| **Conference Scheduling** | Browse teacher slots, request conferences with topic/notes |
| **Weekly Digest** | Grade changes, completed/upcoming assignments, attendance summary, teacher comments |
| **Messaging** | Direct messaging to teachers (COPPA-compliant) |

---

## 10. Admin Features

| Feature | Description |
|---------|-------------|
| **Dashboard** | 6 school metrics, weekly attendance chart, 8 quick actions |
| **User Management** | Browse/search/filter all users, add/delete users, capacity tracking |
| **Bulk Import** | CSV upload + parse + validate + preview + import with progress tracking |
| **Announcements** | Create school-wide announcements (triggers push notification) |
| **School Config** | School name and tenant-level settings |
| **Class Sections** | Manage sections, course-section associations, capacity |
| **Academic Calendar** | Terms (semester/quarter/trimester), events, grading periods |
| **Report Cards** | School-wide report card generation and oversight |
| **Analytics Dashboard** | Daily active users, submissions, attendance charts (7/30/90 day), Swift Charts |

---

## 11. Super Admin Features

| Feature | Description |
|---------|-------------|
| **Multi-Tenant Console** | System health (tenant count, total users, capacity %), add tenants with auto invite codes, edit user limits, per-tenant stats |

---

## 12. Notifications & Reminders

| Feature | Description |
|---------|-------------|
| **Push Notifications** | APNs via Supabase Edge Function, 4 event types, JWT signing, deep-link routing, Keychain token storage |
| **Local Reminders** | 4 timing options (24h/12h/6h/1h before due), smart budgeting (max 40), auto-refresh on data changes |
| **Notification Preferences** | Per-category toggles (assignments, grades, messages, announcements), reminder timing selection |

---

## 13. Wellness & Health

| Feature | Description |
|---------|-------------|
| **Wellness Dashboard** | HealthKit: steps, distance, calories, heart rate, sleep hours, wellness score (0-100), weekly step chart, workout tracking, hydration tracker |

---

## 14. Location & Campus

| Feature | Description |
|---------|-------------|
| **Geofencing** | Campus boundary detection (CoreLocation), configurable center + radius, on/off campus status |
| **Campus Map** | 7 location types (classroom, library, gym, etc.), building/floor/room display |

---

## 15. Offline & Sync

| Feature | Description |
|---------|-------------|
| **Offline Storage** | AES-GCM encrypted per-user local storage, Keychain-stored keys, 8 cached entity types |
| **iCloud Sync** | Key-value sync for preferences, PII masking, sync toggle |
| **Conflict Resolution** | Server-wins strategy, timestamp comparison, conflict history (max 50), auto-sync on recovery |
| **Network Monitor** | NWPathMonitor, connection type detection, isExpensive/isConstrained flags, offline banner |

---

## 16. Writing & Text Tools

| Feature | Description |
|---------|-------------|
| **Writing Assistant** | Word/character/sentence/paragraph count, reading time, readability score, grammar checking (all on-device) |
| **Content Moderation** | Blocks URLs, phone numbers, email addresses in K-12 messages (COPPA) |

---

## 17. System Integration

| Feature | Description |
|---------|-------------|
| **Siri Shortcuts** | 4 App Intents: Check Assignments, Check Grades, Open Courses, Today's Schedule |
| **Deep Linking** | `wolfwhale://` scheme, 10 destinations, role validation, pre-auth storage |
| **Spotlight Search** | CoreSpotlight indexing of courses, assignments, quizzes |
| **Home Screen Widgets** | WidgetKit: Grades, Schedule, Assignments widgets with App Group data sharing |
| **Calendar Sync** | EventKit: dedicated "WolfWhale LMS" calendar, sync class schedule, duplicate detection |

---

## 18. Settings & Preferences

| Feature | Description |
|---------|-------------|
| **App Settings** | Account, security (biometric), appearance (light/dark/system), notifications, data/storage, legal, about, account deletion |
| **Language Settings** | English + French in-app switching (no restart), L10n key-based lookup with fallback chain |

---

## 19. Backend & Infrastructure

| Feature | Description |
|---------|-------------|
| **Supabase** | PostgreSQL + Auth + Realtime + Storage + Edge Functions, retry with exponential backoff, request deduplication |
| **Circuit Breaker** | 3-state pattern (closed/open/halfOpen), configurable threshold (5) + timeout (60s) |
| **Caching** | In-memory actor cache with per-entry TTL + LRU eviction; two-tier image cache (NSCache + disk, 200MB budget) |
| **Crash Reporting** | Error buffering (50 max), 5 severity levels, Supabase audit_logs flush |
| **Logging** | os.log structured logging (10 categories), network request/response logging (DEBUG only) |
| **Input Validation** | Text sanitization, email validation (RFC 5322), password strength requirements |
| **42+ Database Tables** | Multi-tenant with RLS, 308 policies, session-variable-optimized helper functions |

---

## Apple Frameworks Used (30)

SwiftUI, WidgetKit, ActivityKit, GroupActivities, CoreNFC, HealthKit, MusicKit, PencilKit, Vision, VisionKit, CallKit, MultipeerConnectivity, CoreSpotlight, EventKit, PassKit, LocalAuthentication, AVFoundation, Speech, CoreImage, CoreLocation, CloudKit, CryptoKit, Network, App Intents, UserNotifications, Security, PhotosUI, Charts, MediaPlayer, FoundationModels

---

## AI Integration

- **Apple FoundationModels** — On-device Apple Intelligence study assistant
- **CoreML** — Prepared for on-device ML learning recommendations

---

*Generated from codebase analysis — 355 Swift files, 122K lines of code*
*Last updated: February 2026*
