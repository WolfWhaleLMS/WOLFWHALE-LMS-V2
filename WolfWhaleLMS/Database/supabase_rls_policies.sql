-- =============================================================================
-- WolfWhale LMS - Row Level Security Policies
-- =============================================================================
-- Complete rewrite to match actual database schema.
--
-- KEY DESIGN DECISIONS:
--   - Roles come from tenant_memberships.role (NOT profiles.role)
--   - Tenant/school scoping via tenant_id on most tables
--   - Roles are lowercase: 'student', 'teacher', 'admin', 'parent'
--   - Table names: course_enrollments, attendance_records, student_parents,
--     conversation_members, etc.
--   - Courses use created_by (not teacher_id) and name (not title)
--   - Announcements use created_by (not author_id)
--   - No lesson_completions table; progress via student_course_progress view
--
-- Run AFTER all tables have been created.
-- =============================================================================


-- =============================================================================
-- SECTION 1: Helper Functions
-- =============================================================================

-- Get user's role (from tenant_memberships)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text AS $$
    SELECT role FROM tenant_memberships
    WHERE user_id = auth.uid()
      AND status = 'active'
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Get user's tenant_id (from tenant_memberships)
CREATE OR REPLACE FUNCTION public.get_user_tenant_id()
RETURNS uuid AS $$
    SELECT tenant_id FROM tenant_memberships
    WHERE user_id = auth.uid()
      AND status = 'active'
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Check if user is enrolled in a course
CREATE OR REPLACE FUNCTION public.is_enrolled_in_course(p_user_id uuid, p_course_id uuid)
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1 FROM course_enrollments
        WHERE student_id = p_user_id AND course_id = p_course_id
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Check if user is the teacher/creator of a course
CREATE OR REPLACE FUNCTION public.is_course_teacher(p_user_id uuid, p_course_id uuid)
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1 FROM courses
        WHERE id = p_course_id AND created_by = p_user_id
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Check if user is a parent of a student
CREATE OR REPLACE FUNCTION public.is_parent_of(p_parent_id uuid, p_child_id uuid)
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1 FROM student_parents
        WHERE parent_id = p_parent_id AND student_id = p_child_id
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Get all course IDs a parent's children are enrolled in
CREATE OR REPLACE FUNCTION public.get_parent_child_course_ids(p_parent_id uuid)
RETURNS SETOF uuid AS $$
    SELECT DISTINCT ce.course_id
    FROM student_parents sp
    JOIN course_enrollments ce ON ce.student_id = sp.student_id
    WHERE sp.parent_id = p_parent_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Get all student IDs for a parent
CREATE OR REPLACE FUNCTION public.get_parent_child_ids(p_parent_id uuid)
RETURNS SETOF uuid AS $$
    SELECT student_id FROM student_parents
    WHERE parent_id = p_parent_id;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- Check if user has access to a course (teacher, enrolled student, admin same tenant, or parent)
CREATE OR REPLACE FUNCTION public.has_course_access(p_user_id uuid, p_course_id uuid)
RETURNS boolean AS $$
    SELECT (
        is_course_teacher(p_user_id, p_course_id)
        OR is_enrolled_in_course(p_user_id, p_course_id)
        OR get_user_role() = 'admin'
        OR (get_user_role() = 'parent' AND p_course_id IN (SELECT get_parent_child_course_ids(p_user_id)))
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;


-- =============================================================================
-- SECTION 2: Enable RLS on ALL tables
-- =============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_read_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_xp ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;


-- =============================================================================
-- SECTION 3: Drop existing policies (idempotent migration)
-- =============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
            'profiles', 'tenant_memberships', 'tenants',
            'courses', 'modules', 'lessons',
            'course_enrollments', 'assignments', 'submissions', 'grades',
            'quizzes', 'quiz_questions', 'quiz_options', 'quiz_attempts', 'quiz_answers',
            'attendance_records', 'announcements',
            'conversations', 'conversation_members', 'messages', 'message_read_receipts',
            'achievements', 'student_achievements', 'student_parents',
            'student_xp', 'leaderboard_entries',
            'notifications', 'notification_preferences',
            'class_codes', 'coin_transactions', 'xp_events',
            'audit_logs', 'rubrics', 'lesson_attachments', 'consent_records'
          )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
    END LOOP;
END $$;


-- =============================================================================
-- SECTION 4: PROFILES
-- =============================================================================
-- Users can read/update their own profile.
-- Admins can read all profiles in their tenant.
-- Teachers can read profiles of students enrolled in their courses.
-- Parents can read their linked children's profiles.
-- Same-tenant users can see basic profile info (leaderboard).

-- SELECT: Users can always read their own profile
CREATE POLICY "profiles_select_own"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- SELECT: Admins can read all profiles in their tenant
CREATE POLICY "profiles_select_admin_tenant"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND EXISTS (
        SELECT 1 FROM tenant_memberships tm
        WHERE tm.user_id = profiles.id
          AND tm.tenant_id = get_user_tenant_id()
    )
);

-- SELECT: Teachers can read profiles of students enrolled in their courses
CREATE POLICY "profiles_select_teacher_students"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM course_enrollments ce
        JOIN courses c ON c.id = ce.course_id
        WHERE ce.student_id = profiles.id
          AND c.created_by = auth.uid()
    )
);

-- SELECT: Parents can read their children's profiles
CREATE POLICY "profiles_select_parent_children"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), profiles.id)
);

