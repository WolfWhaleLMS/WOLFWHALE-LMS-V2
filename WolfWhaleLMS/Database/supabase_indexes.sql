-- =============================================================================
-- WolfWhale LMS - Performance Indexes
-- =============================================================================
-- Creates indexes on frequently queried columns to improve query performance
-- across all major tables. Run AFTER initial table creation.
--
-- Index naming convention: idx_{table}_{column(s)}
-- Using IF NOT EXISTS for idempotent migrations.
-- =============================================================================

-- =============================================================================
-- SECTION 1: Enrollments (most frequently joined table)
-- =============================================================================

-- Used by: student course lookups, teacher student lists, enrollment checks
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id
ON enrollments(student_id);

CREATE INDEX IF NOT EXISTS idx_enrollments_course_id
ON enrollments(course_id);

-- Composite index for the extremely common (student_id, course_id) lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_student_course
ON enrollments(student_id, course_id);

-- =============================================================================
-- SECTION 2: Courses
-- =============================================================================

-- Used by: teacher's course list, tenant isolation
CREATE INDEX IF NOT EXISTS idx_courses_teacher_id
ON courses(teacher_id);

CREATE INDEX IF NOT EXISTS idx_courses_tenant_id
ON courses(tenant_id);

-- Used by: class code enrollment lookup
CREATE INDEX IF NOT EXISTS idx_courses_class_code
ON courses(class_code);

-- =============================================================================
-- SECTION 3: Modules
-- =============================================================================

-- Used by: fetching modules for a course, ordered
CREATE INDEX IF NOT EXISTS idx_modules_course_id
ON modules(course_id);

CREATE INDEX IF NOT EXISTS idx_modules_course_order
ON modules(course_id, order_index);

-- =============================================================================
-- SECTION 4: Lessons
-- =============================================================================

-- Used by: fetching lessons for a module, ordered
CREATE INDEX IF NOT EXISTS idx_lessons_module_id
ON lessons(module_id);

CREATE INDEX IF NOT EXISTS idx_lessons_module_order
ON lessons(module_id, order_index);

-- =============================================================================
-- SECTION 5: Lesson Completions
-- =============================================================================

-- Used by: tracking student progress
CREATE INDEX IF NOT EXISTS idx_lesson_completions_student_id
ON lesson_completions(student_id);

CREATE INDEX IF NOT EXISTS idx_lesson_completions_lesson_id
ON lesson_completions(lesson_id);

-- Composite for checking if a specific student completed a specific lesson
CREATE UNIQUE INDEX IF NOT EXISTS idx_lesson_completions_student_lesson
ON lesson_completions(student_id, lesson_id);

-- =============================================================================
-- SECTION 6: Assignments
-- =============================================================================

-- Used by: fetching assignments per course
CREATE INDEX IF NOT EXISTS idx_assignments_course_id
ON assignments(course_id);

-- Used by: sorting assignments by due date
CREATE INDEX IF NOT EXISTS idx_assignments_due_date
ON assignments(due_date);

-- Composite for filtered + sorted queries
CREATE INDEX IF NOT EXISTS idx_assignments_course_due
ON assignments(course_id, due_date);

-- =============================================================================
-- SECTION 7: Submissions
-- =============================================================================

-- Used by: student viewing their submissions
CREATE INDEX IF NOT EXISTS idx_submissions_student_id
ON submissions(student_id);

-- Used by: teacher viewing submissions per assignment
CREATE INDEX IF NOT EXISTS idx_submissions_assignment_id
ON submissions(assignment_id);

-- Composite for checking specific student's submission on an assignment
CREATE UNIQUE INDEX IF NOT EXISTS idx_submissions_assignment_student
ON submissions(assignment_id, student_id);

-- =============================================================================
-- SECTION 8: Grades
-- =============================================================================

-- Used by: student grade lookups
CREATE INDEX IF NOT EXISTS idx_grades_student_id
ON grades(student_id);

-- Used by: course-level grade reports
CREATE INDEX IF NOT EXISTS idx_grades_course_id
ON grades(course_id);

-- Composite for student grades in a specific course
CREATE INDEX IF NOT EXISTS idx_grades_student_course
ON grades(student_id, course_id);

-- Used by: linking grades to specific assignments
CREATE INDEX IF NOT EXISTS idx_grades_assignment_id
ON grades(assignment_id);

-- =============================================================================
-- SECTION 9: Quizzes
-- =============================================================================

-- Used by: fetching quizzes per course
CREATE INDEX IF NOT EXISTS idx_quizzes_course_id
ON quizzes(course_id);

-- Used by: sorting quizzes by due date
CREATE INDEX IF NOT EXISTS idx_quizzes_due_date
ON quizzes(due_date);

