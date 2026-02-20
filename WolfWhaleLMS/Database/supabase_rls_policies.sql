-- =============================================================================
-- WolfWhale LMS - Row Level Security Policies
-- =============================================================================
-- This migration enables RLS on all tables and creates granular access policies
-- for multi-tenant isolation. Designed for FERPA/COPPA compliance in K-12
-- school deployments.
--
-- Roles: Student, Teacher, Admin, Parent
-- Tenant isolation: school_id on profiles, tenant_id on courses/announcements
--
-- Run this AFTER all tables have been created.
-- =============================================================================

-- =============================================================================
-- SECTION 1: Helper Functions
-- =============================================================================

-- Helper function to get the current user's role without repeated subqueries
-- Uses SECURITY DEFINER so it can always read profiles regardless of RLS
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM profiles WHERE id = auth.uid();
$$;

-- Helper function to get the current user's school_id
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT school_id FROM profiles WHERE id = auth.uid();
$$;

-- Helper function to check if a user is enrolled in a course
CREATE OR REPLACE FUNCTION public.is_enrolled_in_course(p_user_id uuid, p_course_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM enrollments
        WHERE student_id = p_user_id AND course_id = p_course_id
    );
$$;

-- Helper function to check if a user owns (teaches) a course
CREATE OR REPLACE FUNCTION public.is_course_teacher(p_user_id uuid, p_course_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM courses
        WHERE id = p_course_id AND teacher_id = p_user_id
    );
$$;

-- Helper function to check if a parent has a link to a specific child
CREATE OR REPLACE FUNCTION public.is_parent_of(p_parent_id uuid, p_child_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM parent_child_links
        WHERE parent_id = p_parent_id AND child_id = p_child_id
    );
$$;

-- Helper function to get all course IDs a user's children are enrolled in
CREATE OR REPLACE FUNCTION public.get_parent_child_course_ids(p_parent_id uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT e.course_id
    FROM parent_child_links pcl
    JOIN enrollments e ON e.student_id = pcl.child_id
    WHERE pcl.parent_id = p_parent_id;
$$;

-- =============================================================================
-- SECTION 2: Enable RLS on ALL tables
-- =============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_child_links ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 3: Drop existing policies (idempotent migration)
-- =============================================================================
-- This ensures the migration can be re-run safely.

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
            'profiles', 'courses', 'modules', 'lessons', 'lesson_completions',
            'enrollments', 'assignments', 'submissions', 'grades',
            'quizzes', 'quiz_questions', 'quiz_attempts', 'attendance',
            'announcements', 'conversations', 'conversation_participants',
            'messages', 'achievements', 'student_achievements', 'parent_child_links'
          )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- =============================================================================
-- SECTION 4: PROFILES
-- =============================================================================
-- Users can read/update their own profile.
-- Admins can read/create/delete profiles in their school.
-- Teachers can read student profiles for courses they teach.
-- Parents can read their linked children's profiles.

-- SELECT: Users can always read their own profile
CREATE POLICY "profiles_select_own"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- SELECT: Admins can read all profiles in their school
CREATE POLICY "profiles_select_admin_school"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND school_id = get_user_school_id()
);

-- SELECT: Teachers can read profiles of students enrolled in their courses
CREATE POLICY "profiles_select_teacher_students"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND EXISTS (
        SELECT 1 FROM enrollments e
        JOIN courses c ON c.id = e.course_id
        WHERE e.student_id = profiles.id
          AND c.teacher_id = auth.uid()
    )
);

-- SELECT: Parents can read their children's profiles
CREATE POLICY "profiles_select_parent_children"
ON profiles FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), profiles.id)
);

-- SELECT: All users can read profiles in their school (for leaderboard/XP rankings)
-- Only exposes rows in the same school; the client selects only the columns needed
-- (e.g., display_name, avatar_url, xp) so sensitive fields stay hidden by column-level grants.
CREATE POLICY "profiles_select_school_leaderboard"
ON profiles FOR SELECT
TO authenticated
USING (school_id = get_user_school_id());

-- UPDATE: Users can update their own profile only
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- INSERT: Admins can create profiles in their school
CREATE POLICY "profiles_insert_admin"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Admin'
    AND school_id = get_user_school_id()
);