-- SELECT: Same-tenant users can see profiles for leaderboard
CREATE POLICY "profiles_select_tenant_leaderboard"
ON profiles FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM tenant_memberships tm
        WHERE tm.user_id = profiles.id
          AND tm.tenant_id = get_user_tenant_id()
    )
);

-- UPDATE: Users can update their own profile only
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- INSERT: New user inserts their own profile (on signup)
CREATE POLICY "profiles_insert_own"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- DELETE: Admins can delete profiles in their tenant (not themselves)
CREATE POLICY "profiles_delete_admin"
ON profiles FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND id != auth.uid()
    AND EXISTS (
        SELECT 1 FROM tenant_memberships tm
        WHERE tm.user_id = profiles.id
          AND tm.tenant_id = get_user_tenant_id()
    )
);


-- =============================================================================
-- SECTION 5: TENANT_MEMBERSHIPS
-- =============================================================================
-- Users can read their own memberships.
-- Admins can CRUD memberships within their tenant.

-- SELECT: Users can read their own memberships
CREATE POLICY "tenant_memberships_select_own"
ON tenant_memberships FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- SELECT: Admins can read all memberships in their tenant
CREATE POLICY "tenant_memberships_select_admin"
ON tenant_memberships FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create memberships in their tenant
CREATE POLICY "tenant_memberships_insert_admin"
ON tenant_memberships FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Admins can update memberships in their tenant
CREATE POLICY "tenant_memberships_update_admin"
ON tenant_memberships FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Admins can remove memberships in their tenant
CREATE POLICY "tenant_memberships_delete_admin"
ON tenant_memberships FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 6: TENANTS
-- =============================================================================
-- Users can read their own tenant.
-- Admins can update their tenant.

-- SELECT: Users can read their own tenant
CREATE POLICY "tenants_select_own"
ON tenants FOR SELECT
TO authenticated
USING (id = get_user_tenant_id());

-- UPDATE: Admins can update their own tenant
CREATE POLICY "tenants_update_admin"
ON tenants FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 7: COURSES
-- =============================================================================
-- Teachers can CRUD their own courses (created_by).
-- Students can read courses they are enrolled in.
-- Admins can CRUD courses within their tenant.
-- Parents can read courses their children are enrolled in.

-- SELECT: Teachers can read their own courses
CREATE POLICY "courses_select_teacher_own"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
);

-- SELECT: Students can read courses they are enrolled in
CREATE POLICY "courses_select_student_enrolled"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'student'
    AND is_enrolled_in_course(auth.uid(), courses.id)
);

-- SELECT: Admins can read courses in their tenant
CREATE POLICY "courses_select_admin"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read courses their children are enrolled in
CREATE POLICY "courses_select_parent_children"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND courses.id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create courses in their tenant
CREATE POLICY "courses_insert_teacher"
ON courses FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create courses in their tenant
CREATE POLICY "courses_insert_admin"
ON courses FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update their own courses
CREATE POLICY "courses_update_teacher_own"
ON courses FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
)
WITH CHECK (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
);

-- UPDATE: Admins can update courses in their tenant
CREATE POLICY "courses_update_admin"
ON courses FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Teachers can delete their own courses
CREATE POLICY "courses_delete_teacher_own"
ON courses FOR DELETE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
);

-- DELETE: Admins can delete courses in their tenant
CREATE POLICY "courses_delete_admin"
ON courses FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 8: MODULES
-- =============================================================================
-- Follow course access: if you can see the course, you can see its modules.
-- Teachers who created the course can CRUD. Admins can CRUD within tenant.

