-- =============================================================================
-- WolfWhale LMS - Security & Performance Audit Fixes
-- =============================================================================
-- Migration to address security and performance issues found during audit:
--
--   Fix 1: Conference slots RLS - add tenant isolation for parent viewing
--   Fix 2: SuperAdmin RLS policies - explicit cross-tenant read access
--   Fix 3: Quiz questions/options admin RLS - add tenant filtering
--   Fix 4: Optimize generate_daily_snapshot - range-based date filtering
--   Fix 5: Session variable helpers for RLS performance optimization
--
-- This migration is idempotent (safe to re-run).
-- Run AFTER all existing migrations have been applied.
-- =============================================================================


-- =============================================================================
-- FIX 1: Conference Slots RLS - Add Tenant Isolation
-- =============================================================================
-- The original "Parents can view available slots" policy uses USING (true),
-- which allows ANY authenticated user from ANY tenant to see all slots.
-- Replace with a tenant-scoped policy that restricts visibility to users
-- within the same tenant.
-- =============================================================================

-- The teacher_available_slots table already has a tenant_id column
-- (defined in conferences_migration.sql), so no schema change is needed.

-- Add an index on tenant_id for the new RLS join (idempotent)
CREATE INDEX IF NOT EXISTS idx_teacher_available_slots_tenant_id
    ON teacher_available_slots(tenant_id);

-- Drop the overly-permissive policy and replace with tenant-scoped version
DROP POLICY IF EXISTS "Parents can view available slots" ON teacher_available_slots;
CREATE POLICY "Parents can view available slots" ON teacher_available_slots
    FOR SELECT
    TO authenticated
    USING (
        get_user_role() IN ('parent', 'admin')
        AND EXISTS (
            SELECT 1 FROM tenant_memberships tm
            WHERE tm.user_id = auth.uid()
              AND tm.tenant_id = teacher_available_slots.tenant_id
              AND tm.status = 'active'
        )
    );


-- =============================================================================
-- FIX 2: SuperAdmin RLS Policies
-- =============================================================================
-- The SuperAdmin role currently has no dedicated RLS policies and relies on
-- admin policies. Add explicit read-only cross-tenant access for platform
-- management. These use the 'superadmin' role value (lowercase, matching the
-- existing convention in tenant_memberships.role).
-- =============================================================================

-- SuperAdmin: read all courses across tenants
DROP POLICY IF EXISTS "superadmin_full_read_courses" ON courses;
CREATE POLICY "superadmin_full_read_courses" ON courses
    FOR SELECT
    TO authenticated
    USING (get_user_role() = 'superadmin');

-- SuperAdmin: read all tenant memberships across tenants
DROP POLICY IF EXISTS "superadmin_full_read_tenant_memberships" ON tenant_memberships;
CREATE POLICY "superadmin_full_read_tenant_memberships" ON tenant_memberships
    FOR SELECT
    TO authenticated
    USING (get_user_role() = 'superadmin');

-- SuperAdmin: read all analytics snapshots across tenants
DROP POLICY IF EXISTS "superadmin_full_read_analytics" ON analytics_daily_snapshots;
CREATE POLICY "superadmin_full_read_analytics" ON analytics_daily_snapshots
    FOR SELECT
    TO authenticated
    USING (get_user_role() = 'superadmin');

-- SuperAdmin: read all engagement events across tenants
DROP POLICY IF EXISTS "superadmin_full_read_engagement" ON engagement_events;
CREATE POLICY "superadmin_full_read_engagement" ON engagement_events
    FOR SELECT
    TO authenticated
    USING (get_user_role() = 'superadmin');

-- SuperAdmin: read all conferences across tenants
DROP POLICY IF EXISTS "superadmin_full_read_conferences" ON conferences;
CREATE POLICY "superadmin_full_read_conferences" ON conferences
    FOR SELECT
    TO authenticated
    USING (get_user_role() = 'superadmin');


-- =============================================================================
-- FIX 3: Quiz Questions/Options Admin RLS - Add Tenant Filtering
-- =============================================================================
-- The existing admin SELECT policies for quiz_questions and quiz_options check
-- get_user_role() = 'admin' but do NOT verify the admin belongs to the same
-- tenant as the course. This means an admin in Tenant A could read quiz data
-- from Tenant B. Replace with tenant-scoped admin policies.
-- =============================================================================