-- DELETE: Admins can delete profiles in their school (not themselves)
CREATE POLICY "profiles_delete_admin"
ON profiles FOR DELETE
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND school_id = get_user_school_id()
    AND id != auth.uid()
);

-- =============================================================================
-- SECTION 5: COURSES
-- =============================================================================
-- Teachers can CRUD their own courses.
-- Students can read courses they are enrolled in.
-- Admins can CRUD courses within their school (tenant_id scoping).
-- Parents can read courses their children are enrolled in.

-- SELECT: Teachers can read their own courses
CREATE POLICY "courses_select_teacher_own"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND teacher_id = auth.uid()
);

-- SELECT: Students can read courses they are enrolled in
CREATE POLICY "courses_select_student_enrolled"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Student'
    AND is_enrolled_in_course(auth.uid(), courses.id)
);

-- SELECT: Admins can read courses in their school
CREATE POLICY "courses_select_admin"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- SELECT: Parents can read courses their children are enrolled in
CREATE POLICY "courses_select_parent_children"
ON courses FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND courses.id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create courses (they become the teacher_id)
CREATE POLICY "courses_insert_teacher"
ON courses FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Teacher'
    AND teacher_id = auth.uid()
);

-- INSERT: Admins can create courses in their school
CREATE POLICY "courses_insert_admin"
ON courses FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- UPDATE: Teachers can update their own courses
CREATE POLICY "courses_update_teacher_own"
ON courses FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND teacher_id = auth.uid()
)
WITH CHECK (
    get_user_role() = 'Teacher'
    AND teacher_id = auth.uid()
);

-- UPDATE: Admins can update courses in their school
CREATE POLICY "courses_update_admin"
ON courses FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
)
WITH CHECK (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- DELETE: Teachers can delete their own courses
CREATE POLICY "courses_delete_teacher_own"
ON courses FOR DELETE
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND teacher_id = auth.uid()
);

-- DELETE: Admins can delete courses in their school
CREATE POLICY "courses_delete_admin"
ON courses FOR DELETE
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- =============================================================================
-- SECTION 6: MODULES
-- =============================================================================
-- Follow course access: if you can see the course, you can see its modules.
-- Teachers who own the course can CRUD.

-- SELECT: Anyone who can access the course can read its modules
CREATE POLICY "modules_select_course_access"
ON modules FOR SELECT
TO authenticated
USING (
    -- Teacher owns the course
    is_course_teacher(auth.uid(), course_id)
    -- Student is enrolled
    OR is_enrolled_in_course(auth.uid(), course_id)
    -- Admin can see all
    OR get_user_role() = 'Admin'
    -- Parent's child is enrolled
    OR (get_user_role() = 'Parent' AND course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
);

-- INSERT: Teachers can create modules for their own courses
CREATE POLICY "modules_insert_teacher"
ON modules FOR INSERT
TO authenticated
WITH CHECK (
    is_course_teacher(auth.uid(), course_id)
);

-- UPDATE: Teachers can update modules for their own courses
CREATE POLICY "modules_update_teacher"
ON modules FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- DELETE: Teachers can delete modules for their own courses
CREATE POLICY "modules_delete_teacher"
ON modules FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- =============================================================================
-- SECTION 7: LESSONS
-- =============================================================================
-- Follow course access via module -> course chain.
-- Teachers who own the course can CRUD.

-- SELECT: Anyone who can access the course (via module) can read lessons
CREATE POLICY "lessons_select_course_access"
ON lessons FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM modules m
        WHERE m.id = lessons.module_id
        AND (
            is_course_teacher(auth.uid(), m.course_id)
            OR is_enrolled_in_course(auth.uid(), m.course_id)
            OR get_user_role() = 'Admin'
            OR (get_user_role() = 'Parent' AND m.course_id IN (SELECT get_parent_child_course_ids(auth.uid())))
        )
    )
);

-- INSERT: Teachers can create lessons for modules in their courses
CREATE POLICY "lessons_insert_teacher"
ON lessons FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM modules m
        WHERE m.id = lessons.module_id
        AND is_course_teacher(auth.uid(), m.course_id)
    )
);