-- SELECT: Anyone with course access can read modules
CREATE POLICY "modules_select_course_access"
ON modules FOR SELECT
TO authenticated
USING (
    is_course_teacher(auth.uid(), course_id)
    OR is_enrolled_in_course(auth.uid(), course_id)
    OR (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
    OR (get_user_role() = 'parent' AND course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
);

-- INSERT: Teachers can create modules for their own courses
CREATE POLICY "modules_insert_teacher"
ON modules FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create modules in their tenant
CREATE POLICY "modules_insert_admin"
ON modules FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update modules for their own courses
CREATE POLICY "modules_update_teacher"
ON modules FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Admins can update modules in their tenant
CREATE POLICY "modules_update_admin"
ON modules FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can delete modules for their own courses
CREATE POLICY "modules_delete_teacher"
ON modules FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- DELETE: Admins can delete modules in their tenant
CREATE POLICY "modules_delete_admin"
ON modules FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 9: LESSONS
-- =============================================================================
-- Lessons have both course_id and module_id. Use course_id for access checks.
-- Teachers who created the course can CRUD.

-- SELECT: Anyone with course access can read lessons
CREATE POLICY "lessons_select_course_access"
ON lessons FOR SELECT
TO authenticated
USING (
    is_course_teacher(auth.uid(), course_id)
    OR is_enrolled_in_course(auth.uid(), course_id)
    OR (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
    OR (get_user_role() = 'parent' AND course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
);

-- INSERT: Teachers can create lessons for their courses
CREATE POLICY "lessons_insert_teacher"
ON lessons FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create lessons in their tenant
CREATE POLICY "lessons_insert_admin"
ON lessons FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update lessons for their courses
CREATE POLICY "lessons_update_teacher"
ON lessons FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Admins can update lessons in their tenant
CREATE POLICY "lessons_update_admin"
ON lessons FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can delete lessons for their courses
CREATE POLICY "lessons_delete_teacher"
ON lessons FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- DELETE: Admins can delete lessons in their tenant
CREATE POLICY "lessons_delete_admin"
ON lessons FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 10: COURSE_ENROLLMENTS
-- =============================================================================
-- Students can read their own enrollments.
-- Teachers can read enrollments for courses they teach.
-- Admins can CRUD all enrollments in their tenant.
-- Parents can read their children's enrollments.

-- SELECT: Students can read their own enrollments
CREATE POLICY "course_enrollments_select_student_own"
ON course_enrollments FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read enrollments for courses they teach
CREATE POLICY "course_enrollments_select_teacher"
ON course_enrollments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- SELECT: Admins can read all enrollments in their tenant
CREATE POLICY "course_enrollments_select_admin"
ON course_enrollments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's enrollments
CREATE POLICY "course_enrollments_select_parent"
ON course_enrollments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can enroll themselves (e.g., via class code)
CREATE POLICY "course_enrollments_insert_student_self"
ON course_enrollments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'student'
    AND student_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Teachers can enroll students into their courses
CREATE POLICY "course_enrollments_insert_teacher"
ON course_enrollments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'teacher'
    AND is_course_teacher(auth.uid(), course_id)
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create enrollments in their tenant
CREATE POLICY "course_enrollments_insert_admin"
ON course_enrollments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update enrollments for their courses (grade_letter, status, etc.)
CREATE POLICY "course_enrollments_update_teacher"
ON course_enrollments FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND is_course_teacher(auth.uid(), course_id)
)
WITH CHECK (
    get_user_role() = 'teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- UPDATE: Admins can update enrollments in their tenant
CREATE POLICY "course_enrollments_update_admin"
ON course_enrollments FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can unenroll students from their courses
CREATE POLICY "course_enrollments_delete_teacher"
ON course_enrollments FOR DELETE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- DELETE: Admins can remove enrollments in their tenant
CREATE POLICY "course_enrollments_delete_admin"
ON course_enrollments FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 11: ASSIGNMENTS
-- =============================================================================
-- Follow course access for reading.
-- Teachers who created the course can CRUD.

-- SELECT: Students can read assignments for courses they are enrolled in
CREATE POLICY "assignments_select_student_enrolled"
ON assignments FOR SELECT
TO authenticated
USING (is_enrolled_in_course(auth.uid(), course_id));

-- SELECT: Teachers can read assignments for their courses
CREATE POLICY "assignments_select_teacher"
ON assignments FOR SELECT
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- SELECT: Admins can read all assignments in their tenant
CREATE POLICY "assignments_select_admin"
ON assignments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read assignments for their children's courses
CREATE POLICY "assignments_select_parent"
ON assignments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND course_id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create assignments for their courses
CREATE POLICY "assignments_insert_teacher"
ON assignments FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create assignments in their tenant
CREATE POLICY "assignments_insert_admin"
ON assignments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update assignments for their courses
CREATE POLICY "assignments_update_teacher"
ON assignments FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Admins can update assignments in their tenant
CREATE POLICY "assignments_update_admin"
ON assignments FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can delete assignments for their courses
CREATE POLICY "assignments_delete_teacher"
ON assignments FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- DELETE: Admins can delete assignments in their tenant
CREATE POLICY "assignments_delete_admin"
ON assignments FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 12: SUBMISSIONS
-- =============================================================================
-- Students can create/read their own submissions.
-- Teachers can read/update submissions for their courses.
-- Admins can read all submissions in their tenant.
-- Parents can read their children's submissions.

-- SELECT: Students can read their own submissions
CREATE POLICY "submissions_select_student_own"
ON submissions FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read submissions for assignments in their courses
CREATE POLICY "submissions_select_teacher"
ON submissions FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = submissions.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
);

-- SELECT: Admins can read all submissions in their tenant
CREATE POLICY "submissions_select_admin"
ON submissions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's submissions
CREATE POLICY "submissions_select_parent"
ON submissions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can submit their own work
CREATE POLICY "submissions_insert_student"
ON submissions FOR INSERT
TO authenticated
WITH CHECK (
    student_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Students can update their own submissions (resubmit)
CREATE POLICY "submissions_update_student_own"
ON submissions FOR UPDATE
TO authenticated
USING (student_id = auth.uid())
WITH CHECK (student_id = auth.uid());

-- UPDATE: Teachers can update submissions (grading) for their courses
CREATE POLICY "submissions_update_teacher"
ON submissions FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = submissions.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = submissions.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
);


-- =============================================================================
-- SECTION 13: GRADES
-- =============================================================================
-- Students can read their own grades.
-- Teachers can CRUD grades for their courses.
-- Admins can read grades in their tenant.
-- Parents can read their children's grades.

-- SELECT: Students can read their own grades
CREATE POLICY "grades_select_student_own"
ON grades FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read grades for courses they teach
CREATE POLICY "grades_select_teacher"
ON grades FOR SELECT
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- SELECT: Admins can read all grades in their tenant
CREATE POLICY "grades_select_admin"
ON grades FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's grades
CREATE POLICY "grades_select_parent"
ON grades FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Teachers can create grades for courses they teach
CREATE POLICY "grades_insert_teacher"
ON grades FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND graded_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update grades for courses they teach
CREATE POLICY "grades_update_teacher"
ON grades FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- DELETE: Teachers can delete grades for courses they teach
CREATE POLICY "grades_delete_teacher"
ON grades FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));


-- =============================================================================
-- SECTION 14: QUIZZES
-- =============================================================================
-- Follow course access for reading.
-- Teachers who created the course can CRUD.

-- SELECT: Students can read quizzes for courses they are enrolled in
CREATE POLICY "quizzes_select_student_enrolled"
ON quizzes FOR SELECT
TO authenticated
USING (is_enrolled_in_course(auth.uid(), course_id));

-- SELECT: Teachers can read quizzes for their courses
CREATE POLICY "quizzes_select_teacher"
ON quizzes FOR SELECT
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- SELECT: Admins can read all quizzes in their tenant
CREATE POLICY "quizzes_select_admin"
ON quizzes FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read quizzes in their children's courses
CREATE POLICY "quizzes_select_parent"
ON quizzes FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND course_id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create quizzes for their courses
CREATE POLICY "quizzes_insert_teacher"
ON quizzes FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update quizzes for their courses
CREATE POLICY "quizzes_update_teacher"
ON quizzes FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- DELETE: Teachers can delete quizzes for their courses
CREATE POLICY "quizzes_delete_teacher"
ON quizzes FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));


