-- =============================================================================
-- WolfWhale LMS - Course Schedules Table
-- =============================================================================
-- Adds persistence for course scheduling (day-of-week / time-of-day slots).
-- One table: course_schedules.
-- Run this migration in the Supabase SQL editor.
-- =============================================================================


-- =============================================================================
-- TABLE: course_schedules
-- =============================================================================
CREATE TABLE IF NOT EXISTS course_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week >= 1 AND day_of_week <= 5),
    start_minute INT NOT NULL CHECK (start_minute >= 0 AND start_minute <= 1439),
    end_minute INT NOT NULL CHECK (end_minute > start_minute AND end_minute <= 1440),
    room_number TEXT NOT NULL DEFAULT '',
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_course_schedules_tenant_id ON course_schedules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_course_schedules_course_id ON course_schedules(course_id);
CREATE INDEX IF NOT EXISTS idx_course_schedules_day_of_week ON course_schedules(day_of_week);

-- Unique constraint: no duplicate time slots for same course on same day
CREATE UNIQUE INDEX IF NOT EXISTS idx_course_schedules_course_day_start
    ON course_schedules(course_id, day_of_week, start_minute);


-- =============================================================================
-- Updated_at trigger
-- =============================================================================

DROP TRIGGER IF EXISTS trg_course_schedules_updated_at ON course_schedules;
CREATE TRIGGER trg_course_schedules_updated_at
    BEFORE UPDATE ON course_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =============================================================================
-- RLS Policies
-- =============================================================================

ALTER TABLE course_schedules ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users in the same tenant can read course schedules
CREATE POLICY "course_schedules_select_tenant"
ON course_schedules FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Teachers can create schedules for their own courses
CREATE POLICY "course_schedules_insert_teacher"
ON course_schedules FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'teacher'
    AND tenant_id = get_user_tenant_id()
    AND EXISTS (
        SELECT 1 FROM courses
        WHERE courses.id = course_schedules.course_id
          AND courses.created_by = auth.uid()
    )
);

-- INSERT: Admins can create schedules in their tenant
CREATE POLICY "course_schedules_insert_admin"
ON course_schedules FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Teachers can update schedules for their own courses
CREATE POLICY "course_schedules_update_teacher"
ON course_schedules FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM courses
        WHERE courses.id = course_schedules.course_id
          AND courses.created_by = auth.uid()
    )
)
WITH CHECK (
    get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM courses
        WHERE courses.id = course_schedules.course_id
          AND courses.created_by = auth.uid()
    )
);

-- UPDATE: Admins can update schedules in their tenant
CREATE POLICY "course_schedules_update_admin"
ON course_schedules FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Teachers can delete schedules for their own courses
CREATE POLICY "course_schedules_delete_teacher"
ON course_schedules FOR DELETE
TO authenticated
USING (
    get_user_role() = 'teacher'
    AND EXISTS (
        SELECT 1 FROM courses
        WHERE courses.id = course_schedules.course_id
          AND courses.created_by = auth.uid()
    )
);

-- DELETE: Admins can delete schedules in their tenant
CREATE POLICY "course_schedules_delete_admin"
ON course_schedules FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);