-- =============================================================================
-- SECTION 10: Quiz Questions
-- =============================================================================

-- Used by: fetching questions per quiz
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_id
ON quiz_questions(quiz_id);

-- =============================================================================
-- SECTION 11: Quiz Attempts
-- =============================================================================

-- Used by: student viewing their attempts
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_student_id
ON quiz_attempts(student_id);

-- Used by: viewing attempts per quiz
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_id
ON quiz_attempts(quiz_id);

-- Composite for checking if student attempted a specific quiz
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_student
ON quiz_attempts(quiz_id, student_id);

-- =============================================================================
-- SECTION 12: Attendance
-- =============================================================================

-- Used by: student attendance history
CREATE INDEX IF NOT EXISTS idx_attendance_student_id
ON attendance(student_id);

-- Used by: course attendance records
CREATE INDEX IF NOT EXISTS idx_attendance_course_id
ON attendance(course_id);

-- Used by: date-based attendance queries
CREATE INDEX IF NOT EXISTS idx_attendance_date
ON attendance(date);

-- Composite for attendance by student and date (sorted)
CREATE INDEX IF NOT EXISTS idx_attendance_student_date
ON attendance(student_id, date DESC);

-- Composite for course attendance on a specific date
CREATE INDEX IF NOT EXISTS idx_attendance_course_date
ON attendance(course_id, date);

-- =============================================================================
-- SECTION 13: Announcements
-- =============================================================================

-- Used by: tenant-scoped announcement feeds
CREATE INDEX IF NOT EXISTS idx_announcements_tenant_id
ON announcements(tenant_id);

-- Used by: sorting by newest first
CREATE INDEX IF NOT EXISTS idx_announcements_created_at
ON announcements(created_at DESC);

-- Used by: author lookup
CREATE INDEX IF NOT EXISTS idx_announcements_author_id
ON announcements(author_id);

-- Composite for tenant-scoped sorted feed
CREATE INDEX IF NOT EXISTS idx_announcements_tenant_created
ON announcements(tenant_id, created_at DESC);

-- =============================================================================
-- SECTION 14: Conversations & Messaging
-- =============================================================================

-- Used by: finding a user's conversations
CREATE INDEX IF NOT EXISTS idx_conversation_participants_user_id
ON conversation_participants(user_id);

-- Used by: listing participants in a conversation
CREATE INDEX IF NOT EXISTS idx_conversation_participants_conversation_id
ON conversation_participants(conversation_id);

-- Composite for efficient participant membership checks
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_participants_conv_user
ON conversation_participants(conversation_id, user_id);

-- Used by: fetching messages in a conversation, ordered
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
ON messages(conversation_id);

-- Composite for ordered message retrieval
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
ON messages(conversation_id, created_at);

-- Used by: finding messages sent by a specific user
CREATE INDEX IF NOT EXISTS idx_messages_sender_id
ON messages(sender_id);

-- =============================================================================
-- SECTION 15: Achievements
-- =============================================================================

-- Used by: listing unlocked achievements for a student
CREATE INDEX IF NOT EXISTS idx_student_achievements_student_id
ON student_achievements(student_id);

-- Used by: checking if specific achievement is unlocked
CREATE INDEX IF NOT EXISTS idx_student_achievements_achievement_id
ON student_achievements(achievement_id);

-- Composite for efficient lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_achievements_student_achievement
ON student_achievements(student_id, achievement_id);

-- =============================================================================
-- SECTION 16: Parent-Child Links
-- =============================================================================

-- Used by: parent fetching their children
CREATE INDEX IF NOT EXISTS idx_parent_child_links_parent_id
ON parent_child_links(parent_id);

-- Used by: finding a child's parent(s)
CREATE INDEX IF NOT EXISTS idx_parent_child_links_child_id
ON parent_child_links(child_id);

-- Composite for unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_child_links_parent_child
ON parent_child_links(parent_id, child_id);

-- =============================================================================
-- SECTION 17: Profiles
-- =============================================================================

-- Used by: school-scoped admin queries
CREATE INDEX IF NOT EXISTS idx_profiles_school_id
ON profiles(school_id);

-- Used by: role-based filtering (leaderboard, admin dashboard)
CREATE INDEX IF NOT EXISTS idx_profiles_role
ON profiles(role);

-- Used by: leaderboard sorting
CREATE INDEX IF NOT EXISTS idx_profiles_xp
ON profiles(xp DESC);

-- Composite for school-scoped role queries
CREATE INDEX IF NOT EXISTS idx_profiles_school_role
ON profiles(school_id, role);

-- =============================================================================
-- END OF INDEXES
-- =============================================================================
