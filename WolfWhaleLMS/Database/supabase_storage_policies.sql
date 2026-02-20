-- =============================================================================
-- WolfWhale LMS - Supabase Storage Bucket & Policies
-- =============================================================================
-- Creates storage buckets for file uploads and applies RLS-style policies.
-- Buckets:
--   - assignment-submissions: Student-uploaded assignment files
--   - lesson-materials: Teacher-uploaded lesson content (PDFs, images, etc.)
--   - avatars: User profile avatars
--
-- Folder conventions:
--   assignment-submissions/{student_id}/{assignment_id}/{filename}
--   lesson-materials/{course_id}/{module_id}/{filename}
--   avatars/{user_id}/{filename}
--
-- Run AFTER the main table RLS migration.
-- =============================================================================

-- =============================================================================
-- SECTION 1: Create Buckets
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    (
        'assignment-submissions',
        'assignment-submissions',
        false,
        52428800,  -- 50 MB max file size
        ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/gif', 'image/webp',
              'text/plain', 'application/msword',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'application/vnd.ms-excel',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'application/vnd.ms-powerpoint',
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
              'video/mp4', 'audio/mpeg']
    ),
    (
        'lesson-materials',
        'lesson-materials',
        false,
        104857600,  -- 100 MB max for lesson materials
        ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/gif', 'image/webp',
              'text/plain', 'application/msword',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'video/mp4', 'audio/mpeg', 'application/zip']
    ),
    (
        'avatars',
        'avatars',
        true,  -- Public so avatar URLs work without auth
        5242880,  -- 5 MB max for avatars
        ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    )
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- SECTION 2: Assignment Submissions Bucket Policies
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

-- Teachers can read all submissions in their courses
-- We check via the assignment -> course -> teacher_id chain
CREATE POLICY "Teachers can read course submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) = 'Teacher'
);

-- Admins can read all submissions
CREATE POLICY "Admins can read all submissions"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'assignment-submissions'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) = 'Admin'
);

-- =============================================================================
-- SECTION 3: Lesson Materials Bucket Policies
-- =============================================================================

-- Teachers can upload lesson materials for their courses
-- Folder path: {course_id}/{module_id}/{filename}
CREATE POLICY "Teachers can upload lesson materials"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'lesson-materials'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('Teacher', 'Admin')
);

-- Teachers can read lesson materials they uploaded
CREATE POLICY "Teachers can read lesson materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('Teacher', 'Admin')
);

-- Students can read lesson materials for courses they are enrolled in
-- The folder structure uses course_id as the first segment
CREATE POLICY "Students can read enrolled course materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND EXISTS (
        SELECT 1 FROM enrollments e
        WHERE e.student_id = auth.uid()
          AND e.course_id::text = (storage.foldername(name))[1]
    )
);

-- Parents can read lesson materials for their children's courses
CREATE POLICY "Parents can read child course materials"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND EXISTS (
        SELECT 1 FROM parent_child_links pcl
        JOIN enrollments e ON e.student_id = pcl.child_id
        WHERE pcl.parent_id = auth.uid()
          AND e.course_id::text = (storage.foldername(name))[1]
    )
);

-- Teachers can update their own lesson materials
CREATE POLICY "Teachers can update lesson materials"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('Teacher', 'Admin')
)
WITH CHECK (
    bucket_id = 'lesson-materials'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('Teacher', 'Admin')
);

-- Teachers can delete their own lesson materials
CREATE POLICY "Teachers can delete lesson materials"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'lesson-materials'
    AND (
        SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('Teacher', 'Admin')
);

-- =============================================================================
-- SECTION 4: Avatars Bucket Policies
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

-- Anyone can read avatars (bucket is public)
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