-- UPDATE: Teachers can update lessons for modules in their courses
CREATE POLICY "lessons_update_teacher"
ON lessons FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM modules m
        WHERE m.id = lessons.module_id
        AND is_course_teacher(auth.uid(), m.course_id)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM modules m
        WHERE m.id = lessons.module_id
        AND is_course_teacher(auth.uid(), m.course_id)
    )
);

-- DELETE: Teachers can delete lessons for modules in their courses
CREATE POLICY "lessons_delete_teacher"
ON lessons FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM modules m
        WHERE m.id = lessons.module_id
        AND is_course_teacher(auth.uid(), m.course_id)
    )
);

-- =============================================================================
-- SECTION 8: LESSON_COMPLETIONS
-- =============================================================================
-- Students can create/read their own completions.
-- Teachers can read completions for students in their courses.

-- SELECT: Students can read their own completions
CREATE POLICY "lesson_completions_select_student_own"
ON lesson_completions FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read completions for students in their courses
CREATE POLICY "lesson_completions_select_teacher"
ON lesson_completions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND EXISTS (
        SELECT 1 FROM lessons l
        JOIN modules m ON m.id = l.module_id
        WHERE l.id = lesson_completions.lesson_id
          AND is_course_teacher(auth.uid(), m.course_id)
    )
);

-- SELECT: Parents can read their children's completions
CREATE POLICY "lesson_completions_select_parent"
ON lesson_completions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can create their own completions
CREATE POLICY "lesson_completions_insert_student"
ON lesson_completions FOR INSERT
TO authenticated
WITH CHECK (student_id = auth.uid());

-- =============================================================================
-- SECTION 9: ENROLLMENTS
-- =============================================================================
-- Students can read their own enrollments.
-- Teachers can read enrollments for their courses.
-- Admins can CRUD all enrollments.

-- SELECT: Students can read their own enrollments
CREATE POLICY "enrollments_select_student_own"
ON enrollments FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read enrollments for courses they teach
CREATE POLICY "enrollments_select_teacher"
ON enrollments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- SELECT: Admins can read all enrollments
CREATE POLICY "enrollments_select_admin"
ON enrollments FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read their children's enrollments
CREATE POLICY "enrollments_select_parent"
ON enrollments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can enroll themselves
CREATE POLICY "enrollments_insert_student_self"
ON enrollments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Student'
    AND student_id = auth.uid()
);

-- INSERT: Admins can create enrollments for anyone
CREATE POLICY "enrollments_insert_admin"
ON enrollments FOR INSERT
TO authenticated
WITH CHECK (get_user_role() = 'Admin');

-- INSERT: Teachers can enroll students into their courses
CREATE POLICY "enrollments_insert_teacher"
ON enrollments FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- DELETE: Admins can remove enrollments
CREATE POLICY "enrollments_delete_admin"
ON enrollments FOR DELETE
TO authenticated
USING (get_user_role() = 'Admin');

-- DELETE: Teachers can unenroll students from their courses
CREATE POLICY "enrollments_delete_teacher"
ON enrollments FOR DELETE
TO authenticated
USING (
    get_user_role() = 'Teacher'
    AND is_course_teacher(auth.uid(), course_id)
);

-- =============================================================================
-- SECTION 10: ASSIGNMENTS
-- =============================================================================
-- Follow course access for reading.
-- Teachers who own the course can CRUD.

-- SELECT: Students can read assignments for courses they are enrolled in
CREATE POLICY "assignments_select_student_enrolled"
ON assignments FOR SELECT
TO authenticated
USING (
    is_enrolled_in_course(auth.uid(), course_id)
);

-- SELECT: Teachers can read assignments for their courses
CREATE POLICY "assignments_select_teacher"
ON assignments FOR SELECT
TO authenticated
USING (
    is_course_teacher(auth.uid(), course_id)
);

