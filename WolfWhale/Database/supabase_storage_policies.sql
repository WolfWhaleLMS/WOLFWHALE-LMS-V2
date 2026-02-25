-- =============================================================================
-- WolfWhale LMS - Supabase Storage Bucket Policies
-- =============================================================================
-- Applies RLS-style policies to storage buckets for file uploads.
-- Uses helper functions from supabase_rls_policies.sql (get_user_role(),
-- get_user_tenant_id(), is_course_teacher(), etc.)
--
-- Buckets (already exist - only policies are created here):
--   - assignment-submissions: Student-uploaded assignment files
--   - lesson-materials: Teacher-uploaded lesson content (PDFs, images, etc.)
--   - avatars: User profile avatars
--
-- Folder conventions:
--   assignment-submissions/{student_id}/{assignment_id}/{filename}
--   lesson-materials/{course_id}/{module_id}/{filename}
--   avatars/{user_id}/{filename}
--
-- KEY CHANGE: Uses get_user_role() from tenant_memberships instead of
-- (SELECT role FROM profiles WHERE id = auth.uid()).
--
-- Run AFTER supabase_rls_policies.sql (helper functions must exist).
-- =============================================================================


-- =============================================================================
-- SECTION 0: Drop existing storage policies (idempotent)
-- =============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
    END LOOP;
END $$;


-- =============================================================================
-- SECTION 1: Assignment Submissions Bucket Policies
-- =============================================================================

-- Students can upload their own submissions
-- Folder path: {student_id}/{assignment_id}/{filename}
CREATE POLICY "Students can upload own submissions"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'assignment-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Students can read their own submissions
CREATE POLICY "Students can read own submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Students can update (replace) their own submissions
CREATE POLICY "Students can update own submissions"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'assignment-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Students can delete their own submissions
CREATE POLICY "Students can delete own submissions"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Teachers can read submissions for assignments in courses they teach
-- Folder path: {student_id}/{assignment_id}/{filename}
-- Validates via assignment_id (2nd folder segment) -> course -> created_by chain
CREATE POLICY "Teachers can read course submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM assignments a
        JOIN courses c ON c.id = a.course_id
        WHERE a.id::text = (storage.foldername(name))[2]
          AND c.created_by = auth.uid()
    )
);

-- Admins can read all submissions in their tenant
CREATE POLICY "Admins can read all submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND get_user_role() = 'admin'
);

-- Parents can read their children's submissions
CREATE POLICY "Parents can read child submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND get_user_role() = 'parent'
    AND EXISTS (
        SELECT 1 FROM student_parents sp
        WHERE sp.parent_id = auth.uid()
          AND sp.student_id::text = (storage.foldername(name))[1]
    )
);


-- =============================================================================
-- SECTION 2: Lesson Materials Bucket Policies
-- =============================================================================

-- Teachers and admins can upload lesson materials
-- Folder path: {course_id}/{module_id}/{filename}
CREATE POLICY "Teachers can upload lesson materials"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'lesson-materials'
    AND get_user_role() IN ('teacher', 'admin')
);

-- Teachers and admins can read all lesson materials
CREATE POLICY "Teachers can read lesson materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND get_user_role() IN ('teacher', 'admin')
);

-- Students can read lesson materials for courses they are enrolled in
-- The folder structure uses course_id as the first segment
CREATE POLICY "Students can read enrolled course materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND EXISTS (
        SELECT 1 FROM course_enrollments ce
        WHERE ce.student_id = auth.uid()
          AND ce.course_id::text = (storage.foldername(name))[1]
    )
);

-- Parents can read lesson materials for their children's courses
CREATE POLICY "Parents can read child course materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND EXISTS (
        SELECT 1 FROM student_parents sp
        JOIN course_enrollments ce ON ce.student_id = sp.student_id
        WHERE sp.parent_id = auth.uid()
          AND ce.course_id::text = (storage.foldername(name))[1]
    )
);

-- Teachers and admins can update lesson materials
CREATE POLICY "Teachers can update lesson materials"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND get_user_role() IN ('teacher', 'admin')
)
WITH CHECK (
    bucket_id = 'lesson-materials'
    AND get_user_role() IN ('teacher', 'admin')
);

-- Teachers and admins can delete lesson materials
CREATE POLICY "Teachers can delete lesson materials"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND get_user_role() IN ('teacher', 'admin')
);


-- =============================================================================
-- SECTION 3: Avatars Bucket Policies
-- =============================================================================

-- Users can upload their own avatar
-- Folder path: {user_id}/{filename}
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Anyone authenticated can read avatars (bucket is public)
CREATE POLICY "Anyone can read avatars"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'avatars');

-- Users can update their own avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);


-- =============================================================================
-- END OF STORAGE POLICIES
-- =============================================================================