-- =============================================================================
-- SECTION 15: QUIZ_QUESTIONS
-- =============================================================================
-- Follow quiz -> course access chain for reading.
-- Teachers who own the course can CRUD.

-- SELECT: Anyone who can access the quiz's course can read questions
CREATE POLICY "quiz_questions_select_course_access"
ON quiz_questions FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_questions.quiz_id
        AND (
            is_course_teacher(auth.uid(), q.course_id)
            OR is_enrolled_in_course(auth.uid(), q.course_id)
            OR (get_user_role() = 'admin')
        )
    )
);

-- INSERT: Teachers can create questions for quizzes in their courses
CREATE POLICY "quiz_questions_insert_teacher"
ON quiz_questions FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_questions.quiz_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- UPDATE: Teachers can update questions for quizzes in their courses
CREATE POLICY "quiz_questions_update_teacher"
ON quiz_questions FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_questions.quiz_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_questions.quiz_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- DELETE: Teachers can delete questions for quizzes in their courses
CREATE POLICY "quiz_questions_delete_teacher"
ON quiz_questions FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_questions.quiz_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);


-- =============================================================================
-- SECTION 16: QUIZ_OPTIONS
-- =============================================================================
-- Follow quiz_question -> quiz -> course access chain.
-- Teachers who own the course can CRUD.

-- SELECT: Anyone who can access the quiz can read options
CREATE POLICY "quiz_options_select_course_access"
ON quiz_options FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_questions qq
        JOIN quizzes q ON q.id = qq.quiz_id
        WHERE qq.id = quiz_options.question_id
        AND (
            is_course_teacher(auth.uid(), q.course_id)
            OR is_enrolled_in_course(auth.uid(), q.course_id)
            OR (get_user_role() = 'admin')
        )
    )
);

-- INSERT: Teachers can create options for questions in their course quizzes
CREATE POLICY "quiz_options_insert_teacher"
ON quiz_options FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM quiz_questions qq
        JOIN quizzes q ON q.id = qq.quiz_id
        WHERE qq.id = quiz_options.question_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- UPDATE: Teachers can update options
CREATE POLICY "quiz_options_update_teacher"
ON quiz_options FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_questions qq
        JOIN quizzes q ON q.id = qq.quiz_id
        WHERE qq.id = quiz_options.question_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM quiz_questions qq
        JOIN quizzes q ON q.id = qq.quiz_id
        WHERE qq.id = quiz_options.question_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- DELETE: Teachers can delete options
CREATE POLICY "quiz_options_delete_teacher"
ON quiz_options FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_questions qq
        JOIN quizzes q ON q.id = qq.quiz_id
        WHERE qq.id = quiz_options.question_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);


-- =============================================================================
-- SECTION 17: QUIZ_ATTEMPTS
-- =============================================================================
-- Students can create/read their own attempts.
-- Teachers can read attempts for quizzes in their courses.
-- Admins can read attempts in their tenant.
-- Parents can read their children's attempts.

-- SELECT: Students can read their own attempts
CREATE POLICY "quiz_attempts_select_student_own"
ON quiz_attempts FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read attempts for quizzes in their courses
CREATE POLICY "quiz_attempts_select_teacher"
ON quiz_attempts FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quizzes q
        WHERE q.id = quiz_attempts.quiz_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- SELECT: Admins can read quiz attempts in their tenant
CREATE POLICY "quiz_attempts_select_admin"
ON quiz_attempts FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's quiz attempts
CREATE POLICY "quiz_attempts_select_parent"
ON quiz_attempts FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can create their own quiz attempts
CREATE POLICY "quiz_attempts_insert_student"
ON quiz_attempts FOR INSERT
TO authenticated
WITH CHECK (
    student_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Students can update their own attempts (e.g., completing)
CREATE POLICY "quiz_attempts_update_student_own"
ON quiz_attempts FOR UPDATE
TO authenticated
USING (student_id = auth.uid())
WITH CHECK (student_id = auth.uid());


-- =============================================================================
-- SECTION 18: QUIZ_ANSWERS
-- =============================================================================
-- Access via quiz_attempts chain.

-- SELECT: Students can read answers for their own attempts
CREATE POLICY "quiz_answers_select_student_own"
ON quiz_answers FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_attempts qa
        WHERE qa.id = quiz_answers.attempt_id
          AND qa.student_id = auth.uid()
    )
);