-- SELECT: Admins can read all assignments
CREATE POLICY "assignments_select_admin"
ON assignments FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read assignments for their children's courses
CREATE POLICY "assignments_select_parent"
ON assignments FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND course_id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create assignments for their courses
CREATE POLICY "assignments_insert_teacher"
ON assignments FOR INSERT
TO authenticated
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Teachers can update assignments for their courses
CREATE POLICY "assignments_update_teacher"
ON assignments FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- DELETE: Teachers can delete assignments for their courses
CREATE POLICY "assignments_delete_teacher"
ON assignments FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- =============================================================================
-- SECTION 11: SUBMISSIONS
-- =============================================================================
-- Students can create/read their own submissions.
-- Teachers can read/update submissions for their courses.

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

-- SELECT: Admins can read all submissions
CREATE POLICY "submissions_select_admin"
ON submissions FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read their children's submissions
CREATE POLICY "submissions_select_parent"
ON submissions FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can submit their own work
CREATE POLICY "submissions_insert_student"
ON submissions FOR INSERT
TO authenticated
WITH CHECK (student_id = auth.uid());

-- UPDATE: Teachers can update submissions (add grades/feedback) for their courses
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
-- SECTION 12: GRADES
-- =============================================================================
-- Students can read their own grades.
-- Teachers can create/read grades for their courses.
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
USING (
    is_course_teacher(auth.uid(), course_id)
);

-- SELECT: Admins can read all grades
CREATE POLICY "grades_select_admin"
ON grades FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read their children's grades
CREATE POLICY "grades_select_parent"
ON grades FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Teachers can create grades for courses they teach
CREATE POLICY "grades_insert_teacher"
ON grades FOR INSERT
TO authenticated
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- UPDATE: Teachers can update grades for courses they teach
CREATE POLICY "grades_update_teacher"
ON grades FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- =============================================================================
-- SECTION 13: QUIZZES
-- =============================================================================
-- Follow course access for reading.
-- Teachers who own the course can CRUD.

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

-- SELECT: Admins can read all quizzes
CREATE POLICY "quizzes_select_admin"
ON quizzes FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read quizzes in their children's courses
CREATE POLICY "quizzes_select_parent"
ON quizzes FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND course_id IN (SELECT get_parent_child_course_ids(auth.uid()))
);

-- INSERT: Teachers can create quizzes for their courses
CREATE POLICY "quizzes_insert_teacher"
ON quizzes FOR INSERT
TO authenticated
WITH CHECK (is_course_teacher(auth.uid(), course_id));

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
-- SECTION 14: QUIZ_QUESTIONS
-- =============================================================================
-- Follow quiz -> course access for reading.
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
            OR get_user_role() = 'Admin'
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
-- SECTION 15: QUIZ_ATTEMPTS
-- =============================================================================
-- Students can create/read their own attempts.
-- Teachers can read attempts for quizzes in their courses.

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

-- SELECT: Admins can read quiz attempts in their school
CREATE POLICY "quiz_attempts_select_admin"
ON quiz_attempts FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND EXISTS (
        SELECT 1 FROM quizzes q
        JOIN courses c ON c.id = q.course_id
        WHERE q.id = quiz_attempts.quiz_id
          AND c.tenant_id::text = get_user_school_id()
    )
);

-- SELECT: Parents can read their children's quiz attempts
CREATE POLICY "quiz_attempts_select_parent"
ON quiz_attempts FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Students can create their own quiz attempts
CREATE POLICY "quiz_attempts_insert_student"
ON quiz_attempts FOR INSERT
TO authenticated
WITH CHECK (student_id = auth.uid());

-- =============================================================================
-- SECTION 16: ATTENDANCE
-- =============================================================================
-- Students can read their own attendance records.
-- Teachers can CRUD attendance for their courses.
-- Admins can read all attendance.

-- SELECT: Students can read their own attendance
CREATE POLICY "attendance_select_student_own"
ON attendance FOR SELECT
TO authenticated
USING (student_id = auth.uid());

-- SELECT: Teachers can read attendance for their courses
CREATE POLICY "attendance_select_teacher"
ON attendance FOR SELECT
TO authenticated
USING (
    is_course_teacher(auth.uid(), course_id)
);