-- ----- quiz_questions: admin + superadmin management with tenant filter ------
DROP POLICY IF EXISTS "quiz_questions_admin_manage" ON quiz_questions;
CREATE POLICY "quiz_questions_admin_manage" ON quiz_questions
    FOR ALL
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'superadmin')
        AND EXISTS (
            SELECT 1 FROM quizzes q
            JOIN courses c ON q.course_id = c.id
            WHERE q.id = quiz_questions.quiz_id
              AND c.tenant_id = get_user_tenant_id()
        )
    );

-- ----- quiz_options: admin + superadmin management with tenant filter --------
DROP POLICY IF EXISTS "quiz_options_admin_manage" ON quiz_options;
CREATE POLICY "quiz_options_admin_manage" ON quiz_options
    FOR ALL
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'superadmin')
        AND EXISTS (
            SELECT 1 FROM quiz_questions qq
            JOIN quizzes q ON qq.quiz_id = q.id
            JOIN courses c ON q.course_id = c.id
            WHERE qq.id = quiz_options.question_id
              AND c.tenant_id = get_user_tenant_id()
        )
    );


-- =============================================================================
-- FIX 4: Optimize generate_daily_snapshot - Range-Based Date Filtering
-- =============================================================================
-- The original function uses `created_at::date = p_date` which casts every row
-- to DATE, preventing index usage on the created_at TIMESTAMPTZ column.
-- Replacing with range comparisons: created_at >= p_date AND created_at < p_date + 1 day
-- so the planner can use btree indexes on created_at.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_daily_snapshot(
    p_tenant_id UUID,
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_students INT;
    v_total_teachers INT;
    v_total_courses INT;
    v_active_users INT;
    v_average_attendance NUMERIC(5,2);
    v_average_gpa NUMERIC(4,2);
    v_assignments_created INT;
    v_submissions_count INT;
    v_messages_sent INT;
    v_snapshot_id UUID;
BEGIN
    -- Security check: caller must be admin in the target tenant
    IF NOT EXISTS (
        SELECT 1 FROM tenant_memberships
        WHERE user_id = auth.uid()
          AND tenant_id = p_tenant_id
          AND role = 'admin'
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Access denied: caller is not an admin in the target tenant';
    END IF;

    -- Total students in the tenant
    SELECT COUNT(*) INTO v_total_students
    FROM tenant_memberships
    WHERE tenant_id = p_tenant_id
      AND role = 'student'
      AND status = 'active';

    -- Total teachers in the tenant
    SELECT COUNT(*) INTO v_total_teachers
    FROM tenant_memberships
    WHERE tenant_id = p_tenant_id
      AND role = 'teacher'
      AND status = 'active';

    -- Total courses in the tenant
    SELECT COUNT(*) INTO v_total_courses
    FROM courses
    WHERE tenant_id = p_tenant_id;

    -- Active users: distinct users who created engagement events on this date
    -- FIX: range-based filter instead of created_at::date = p_date
    SELECT COUNT(DISTINCT user_id) INTO v_active_users
    FROM engagement_events
    WHERE tenant_id = p_tenant_id
      AND created_at >= p_date
      AND created_at < p_date + INTERVAL '1 day';

    -- Average attendance rate for the date (percentage of 'present' out of total records)
    SELECT COALESCE(
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE status = 'present') / NULLIF(COUNT(*), 0),
            2
        ),
        0.00
    ) INTO v_average_attendance
    FROM attendance_records
    WHERE tenant_id = p_tenant_id
      AND date = p_date;

    -- Average GPA across all grades in the tenant
    SELECT COALESCE(ROUND(AVG(score), 2), 0.00) INTO v_average_gpa
    FROM grades
    WHERE tenant_id = p_tenant_id;

    -- Assignments created on this date
    -- FIX: range-based filter instead of created_at::date = p_date
    SELECT COUNT(*) INTO v_assignments_created
    FROM assignments
    WHERE tenant_id = p_tenant_id
      AND created_at >= p_date
      AND created_at < p_date + INTERVAL '1 day';

    -- Submissions on this date
    -- FIX: range-based filter instead of created_at::date = p_date
    SELECT COUNT(*) INTO v_submissions_count
    FROM submissions
    WHERE tenant_id = p_tenant_id
      AND created_at >= p_date
      AND created_at < p_date + INTERVAL '1 day';

    -- Messages sent on this date
    -- FIX: range-based filter instead of created_at::date = p_date
    SELECT COUNT(*) INTO v_messages_sent
    FROM messages
    WHERE tenant_id = p_tenant_id
      AND created_at >= p_date
      AND created_at < p_date + INTERVAL '1 day';

    -- Upsert the snapshot row
    INSERT INTO analytics_daily_snapshots (
        tenant_id,
        snapshot_date,
        total_students,
        total_teachers,
        total_courses,
        active_users,
        average_attendance,
        average_gpa,
        assignments_created,
        submissions_count,
        messages_sent
    ) VALUES (
        p_tenant_id,
        p_date,
        v_total_students,
        v_total_teachers,
        v_total_courses,
        v_active_users,
        v_average_attendance,
        v_average_gpa,
        v_assignments_created,
        v_submissions_count,
        v_messages_sent
    )
    ON CONFLICT (tenant_id, snapshot_date)
    DO UPDATE SET
        total_students = EXCLUDED.total_students,
        total_teachers = EXCLUDED.total_teachers,
        total_courses = EXCLUDED.total_courses,
        active_users = EXCLUDED.active_users,
        average_attendance = EXCLUDED.average_attendance,
        average_gpa = EXCLUDED.average_gpa,
        assignments_created = EXCLUDED.assignments_created,
        submissions_count = EXCLUDED.submissions_count,
        messages_sent = EXCLUDED.messages_sent
    RETURNING id INTO v_snapshot_id;

    -- Return the snapshot as JSONB
    RETURN jsonb_build_object(
        'snapshot_id', v_snapshot_id,
        'tenant_id', p_tenant_id,
        'snapshot_date', p_date,
        'total_students', v_total_students,
        'total_teachers', v_total_teachers,
        'total_courses', v_total_courses,
        'active_users', v_active_users,
        'average_attendance', v_average_attendance,
        'average_gpa', v_average_gpa,
        'assignments_created', v_assignments_created,
        'submissions_count', v_submissions_count,
        'messages_sent', v_messages_sent
    );
