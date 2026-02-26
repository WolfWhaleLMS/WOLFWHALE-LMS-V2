-- =============================================================================
-- WolfWhale LMS - Analytics Tables & Functions
-- =============================================================================
-- Adds persistence for daily analytics snapshots and engagement event tracking.
-- Two tables: analytics_daily_snapshots, engagement_events.
-- One RPC function: generate_daily_snapshot.
-- Run this migration in the Supabase SQL editor.
-- =============================================================================


-- =============================================================================
-- TABLE: analytics_daily_snapshots
-- =============================================================================
CREATE TABLE IF NOT EXISTS analytics_daily_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_students INT NOT NULL DEFAULT 0,
    total_teachers INT NOT NULL DEFAULT 0,
    total_courses INT NOT NULL DEFAULT 0,
    active_users INT NOT NULL DEFAULT 0,
    average_attendance NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    average_gpa NUMERIC(4,2) NOT NULL DEFAULT 0.00,
    assignments_created INT NOT NULL DEFAULT 0,
    submissions_count INT NOT NULL DEFAULT 0,
    messages_sent INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_analytics_daily_snapshots_tenant_date UNIQUE (tenant_id, snapshot_date)
);


-- =============================================================================
-- TABLE: engagement_events
-- =============================================================================
CREATE TABLE IF NOT EXISTS engagement_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- Indexes
-- =============================================================================

-- analytics_daily_snapshots indexes
CREATE INDEX IF NOT EXISTS idx_analytics_daily_snapshots_tenant_id ON analytics_daily_snapshots(tenant_id);
CREATE INDEX IF NOT EXISTS idx_analytics_daily_snapshots_snapshot_date ON analytics_daily_snapshots(snapshot_date);

-- engagement_events indexes
CREATE INDEX IF NOT EXISTS idx_engagement_events_tenant_id ON engagement_events(tenant_id);
CREATE INDEX IF NOT EXISTS idx_engagement_events_user_id ON engagement_events(user_id);
CREATE INDEX IF NOT EXISTS idx_engagement_events_event_type ON engagement_events(event_type);
CREATE INDEX IF NOT EXISTS idx_engagement_events_created_at ON engagement_events(created_at);


-- =============================================================================
-- RLS Policies
-- =============================================================================

ALTER TABLE analytics_daily_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement_events ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- analytics_daily_snapshots policies
-- -----------------------------------------------------------------------------

-- SELECT: Only admins can read analytics snapshots in their tenant
CREATE POLICY "analytics_daily_snapshots_select_admin"
ON analytics_daily_snapshots FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Only admins (or service role via RPC) can create snapshots
CREATE POLICY "analytics_daily_snapshots_insert_admin"
ON analytics_daily_snapshots FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- -----------------------------------------------------------------------------
-- engagement_events policies
-- -----------------------------------------------------------------------------

-- SELECT: Admins can read all engagement events in their tenant
CREATE POLICY "engagement_events_select_admin"
ON engagement_events FOR SELECT
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- INSERT: Authenticated users can insert their own engagement events
CREATE POLICY "engagement_events_insert_own"
ON engagement_events FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
    AND tenant_id = get_user_tenant_id()
);


-- =============================================================================
-- RPC Function: generate_daily_snapshot
-- =============================================================================
-- Aggregates counts from tenant_memberships, courses, assignments, submissions,
-- messages, and engagement_events to produce a daily analytics snapshot row.
-- Uses INSERT ... ON CONFLICT to upsert for the given tenant + date.
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
    SELECT COUNT(DISTINCT user_id) INTO v_active_users
    FROM engagement_events
    WHERE tenant_id = p_tenant_id
      AND created_at::date = p_date;

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
    SELECT COUNT(*) INTO v_assignments_created
    FROM assignments
    WHERE tenant_id = p_tenant_id
      AND created_at::date = p_date;

    -- Submissions on this date
    SELECT COUNT(*) INTO v_submissions_count
    FROM submissions
    WHERE tenant_id = p_tenant_id
      AND created_at::date = p_date;

    -- Messages sent on this date
    SELECT COUNT(*) INTO v_messages_sent
    FROM messages
    WHERE tenant_id = p_tenant_id
      AND created_at::date = p_date;

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

-- Grant execute to authenticated users (admin check is inside the function)
GRANT EXECUTE ON FUNCTION public.generate_daily_snapshot(UUID, DATE) TO authenticated;