-- SELECT: Admins can read all attendance
CREATE POLICY "attendance_select_admin"
ON attendance FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read their children's attendance
CREATE POLICY "attendance_select_parent"
ON attendance FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Teachers can create attendance records for their courses
CREATE POLICY "attendance_insert_teacher"
ON attendance FOR INSERT
TO authenticated
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- INSERT: Admins can create attendance records
CREATE POLICY "attendance_insert_admin"
ON attendance FOR INSERT
TO authenticated
WITH CHECK (get_user_role() = 'Admin');

-- UPDATE: Teachers can update attendance for their courses
CREATE POLICY "attendance_update_teacher"
ON attendance FOR UPDATE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id))
WITH CHECK (is_course_teacher(auth.uid(), course_id));

-- DELETE: Teachers can delete attendance for their courses
CREATE POLICY "attendance_delete_teacher"
ON attendance FOR DELETE
TO authenticated
USING (is_course_teacher(auth.uid(), course_id));

-- =============================================================================
-- SECTION 17: ANNOUNCEMENTS
-- =============================================================================
-- Users can read announcements within their own school (tenant_id scoping).
-- Admins and teachers can create announcements (scoped to their school).
-- Authors can update/delete their own announcements.

-- SELECT: Authenticated users can read announcements in their school
CREATE POLICY "announcements_select_school"
ON announcements FOR SELECT
TO authenticated
USING (tenant_id::text = get_user_school_id());

-- INSERT: Admins can create announcements in their school
CREATE POLICY "announcements_insert_admin"
ON announcements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- INSERT: Teachers can create announcements
CREATE POLICY "announcements_insert_teacher"
ON announcements FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'Teacher'
    AND author_id = auth.uid()
);

-- UPDATE: Authors can update their own announcements
CREATE POLICY "announcements_update_author"
ON announcements FOR UPDATE
TO authenticated
USING (author_id = auth.uid())
WITH CHECK (author_id = auth.uid());

-- UPDATE: Admins can update announcements in their school
CREATE POLICY "announcements_update_admin"
ON announcements FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
)
WITH CHECK (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- DELETE: Authors can delete their own announcements
CREATE POLICY "announcements_delete_author"
ON announcements FOR DELETE
TO authenticated
USING (author_id = auth.uid());

-- DELETE: Admins can delete announcements in their school
CREATE POLICY "announcements_delete_admin"
ON announcements FOR DELETE
TO authenticated
USING (
    get_user_role() = 'Admin'
    AND tenant_id::text = get_user_school_id()
);

-- =============================================================================
-- SECTION 18: CONVERSATIONS
-- =============================================================================
-- Only participants can read conversations.

-- SELECT: Only participants can read a conversation
CREATE POLICY "conversations_select_participant"
ON conversations FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_participants cp
        WHERE cp.conversation_id = conversations.id
          AND cp.user_id = auth.uid()
    )
);

-- INSERT: Authenticated users can create conversations
CREATE POLICY "conversations_insert_authenticated"
ON conversations FOR INSERT
TO authenticated
WITH CHECK (true);

-- =============================================================================
-- SECTION 19: CONVERSATION_PARTICIPANTS
-- =============================================================================
-- Users can only see participant records for conversations they are in.

-- SELECT: Users can read participants for conversations they belong to
CREATE POLICY "conversation_participants_select_member"
ON conversation_participants FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_participants cp2
        WHERE cp2.conversation_id = conversation_participants.conversation_id
          AND cp2.user_id = auth.uid()
    )
);

-- INSERT: Users can add participants to conversations they belong to
CREATE POLICY "conversation_participants_insert_member"
ON conversation_participants FOR INSERT
TO authenticated
WITH CHECK (
    -- The inserting user must already be a participant, OR be adding themselves
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM conversation_participants cp2
        WHERE cp2.conversation_id = conversation_participants.conversation_id
          AND cp2.user_id = auth.uid()
    )
);

-- UPDATE: Users can update their own participant record (e.g., unread_count)
CREATE POLICY "conversation_participants_update_own"
ON conversation_participants FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- SECTION 20: MESSAGES
-- =============================================================================
-- Only conversation participants can read/write messages.