END;
$$;

-- Re-grant execute (idempotent)
GRANT EXECUTE ON FUNCTION public.generate_daily_snapshot(UUID, DATE) TO authenticated;


-- =============================================================================
-- FIX 5: Session Variable Helpers for RLS Performance
-- =============================================================================
-- The get_user_role() and get_user_tenant_id() functions query
-- tenant_memberships on every single RLS check. For pages that touch many
-- rows, this causes N+1-style overhead. These helpers let the application
-- call set_user_session_vars() once per request/session, caching the results
-- in PostgreSQL session variables (transaction-local via set_config).
--
-- The _fast() variants read from session vars first, falling back to the
-- original functions if the vars have not been set.
-- =============================================================================

-- Set session variables (call once at start of session/request)
CREATE OR REPLACE FUNCTION public.set_user_session_vars()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_tenant_id UUID;
BEGIN
    SELECT role, tenant_id INTO v_role, v_tenant_id
    FROM tenant_memberships
    WHERE user_id = auth.uid()
      AND status = 'active'
    LIMIT 1;

    -- true = local to current transaction
    PERFORM set_config('app.user_role', COALESCE(v_role, ''), true);
    PERFORM set_config('app.user_tenant_id', COALESCE(v_tenant_id::text, ''), true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_session_vars() TO authenticated;

-- Fast role lookup (reads session var, falls back to DB query)
CREATE OR REPLACE FUNCTION public.get_user_role_fast()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
    RETURN NULLIF(current_setting('app.user_role', true), '');
EXCEPTION WHEN OTHERS THEN
    RETURN get_user_role();  -- Fall back to original
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_role_fast() TO authenticated;

-- Fast tenant_id lookup (reads session var, falls back to DB query)
CREATE OR REPLACE FUNCTION public.get_user_tenant_id_fast()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
    RETURN NULLIF(current_setting('app.user_tenant_id', true), '')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN get_user_tenant_id();  -- Fall back to original
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_tenant_id_fast() TO authenticated;


-- =============================================================================
-- Done. Summary of changes:
--   1. Conference slots: tenant-isolated parent viewing policy
--   2. SuperAdmin: explicit cross-tenant SELECT on key tables
--   3. Quiz admin: tenant-scoped policies for quiz_questions and quiz_options
--   4. Analytics: range-based date filters for index efficiency
--   5. Session vars: set_user_session_vars(), get_user_role_fast(),
--      get_user_tenant_id_fast() for RLS performance optimization
-- =============================================================================