-- SELECT: Teachers can read answers for attempts in their course quizzes
CREATE POLICY "quiz_answers_select_teacher"
ON quiz_answers FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_attempts qa
        JOIN quizzes q ON q.id = qa.quiz_id
        WHERE qa.id = quiz_answers.attempt_id
          AND is_course_teacher(auth.uid(), q.course_id)
    )
);

-- SELECT: Admins can read answers in their tenant
CREATE POLICY "quiz_answers_select_admin"
ON quiz_answers FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM quiz_attempts qa
        WHERE qa.id = quiz_answers.attempt_id
          AND qa.tenant_id = get_user_tenant_id()
          AND get_user_role() = 'admin'
    )
);

-- INSERT: Students can create answers for their own attempts
CREATE POLICY "quiz_answers_insert_student"
ON quiz_answers FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM quiz_attempts qa
        WHERE qa.id = quiz_answers.attempt_id
          AND qa.student_id = auth.uid()
    )
);


-- =============================================================================
-- SECTION 19: ATTENDANCE_RECORDS
-- =============================================================================
-- Students can read their own attendance records.
-- Teachers can CRUD attendance for their courses.
-- Admins can CRUD attendance in their tenant.
-- Parents can read their children's attendance.

-- SELECT: Students can read their own attendance
CREATE POLICY "attendance_records_select_student_own"
ON attendance_records FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read attendance for their courses
CREATE POLICY "attendance_records_select_teacher"
ON attendance_records FOR SELECT
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- SELECT: Admins can read all attendance in their tenant
CREATE POLICY "attendance_records_select_admin"
ON attendance_records FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's attendance
CREATE POLICY "attendance_records_select_parent"
ON attendance_records FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Teachers can create attendance records for their courses
CREATE POLICY "attendance_records_insert_teacher"
ON attendance_records FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND marked_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create attendance records in their tenant
CREATE POLICY "attendance_records_insert_admin"
ON attendance_records FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update attendance for their courses
CREATE POLICY "attendance_records_update_teacher"
ON attendance_records FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Admins can update attendance in their tenant
CREATE POLICY "attendance_records_update_admin"
ON attendance_records FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can delete attendance for their courses
CREATE POLICY "attendance_records_delete_teacher"
ON attendance_records FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- DELETE: Admins can delete attendance in their tenant
CREATE POLICY "attendance_records_delete_admin"
ON attendance_records FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 20: ANNOUNCEMENTS
-- =============================================================================
-- All same-tenant users can read announcements.
-- Admins and teachers can create announcements (created_by column).
-- Authors can update/delete their own.
-- Admins can update/delete any in their tenant.

-- SELECT: Authenticated users can read announcements in their tenant
CREATE POLICY "announcements_select_tenant"
ON announcements FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Admins can create announcements in their tenant
CREATE POLICY "announcements_insert_admin"
ON announcements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
    AND created_by = auth.uid()
);

-- INSERT: Teachers can create announcements
CREATE POLICY "announcements_insert_teacher"
ON announcements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'teacher'
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Authors can update their own announcements
CREATE POLICY "announcements_update_author"
ON announcements FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- UPDATE: Admins can update announcements in their tenant
CREATE POLICY "announcements_update_admin"
ON announcements FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Authors can delete their own announcements
CREATE POLICY "announcements_delete_author"
ON announcements FOR DELETE
TO authenticated
USING (created_by = auth.uid());

-- DELETE: Admins can delete announcements in their tenant
CREATE POLICY "announcements_delete_admin"
ON announcements FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 21: CONVERSATIONS
-- =============================================================================
-- Only members can read conversations.
-- Authenticated users can create conversations in their tenant.

-- SELECT: Only members can read a conversation
CREATE POLICY "conversations_select_member"
ON conversations FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_members cm
        WHERE cm.conversation_id = conversations.id
          AND cm.user_id = auth.uid()
    )
);

-- INSERT: Authenticated users can create conversations in their tenant
CREATE POLICY "conversations_insert_authenticated"
ON conversations FOR INSERT
TO authenticated
WITH CHECK (
    created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Conversation creator can update (e.g., subject)
CREATE POLICY "conversations_update_creator"
ON conversations FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());


-- =============================================================================
-- SECTION 22: CONVERSATION_MEMBERS
-- =============================================================================
-- Users can see members of conversations they belong to.
-- Members can add others. Users can add themselves (join).

-- SELECT: Users can read members for conversations they belong to
CREATE POLICY "conversation_members_select_member"
ON conversation_members FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_members cm2
        WHERE cm2.conversation_id = conversation_members.conversation_id
          AND cm2.user_id = auth.uid()
    )
);

-- INSERT: Users can add members to conversations they belong to, or add themselves
CREATE POLICY "conversation_members_insert_member"
ON conversation_members FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM conversation_members cm2
        WHERE cm2.conversation_id = conversation_members.conversation_id
          AND cm2.user_id = auth.uid()
    )
);