-- SELECT: Only participants can read messages in their conversations
CREATE POLICY "messages_select_participant"
ON messages FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversation_participants cp
        WHERE cp.conversation_id = messages.conversation_id
          AND cp.user_id = auth.uid()
    )
);

-- INSERT: Only participants can send messages to their conversations
CREATE POLICY "messages_insert_participant"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM conversation_participants cp
        WHERE cp.conversation_id = messages.conversation_id
          AND cp.user_id = auth.uid()
    )
);

-- =============================================================================
-- SECTION 21: ACHIEVEMENTS
-- =============================================================================
-- Everyone authenticated can read achievements (they are a catalog).
-- Admins can CRUD achievements.

-- SELECT: All authenticated users can read the achievements catalog
CREATE POLICY "achievements_select_all"
ON achievements FOR SELECT
TO authenticated
USING (true);

-- INSERT: Admins can create achievements
CREATE POLICY "achievements_insert_admin"
ON achievements FOR INSERT
TO authenticated
WITH CHECK (get_user_role() = 'Admin');

-- UPDATE: Admins can update achievements
CREATE POLICY "achievements_update_admin"
ON achievements FOR UPDATE
TO authenticated
USING (get_user_role() = 'Admin')
WITH CHECK (get_user_role() = 'Admin');

-- DELETE: Admins can delete achievements
CREATE POLICY "achievements_delete_admin"
ON achievements FOR DELETE
TO authenticated
USING (get_user_role() = 'Admin');

-- =============================================================================
-- SECTION 22: STUDENT_ACHIEVEMENTS
-- =============================================================================
-- Students can read their own earned achievements.
-- Admins can create (grant) achievements.
-- The system (via service role) can also grant achievements.

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
    get_user_role() = 'Teacher'
    AND EXISTS (
        SELECT 1 FROM enrollments e
        JOIN courses c ON c.id = e.course_id
        WHERE e.student_id = student_achievements.student_id
          AND c.teacher_id = auth.uid()
    )
);

-- SELECT: Admins can read all student achievements
CREATE POLICY "student_achievements_select_admin"
ON student_achievements FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- SELECT: Parents can read their children's achievements
CREATE POLICY "student_achievements_select_parent"
ON student_achievements FOR SELECT
TO authenticated
USING (
    get_user_role() = 'Parent'
    AND is_parent_of(auth.uid(), student_id)
);

-- INSERT: Admins can grant achievements
CREATE POLICY "student_achievements_insert_admin"
ON student_achievements FOR INSERT
TO authenticated
WITH CHECK (get_user_role() = 'Admin');

-- =============================================================================
-- SECTION 23: PARENT_CHILD_LINKS
-- =============================================================================
-- Parents can read their own links.
-- Admins can CRUD links.

-- SELECT: Parents can read their own parent-child links
CREATE POLICY "parent_child_links_select_parent"
ON parent_child_links FOR SELECT
TO authenticated
USING (parent_id = auth.uid());

-- SELECT: The linked child can also see the link
CREATE POLICY "parent_child_links_select_child"
ON parent_child_links FOR SELECT
TO authenticated
USING (child_id = auth.uid());

-- SELECT: Admins can read all links
CREATE POLICY "parent_child_links_select_admin"
ON parent_child_links FOR SELECT
TO authenticated
USING (get_user_role() = 'Admin');

-- INSERT: Admins can create parent-child links
CREATE POLICY "parent_child_links_insert_admin"
ON parent_child_links FOR INSERT
TO authenticated
WITH CHECK (get_user_role() = 'Admin');

-- DELETE: Admins can delete parent-child links
CREATE POLICY "parent_child_links_delete_admin"
ON parent_child_links FOR DELETE
TO authenticated
USING (get_user_role() = 'Admin');

-- =============================================================================
-- SECTION 24: Grant execute on helper functions to authenticated role
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_course_teacher(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_parent_of(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_parent_child_course_ids(uuid) TO authenticated;

-- =============================================================================
-- END OF RLS POLICIES
-- =============================================================================
-- IMPORTANT: The service_role key bypasses all RLS policies.
-- Use the anon/authenticated key in the client app so RLS is enforced.
-- The supabaseClient in SupabaseService.swift uses the anon key, which is correct.
-- =============================================================================
