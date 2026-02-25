-- =============================================================================
-- WolfWhale LMS - Performance Indexes
-- =============================================================================
-- Creates indexes on frequently queried columns to improve query performance
-- across all tables. Matches the actual database schema.
--
-- KEY CHANGES from previous version:
--   - course_enrollments (not enrollments)
--   - attendance_records (not attendance), attendance_date (not date)
--   - conversation_members (not conversation_participants)
--   - student_parents (not parent_child_links), student_id (not child_id)
--   - courses.created_by (not teacher_id), courses.name (not title)
--   - announcements.created_by (not author_id)
--   - No lesson_completions, no school_id on profiles
--   - Added indexes for: student_xp, leaderboard_entries, notifications,
--     class_codes, xp_events, coin_transactions, audit_logs, quiz_options,
--     quiz_answers, message_read_receipts, rubrics, lesson_attachments,
--     consent_records, notification_preferences, tenant_memberships
--
-- Index naming convention: idx_{table}_{column(s)}
-- Using IF NOT EXISTS for idempotent migrations.
-- Run AFTER initial table creation.
-- =============================================================================


-- =============================================================================
-- SECTION 1: TENANT_MEMBERSHIPS (critical for RLS helper functions)
-- =============================================================================

-- Used by: get_user_role(), get_user_tenant_id() - called on every RLS check
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user_id
ON tenant_memberships(user_id);

CREATE INDEX IF NOT EXISTS idx_tenant_memberships_tenant_id
ON tenant_memberships(tenant_id);

-- Composite for the most common lookup: user's active membership
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user_status
ON tenant_memberships(user_id, status);

-- Composite for tenant + role queries (admin dashboards)
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_tenant_role
ON tenant_memberships(tenant_id, role);

-- Unique constraint for one membership per user per tenant
CREATE UNIQUE INDEX IF NOT EXISTS idx_tenant_memberships_tenant_user
ON tenant_memberships(tenant_id, user_id);


-- =============================================================================
-- SECTION 2: COURSE_ENROLLMENTS (most frequently joined table)
-- =============================================================================

-- Used by: student course lookups, teacher student lists, enrollment checks
CREATE INDEX IF NOT EXISTS idx_course_enrollments_student_id
ON course_enrollments(student_id);

CREATE INDEX IF NOT EXISTS idx_course_enrollments_course_id
ON course_enrollments(course_id);

-- Composite index for the extremely common (student_id, course_id) lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_course_enrollments_student_course
ON course_enrollments(student_id, course_id);

-- Used by: tenant-scoped enrollment queries
CREATE INDEX IF NOT EXISTS idx_course_enrollments_tenant_id
ON course_enrollments(tenant_id);

-- Used by: teacher looking up their enrollments
CREATE INDEX IF NOT EXISTS idx_course_enrollments_teacher_id
ON course_enrollments(teacher_id);


-- =============================================================================
-- SECTION 3: COURSES
-- =============================================================================

-- Used by: teacher's course list (courses.created_by not teacher_id)
CREATE INDEX IF NOT EXISTS idx_courses_created_by
ON courses(created_by);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_courses_tenant_id
ON courses(tenant_id);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_courses_status
ON courses(status);

-- Composite for tenant-scoped course lists
CREATE INDEX IF NOT EXISTS idx_courses_tenant_status
ON courses(tenant_id, status);

-- Composite for teacher's courses in a tenant
CREATE INDEX IF NOT EXISTS idx_courses_tenant_created_by
ON courses(tenant_id, created_by);


-- =============================================================================
-- SECTION 4: MODULES
-- =============================================================================

-- Used by: fetching modules for a course, ordered
CREATE INDEX IF NOT EXISTS idx_modules_course_id
ON modules(course_id);

CREATE INDEX IF NOT EXISTS idx_modules_course_order
ON modules(course_id, order_index);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_modules_tenant_id
ON modules(tenant_id);


-- =============================================================================
-- SECTION 5: LESSONS
-- =============================================================================

-- Used by: fetching lessons for a module, ordered
CREATE INDEX IF NOT EXISTS idx_lessons_module_id
ON lessons(module_id);