-- DELETE: Users can remove themselves from conversations
CREATE POLICY "conversation_members_delete_self"
ON conversation_members FOR DELETE
TO authenticated
USING (user_id = auth.uid());


-- =============================================================================
-- SECTION 23: MESSAGES
-- =============================================================================
-- Only conversation members can read/write messages.

-- SELECT: Only members can read messages in their conversations
CREATE POLICY "messages_select_member"
ON messages FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_members cm
        WHERE cm.conversation_id = messages.conversation_id
          AND cm.user_id = auth.uid()
    )
);

-- INSERT: Only members can send messages to their conversations
CREATE POLICY "messages_insert_member"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
    AND EXISTS (
        SELECT 1 FROM conversation_members cm
        WHERE cm.conversation_id = messages.conversation_id
          AND cm.user_id = auth.uid()
    )
);

-- UPDATE: Senders can update their own messages (edit)
CREATE POLICY "messages_update_sender"
ON messages FOR UPDATE
TO authenticated
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- DELETE: Senders can soft-delete their own messages
CREATE POLICY "messages_delete_sender"
ON messages FOR DELETE
TO authenticated
USING (sender_id = auth.uid());


-- =============================================================================
-- SECTION 24: MESSAGE_READ_RECEIPTS
-- =============================================================================
-- Users can only manage their own read receipts.

-- SELECT: Users can read their own receipts
CREATE POLICY "message_read_receipts_select_own"
ON message_read_receipts FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT: Users can create their own read receipts
CREATE POLICY "message_read_receipts_insert_own"
ON message_read_receipts FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- UPDATE: Users can update their own read receipts
CREATE POLICY "message_read_receipts_update_own"
ON message_read_receipts FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());


-- =============================================================================
-- SECTION 25: ACHIEVEMENTS
-- =============================================================================
-- All authenticated users can read the achievements catalog.
-- Admins and teachers can CRUD achievements in their tenant.

-- SELECT: All authenticated users can read achievements in their tenant (or global)
CREATE POLICY "achievements_select_all"
ON achievements FOR SELECT
TO authenticated
USING (
    tenant_id = get_user_tenant_id()
    OR is_global = true
);

-- INSERT: Admins can create achievements in their tenant
CREATE POLICY "achievements_insert_admin"
ON achievements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Admins can update achievements in their tenant
CREATE POLICY "achievements_update_admin"
ON achievements FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Admins can delete achievements in their tenant
CREATE POLICY "achievements_delete_admin"
ON achievements FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 26: STUDENT_ACHIEVEMENTS
-- =============================================================================
-- Students can read their own achievements.
-- Teachers can read achievements for students in their courses.
-- Admins can CRUD in their tenant.
-- Parents can read their children's achievements.

-- SELECT: Students can read their own achievements
CREATE POLICY "student_achievements_select_student_own"
ON student_achievements FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read achievements for students in their courses
CREATE POLICY "student_achievements_select_teacher"
ON student_achievements FOR SELECT
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM course_enrollments ce
        JOIN courses c ON c.id = ce.course_id
        WHERE ce.student_id = student_achievements.student_id
          AND c.created_by = auth.uid()
    )
);

-- SELECT: Admins can read all student achievements in their tenant
CREATE POLICY "student_achievements_select_admin"
ON student_achievements FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Parents can read their children's achievements
CREATE POLICY "student_achievements_select_parent"
ON student_achievements FOR SELECT
TO authenticated
USING (
    get_user_role() = 'parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Admins can grant achievements
CREATE POLICY "student_achievements_insert_admin"
ON student_achievements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Teachers can grant achievements to students in their courses
CREATE POLICY "student_achievements_insert_teacher"
ON student_achievements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'teacher'
    AND tenant_id = get_user_tenant_id()
    AND EXISTS (
        SELECT 1 FROM course_enrollments ce
        JOIN courses c ON c.id = ce.course_id
        WHERE ce.student_id = student_achievements.student_id
          AND c.created_by = auth.uid()
    )
);

-- UPDATE: Students can update their own (e.g., toggle displayed)
CREATE POLICY "student_achievements_update_student_own"
ON student_achievements FOR UPDATE
TO authenticated
USING (student_id = auth.uid())
WITH CHECK (student_id = auth.uid());


-- =============================================================================
-- SECTION 27: STUDENT_PARENTS
-- =============================================================================
-- Parents can read their own links.
-- Students can see who their parents are.
-- Admins can CRUD links in their tenant.

-- SELECT: Parents can read their own parent-student links
CREATE POLICY "student_parents_select_parent"
ON student_parents FOR SELECT
TO authenticated
USING (parent_id = auth.uid());

-- SELECT: Students can see their linked parents
CREATE POLICY "student_parents_select_student"
ON student_parents FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Admins can read all links in their tenant
CREATE POLICY "student_parents_select_admin"
ON student_parents FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create parent-student links in their tenant
CREATE POLICY "student_parents_insert_admin"
ON student_parents FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Admins can update links in their tenant
CREATE POLICY "student_parents_update_admin"
ON student_parents FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Admins can delete parent-student links in their tenant
CREATE POLICY "student_parents_delete_admin"
ON student_parents FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- SECTION 28: STUDENT_XP
-- =============================================================================
-- Students can read their own XP.
-- Same-tenant users can read XP for leaderboard.
-- Admins can update XP.

-- SELECT: Students can read their own XP
CREATE POLICY "student_xp_select_student_own"
ON student_xp FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Same-tenant users can read XP (for leaderboard)
CREATE POLICY "student_xp_select_tenant"
ON student_xp FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: System creates XP records (students can also self-insert on first setup)
CREATE POLICY "student_xp_insert_own"
ON student_xp FOR INSERT
TO authenticated
WITH CHECK (
    student_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Students can update their own XP (streak, last_login_date)
CREATE POLICY "student_xp_update_own"
ON student_xp FOR UPDATE
TO authenticated
USING (student_id = auth.uid())
WITH CHECK (student_id = auth.uid());

-- UPDATE: Admins can update XP in their tenant
CREATE POLICY "student_xp_update_admin"
ON student_xp FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 29: LEADERBOARD_ENTRIES
-- =============================================================================
-- Same-tenant users can read leaderboard entries.
-- System manages writes (typically via service role or triggers).

-- SELECT: Same-tenant users can read leaderboard entries
CREATE POLICY "leaderboard_entries_select_tenant"
ON leaderboard_entries FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Admins or system can insert leaderboard entries
CREATE POLICY "leaderboard_entries_insert_admin"
ON leaderboard_entries FOR INSERT
TO authenticated
WITH CHECK (
    tenant_id = get_user_tenant_id()
);

-- UPDATE: Admins or system can update leaderboard entries
CREATE POLICY "leaderboard_entries_update_admin"
ON leaderboard_entries FOR UPDATE
TO authenticated
USING (tenant_id = get_user_tenant_id())
WITH CHECK (tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 30: NOTIFICATIONS
-- =============================================================================
-- Users can only see and manage their own notifications.

-- SELECT: Users can read their own notifications
CREATE POLICY "notifications_select_own"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT: System/admins can create notifications (tenant scoped)
CREATE POLICY "notifications_insert_tenant"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (tenant_id = get_user_tenant_id());

-- UPDATE: Users can update their own notifications (mark read)
CREATE POLICY "notifications_update_own"
ON notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- DELETE: Users can delete their own notifications
CREATE POLICY "notifications_delete_own"
ON notifications FOR DELETE
TO authenticated
USING (user_id = auth.uid());


-- =============================================================================
-- SECTION 31: NOTIFICATION_PREFERENCES
-- =============================================================================
-- Users can only manage their own notification preferences.

-- SELECT: Users can read their own preferences
CREATE POLICY "notification_preferences_select_own"
ON notification_preferences FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT: Users can create their own preferences
CREATE POLICY "notification_preferences_insert_own"
ON notification_preferences FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- UPDATE: Users can update their own preferences
CREATE POLICY "notification_preferences_update_own"
ON notification_preferences FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- DELETE: Users can delete their own preferences
CREATE POLICY "notification_preferences_delete_own"
ON notification_preferences FOR DELETE
TO authenticated
USING (user_id = auth.uid());


-- =============================================================================
-- SECTION 32: CLASS_CODES
-- =============================================================================
-- Teachers can CRUD class codes for their courses.
-- Admins can CRUD in their tenant.
-- Students can read active class codes (for enrollment).

-- SELECT: Teachers can read class codes for their courses
CREATE POLICY "class_codes_select_teacher"
ON class_codes FOR SELECT
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- SELECT: Admins can read all class codes in their tenant
CREATE POLICY "class_codes_select_admin"
ON class_codes FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- SELECT: Students can read active class codes in their tenant (for enrollment)
CREATE POLICY "class_codes_select_student_active"
ON class_codes FOR SELECT
TO authenticated
USING (
    get_user_role() = 'student'
    AND tenant_id = get_user_tenant_id()
    AND is_active = true
);

-- INSERT: Teachers can create class codes for their courses
CREATE POLICY "class_codes_insert_teacher"
ON class_codes FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create class codes in their tenant
CREATE POLICY "class_codes_insert_admin"
ON class_codes FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update class codes for their courses
CREATE POLICY "class_codes_update_teacher"
ON class_codes FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Admins can update class codes in their tenant
CREATE POLICY "class_codes_update_admin"
ON class_codes FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());

-- DELETE: Teachers can delete class codes for their courses
CREATE POLICY "class_codes_delete_teacher"
ON class_codes FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- DELETE: Admins can delete class codes in their tenant
CREATE POLICY "class_codes_delete_admin"
ON class_codes FOR DELETE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 33: COIN_TRANSACTIONS
-- =============================================================================
-- Students can read their own coin transactions.
-- Admins can read/create in their tenant.

-- SELECT: Students can read their own transactions
CREATE POLICY "coin_transactions_select_student_own"
ON coin_transactions FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Admins can read all transactions in their tenant
CREATE POLICY "coin_transactions_select_admin"
ON coin_transactions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: System can create transactions (tenant scoped)
CREATE POLICY "coin_transactions_insert_tenant"
ON coin_transactions FOR INSERT
TO authenticated
WITH CHECK (tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 34: XP_EVENTS
-- =============================================================================
-- Students can read their own XP events.
-- Admins can read/create in their tenant.

-- SELECT: Students can read their own XP events
CREATE POLICY "xp_events_select_student_own"
ON xp_events FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- SELECT: Admins can read all XP events in their tenant
CREATE POLICY "xp_events_select_admin"
ON xp_events FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: System can create XP events (tenant scoped)
CREATE POLICY "xp_events_insert_tenant"
ON xp_events FOR INSERT
TO authenticated
WITH CHECK (tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 35: AUDIT_LOGS
-- =============================================================================
-- Admins can only read audit logs in their tenant.
-- Inserts happen via service role or triggers.

-- SELECT: Admins can read audit logs in their tenant
CREATE POLICY "audit_logs_select_admin"
ON audit_logs FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Allow inserts within tenant (system/triggers will use service role,
-- but authenticated inserts are allowed for client-side audit logging)
CREATE POLICY "audit_logs_insert_tenant"
ON audit_logs FOR INSERT
TO authenticated
WITH CHECK (
    tenant_id = get_user_tenant_id()
    AND user_id = auth.uid()
);


-- =============================================================================
-- SECTION 36: RUBRICS
-- =============================================================================
-- Follow course access via assignment -> course chain.
-- Teachers can CRUD rubrics for their course assignments.

-- SELECT: Anyone with course access can read rubrics
CREATE POLICY "rubrics_select_course_access"
ON rubrics FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = rubrics.assignment_id
        AND (
            is_course_teacher(auth.uid(), a.course_id)
            OR is_enrolled_in_course(auth.uid(), a.course_id)
            OR (get_user_role() = 'admin' AND a.tenant_id = get_user_tenant_id())
            OR (get_user_role() = 'parent' AND a.course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
        )
    )
);

-- INSERT: Teachers can create rubrics for assignments in their courses
CREATE POLICY "rubrics_insert_teacher"
ON rubrics FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = rubrics.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
    AND created_by = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update rubrics for assignments in their courses
CREATE POLICY "rubrics_update_teacher"
ON rubrics FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = rubrics.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = rubrics.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
);

-- DELETE: Teachers can delete rubrics for assignments in their courses
CREATE POLICY "rubrics_delete_teacher"
ON rubrics FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM assignments a
        WHERE a.id = rubrics.assignment_id
          AND is_course_teacher(auth.uid(), a.course_id)
    )
);