CREATE INDEX IF NOT EXISTS idx_lessons_module_order
ON lessons(module_id, order_index);

-- Used by: fetching lessons for a course directly
CREATE INDEX IF NOT EXISTS idx_lessons_course_id
ON lessons(course_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_lessons_tenant_id
ON lessons(tenant_id);


-- =============================================================================
-- SECTION 6: ASSIGNMENTS
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

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_assignments_tenant_id
ON assignments(tenant_id);

-- Used by: creator lookup
CREATE INDEX IF NOT EXISTS idx_assignments_created_by
ON assignments(created_by);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_assignments_status
ON assignments(status);


-- =============================================================================
-- SECTION 7: SUBMISSIONS
-- =============================================================================

-- Used by: student viewing their submissions
CREATE INDEX IF NOT EXISTS idx_submissions_student_id
ON submissions(student_id);

-- Used by: teacher viewing submissions per assignment
CREATE INDEX IF NOT EXISTS idx_submissions_assignment_id
ON submissions(assignment_id);

-- Composite for checking specific student's submission on an assignment
CREATE INDEX IF NOT EXISTS idx_submissions_assignment_student
ON submissions(assignment_id, student_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_submissions_tenant_id
ON submissions(tenant_id);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_submissions_status
ON submissions(status);


-- =============================================================================
-- SECTION 8: GRADES
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

-- Used by: linking grades to specific submissions
CREATE INDEX IF NOT EXISTS idx_grades_submission_id
ON grades(submission_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_grades_tenant_id
ON grades(tenant_id);


-- =============================================================================
-- SECTION 9: QUIZZES
-- =============================================================================

-- Used by: fetching quizzes per course
CREATE INDEX IF NOT EXISTS idx_quizzes_course_id
ON quizzes(course_id);

-- Used by: linking quiz to assignment
CREATE INDEX IF NOT EXISTS idx_quizzes_assignment_id
ON quizzes(assignment_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_quizzes_tenant_id
ON quizzes(tenant_id);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_quizzes_status
ON quizzes(status);


-- =============================================================================
-- SECTION 10: QUIZ_QUESTIONS
-- =============================================================================

-- Used by: fetching questions per quiz, ordered
CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_id
ON quiz_questions(quiz_id);

CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_order
ON quiz_questions(quiz_id, order_index);


-- =============================================================================
-- SECTION 11: QUIZ_OPTIONS
-- =============================================================================

-- Used by: fetching options per question, ordered
CREATE INDEX IF NOT EXISTS idx_quiz_options_question_id
ON quiz_options(question_id);

CREATE INDEX IF NOT EXISTS idx_quiz_options_question_order
ON quiz_options(question_id, order_index);


-- =============================================================================
-- SECTION 12: QUIZ_ATTEMPTS
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

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_tenant_id
ON quiz_attempts(tenant_id);


-- =============================================================================
-- SECTION 13: QUIZ_ANSWERS
-- =============================================================================

-- Used by: fetching answers per attempt
CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt_id
ON quiz_answers(attempt_id);

-- Used by: fetching answers per question
CREATE INDEX IF NOT EXISTS idx_quiz_answers_question_id
ON quiz_answers(question_id);

-- Composite for checking specific answer
CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt_question
ON quiz_answers(attempt_id, question_id);


-- =============================================================================
-- SECTION 14: ATTENDANCE_RECORDS
-- =============================================================================

-- Used by: student attendance history
CREATE INDEX IF NOT EXISTS idx_attendance_records_student_id
ON attendance_records(student_id);

-- Used by: course attendance records
CREATE INDEX IF NOT EXISTS idx_attendance_records_course_id
ON attendance_records(course_id);

-- Used by: date-based attendance queries (attendance_date, not date)
CREATE INDEX IF NOT EXISTS idx_attendance_records_attendance_date
ON attendance_records(attendance_date);

-- Composite for attendance by student and date (sorted)
CREATE INDEX IF NOT EXISTS idx_attendance_records_student_date
ON attendance_records(student_id, attendance_date DESC);

-- Composite for course attendance on a specific date
CREATE INDEX IF NOT EXISTS idx_attendance_records_course_date
ON attendance_records(course_id, attendance_date);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_attendance_records_tenant_id
ON attendance_records(tenant_id);


-- =============================================================================
-- SECTION 15: ANNOUNCEMENTS
-- =============================================================================

-- Used by: tenant-scoped announcement feeds
CREATE INDEX IF NOT EXISTS idx_announcements_tenant_id
ON announcements(tenant_id);

-- Used by: sorting by newest first
CREATE INDEX IF NOT EXISTS idx_announcements_created_at
ON announcements(created_at DESC);

-- Used by: author lookup (created_by, not author_id)
CREATE INDEX IF NOT EXISTS idx_announcements_created_by
ON announcements(created_by);

-- Composite for tenant-scoped sorted feed
CREATE INDEX IF NOT EXISTS idx_announcements_tenant_created
ON announcements(tenant_id, created_at DESC);

-- Used by: course-specific announcements
CREATE INDEX IF NOT EXISTS idx_announcements_course_id
ON announcements(course_id);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_announcements_status
ON announcements(status);


-- =============================================================================
-- SECTION 16: CONVERSATIONS & MESSAGING
-- =============================================================================

-- conversation_members (not conversation_participants)

-- Used by: finding a user's conversations
CREATE INDEX IF NOT EXISTS idx_conversation_members_user_id
ON conversation_members(user_id);

-- Used by: listing members in a conversation
CREATE INDEX IF NOT EXISTS idx_conversation_members_conversation_id
ON conversation_members(conversation_id);

-- Composite for efficient membership checks
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_members_conv_user
ON conversation_members(conversation_id, user_id);

-- Conversations: tenant isolation
CREATE INDEX IF NOT EXISTS idx_conversations_tenant_id
ON conversations(tenant_id);

-- Conversations: creator lookup
CREATE INDEX IF NOT EXISTS idx_conversations_created_by
ON conversations(created_by);

-- Conversations: course-specific conversations
CREATE INDEX IF NOT EXISTS idx_conversations_course_id
ON conversations(course_id);

-- Messages

-- Used by: fetching messages in a conversation, ordered
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
ON messages(conversation_id);

-- Composite for ordered message retrieval
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
ON messages(conversation_id, created_at);

-- Used by: finding messages sent by a specific user
CREATE INDEX IF NOT EXISTS idx_messages_sender_id
ON messages(sender_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_messages_tenant_id
ON messages(tenant_id);


-- =============================================================================
-- SECTION 17: MESSAGE_READ_RECEIPTS
-- =============================================================================

-- Used by: checking if a user read a message
CREATE INDEX IF NOT EXISTS idx_message_read_receipts_user_id
ON message_read_receipts(user_id);

CREATE INDEX IF NOT EXISTS idx_message_read_receipts_message_id
ON message_read_receipts(message_id);

-- Composite for efficient receipt lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_read_receipts_message_user
ON message_read_receipts(message_id, user_id);


-- =============================================================================
-- SECTION 18: ACHIEVEMENTS
-- =============================================================================

-- Used by: tenant-scoped achievement catalog
CREATE INDEX IF NOT EXISTS idx_achievements_tenant_id
ON achievements(tenant_id);

-- Used by: filtering global achievements
CREATE INDEX IF NOT EXISTS idx_achievements_is_global
ON achievements(is_global);

-- Used by: filtering by category
CREATE INDEX IF NOT EXISTS idx_achievements_category
ON achievements(category);


-- =============================================================================
-- SECTION 19: STUDENT_ACHIEVEMENTS
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

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_student_achievements_tenant_id
ON student_achievements(tenant_id);


-- =============================================================================
-- SECTION 20: STUDENT_PARENTS (not parent_child_links)
-- =============================================================================

-- Used by: parent fetching their children
CREATE INDEX IF NOT EXISTS idx_student_parents_parent_id
ON student_parents(parent_id);

-- Used by: finding a student's parent(s)
CREATE INDEX IF NOT EXISTS idx_student_parents_student_id
ON student_parents(student_id);

-- Composite for unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_parents_parent_student
ON student_parents(parent_id, student_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_student_parents_tenant_id
ON student_parents(tenant_id);


-- =============================================================================
-- SECTION 21: STUDENT_XP
-- =============================================================================

-- Used by: student XP lookups
CREATE INDEX IF NOT EXISTS idx_student_xp_student_id
ON student_xp(student_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_student_xp_tenant_id
ON student_xp(tenant_id);

-- Used by: leaderboard sorting
CREATE INDEX IF NOT EXISTS idx_student_xp_total_xp
ON student_xp(total_xp DESC);

-- Composite for tenant-scoped leaderboard
CREATE INDEX IF NOT EXISTS idx_student_xp_tenant_total_xp
ON student_xp(tenant_id, total_xp DESC);

-- Used by: streak tracking
CREATE INDEX IF NOT EXISTS idx_student_xp_last_login_date
ON student_xp(last_login_date);

-- Unique: one XP record per student per tenant
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_xp_tenant_student
ON student_xp(tenant_id, student_id);


-- =============================================================================
-- SECTION 22: LEADERBOARD_ENTRIES
-- =============================================================================

-- Used by: tenant-scoped leaderboard queries
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_tenant_id
ON leaderboard_entries(tenant_id);

-- Used by: user's leaderboard position
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_user_id
ON leaderboard_entries(user_id);

-- Used by: filtering by scope (global, course, etc.)
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_scope
ON leaderboard_entries(scope);

-- Used by: filtering by period
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_period
ON leaderboard_entries(period);

-- Composite for ranked leaderboard retrieval
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_tenant_scope_period_rank
ON leaderboard_entries(tenant_id, scope, scope_id, period, rank);

-- Composite for user position lookup
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_user_scope_period
ON leaderboard_entries(user_id, scope, period);


-- =============================================================================
-- SECTION 23: NOTIFICATIONS
-- =============================================================================

-- Used by: user notification feed
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
ON notifications(user_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id
ON notifications(tenant_id);

-- Used by: filtering unread notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_read
ON notifications(user_id, read);

-- Composite for sorted notification feed
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
ON notifications(user_id, created_at DESC);

-- Used by: notification type filtering
CREATE INDEX IF NOT EXISTS idx_notifications_type
ON notifications(type);

-- Used by: linking notifications to specific resources
CREATE INDEX IF NOT EXISTS idx_notifications_course_id
ON notifications(course_id);

CREATE INDEX IF NOT EXISTS idx_notifications_assignment_id
ON notifications(assignment_id);


-- =============================================================================
-- SECTION 24: NOTIFICATION_PREFERENCES
-- =============================================================================

-- Used by: user preference lookup
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id
ON notification_preferences(user_id);

-- Composite for user + tenant preferences
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_tenant
ON notification_preferences(user_id, tenant_id);


-- =============================================================================
-- SECTION 25: CLASS_CODES
-- =============================================================================

-- Used by: code lookup during enrollment
CREATE UNIQUE INDEX IF NOT EXISTS idx_class_codes_code
ON class_codes(code);

-- Used by: course-specific code management
CREATE INDEX IF NOT EXISTS idx_class_codes_course_id
ON class_codes(course_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_class_codes_tenant_id
ON class_codes(tenant_id);

-- Used by: filtering active codes
CREATE INDEX IF NOT EXISTS idx_class_codes_is_active
ON class_codes(is_active);

-- Composite for active codes per course
CREATE INDEX IF NOT EXISTS idx_class_codes_course_active
ON class_codes(course_id, is_active);


-- =============================================================================
-- SECTION 26: COIN_TRANSACTIONS
-- =============================================================================

-- Used by: student transaction history
CREATE INDEX IF NOT EXISTS idx_coin_transactions_student_id
ON coin_transactions(student_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_coin_transactions_tenant_id
ON coin_transactions(tenant_id);

-- Used by: filtering by transaction type
CREATE INDEX IF NOT EXISTS idx_coin_transactions_transaction_type
ON coin_transactions(transaction_type);

-- Composite for sorted transaction history
CREATE INDEX IF NOT EXISTS idx_coin_transactions_student_created
ON coin_transactions(student_id, created_at DESC);

-- Used by: source tracking
CREATE INDEX IF NOT EXISTS idx_coin_transactions_source
ON coin_transactions(source_type, source_id);


-- =============================================================================
-- SECTION 27: XP_EVENTS
-- =============================================================================

-- Used by: user XP event history
CREATE INDEX IF NOT EXISTS idx_xp_events_user_id
ON xp_events(user_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_xp_events_tenant_id
ON xp_events(tenant_id);

-- Used by: filtering by event type
CREATE INDEX IF NOT EXISTS idx_xp_events_event_type
ON xp_events(event_type);

-- Composite for sorted event history
CREATE INDEX IF NOT EXISTS idx_xp_events_user_created
ON xp_events(user_id, created_at DESC);

-- Used by: course-specific XP tracking
CREATE INDEX IF NOT EXISTS idx_xp_events_course_id
ON xp_events(course_id);

-- Used by: source tracking
CREATE INDEX IF NOT EXISTS idx_xp_events_source
ON xp_events(source_type, source_id);


-- =============================================================================
-- SECTION 28: AUDIT_LOGS
-- =============================================================================

-- Used by: tenant-scoped audit trail
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id
ON audit_logs(tenant_id);

-- Used by: user activity tracking
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id
ON audit_logs(user_id);

-- Used by: filtering by action type
CREATE INDEX IF NOT EXISTS idx_audit_logs_action
ON audit_logs(action);

-- Used by: resource tracking
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource
ON audit_logs(resource_type, resource_id);

-- Composite for sorted audit trail
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_created
ON audit_logs(tenant_id, created_at DESC);

-- Used by: target user tracking
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_user_id
ON audit_logs(target_user_id);

-- Composite for user-specific audit trail
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created
ON audit_logs(user_id, created_at DESC);


-- =============================================================================
-- SECTION 29: RUBRICS
-- =============================================================================

-- Used by: fetching rubrics per assignment
CREATE INDEX IF NOT EXISTS idx_rubrics_assignment_id
ON rubrics(assignment_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_rubrics_tenant_id
ON rubrics(tenant_id);

-- Used by: creator lookup
CREATE INDEX IF NOT EXISTS idx_rubrics_created_by
ON rubrics(created_by);


-- =============================================================================
-- SECTION 30: LESSON_ATTACHMENTS
-- =============================================================================

-- Used by: fetching attachments per lesson
CREATE INDEX IF NOT EXISTS idx_lesson_attachments_lesson_id
ON lesson_attachments(lesson_id);

-- Composite for ordered attachment retrieval
CREATE INDEX IF NOT EXISTS idx_lesson_attachments_lesson_order
ON lesson_attachments(lesson_id, order_index);


-- =============================================================================
-- SECTION 31: CONSENT_RECORDS
-- =============================================================================

-- Used by: parent consent lookup
CREATE INDEX IF NOT EXISTS idx_consent_records_parent_id
ON consent_records(parent_id);

-- Used by: student consent status
CREATE INDEX IF NOT EXISTS idx_consent_records_student_id
ON consent_records(student_id);

-- Used by: tenant isolation
CREATE INDEX IF NOT EXISTS idx_consent_records_tenant_id
ON consent_records(tenant_id);

-- Composite for parent-student consent lookup
CREATE INDEX IF NOT EXISTS idx_consent_records_parent_student
ON consent_records(parent_id, student_id);


-- =============================================================================
-- SECTION 32: PROFILES
-- =============================================================================
-- No school_id or role on profiles (those are in tenant_memberships)

-- Used by: updated_at sorting for recent activity
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at
ON profiles(updated_at DESC);


-- =============================================================================
-- SECTION 33: TENANTS
-- =============================================================================

-- Used by: slug-based tenant lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_tenants_slug
ON tenants(slug);

-- Used by: filtering by status
CREATE INDEX IF NOT EXISTS idx_tenants_status
ON tenants(status);


-- =============================================================================
-- END OF INDEXES
-- =============================================================================