-- =============================================================================
-- SECTION 37: LESSON_ATTACHMENTS
-- =============================================================================
-- Follow lesson -> course access chain.

-- SELECT: Anyone with course access can read lesson attachments
CREATE POLICY "lesson_attachments_select_course_access"
ON lesson_attachments FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lessons l
        WHERE l.id = lesson_attachments.lesson_id
        AND (
            is_course_teacher(auth.uid(), l.course_id)
            OR is_enrolled_in_course(auth.uid(), l.course_id)
            OR (get_user_role() = 'admin' AND l.tenant_id = get_user_tenant_id())
            OR (get_user_role() = 'parent' AND l.course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
        )
    )
);

-- INSERT: Teachers can create attachments for lessons in their courses
CREATE POLICY "lesson_attachments_insert_teacher"
ON lesson_attachments FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM lessons l
        WHERE l.id = lesson_attachments.lesson_id
          AND is_course_teacher(auth.uid(), l.course_id)
    )
);

-- UPDATE: Teachers can update attachments for lessons in their courses
CREATE POLICY "lesson_attachments_update_teacher"
ON lesson_attachments FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lessons l
        WHERE l.id = lesson_attachments.lesson_id
          AND is_course_teacher(auth.uid(), l.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM lessons l
        WHERE l.id = lesson_attachments.lesson_id
          AND is_course_teacher(auth.uid(), l.course_id)
    )
);

-- DELETE: Teachers can delete attachments for lessons in their courses
CREATE POLICY "lesson_attachments_delete_teacher"
ON lesson_attachments FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lessons l
        WHERE l.id = lesson_attachments.lesson_id
          AND is_course_teacher(auth.uid(), l.course_id)
    )
);


-- =============================================================================
-- SECTION 38: CONSENT_RECORDS
-- =============================================================================
-- Parents can read their own consent records.
-- Admins can CRUD consent records in their tenant.

-- SELECT: Parents can read their own consent records
CREATE POLICY "consent_records_select_parent"
ON consent_records FOR SELECT
TO authenticated
USING (parent_id = auth.uid());

-- SELECT: Admins can read all consent records in their tenant
CREATE POLICY "consent_records_select_admin"
ON consent_records FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Parents can create their own consent records
CREATE POLICY "consent_records_insert_parent"
ON consent_records FOR INSERT
TO authenticated
WITH CHECK (
    parent_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Admins can create consent records in their tenant
CREATE POLICY "consent_records_insert_admin"
ON consent_records FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Parents can update their own consent records (withdrawal)
CREATE POLICY "consent_records_update_parent"
ON consent_records FOR UPDATE
TO authenticated
USING (parent_id = auth.uid())
WITH CHECK (parent_id = auth.uid());

-- UPDATE: Admins can update consent records in their tenant
CREATE POLICY "consent_records_update_admin"
ON consent_records FOR UPDATE
TO authenticated
USING (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id())
WITH CHECK (get_user_role() = 'admin' AND tenant_id = get_user_tenant_id());


-- =============================================================================
-- SECTION 39: Grant execute on helper functions to authenticated role
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_tenant_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_course_teacher(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_parent_of(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_course_ids(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_ids(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_course_access(uuid, uuid) TO authenticated;


-- =============================================================================
-- END OF RLS POLICIES
-- =============================================================================
-- IMPORTANT: The service_role key bypasses all RLS policies.
-- Use the anon/authenticated key in the client app so RLS is enforced.
-- =============================================================================
