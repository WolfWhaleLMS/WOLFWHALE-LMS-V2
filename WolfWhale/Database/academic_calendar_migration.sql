-- =============================================================================
-- WolfWhale LMS - Academic Calendar Tables
-- =============================================================================
-- Adds persistence for academic terms, events, and grading periods.
-- Three tables: academic_terms, academic_events, grading_periods.
-- Run this migration in the Supabase SQL editor.
-- =============================================================================


-- =============================================================================
-- TABLE: academic_terms
-- =============================================================================
CREATE TABLE IF NOT EXISTS academic_terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    type TEXT NOT NULL DEFAULT 'Semester',
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_academic_terms_dates CHECK (end_date > start_date)
);


-- =============================================================================
-- TABLE: academic_events
-- =============================================================================
CREATE TABLE IF NOT EXISTS academic_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    event_date DATE NOT NULL,
    end_date DATE,
    type TEXT NOT NULL DEFAULT 'School Event',
    description TEXT,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- TABLE: grading_periods
-- =============================================================================
CREATE TABLE IF NOT EXISTS grading_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    term_id UUID NOT NULL REFERENCES academic_terms(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    grade_submission_deadline TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- Indexes
-- =============================================================================

-- academic_terms indexes
CREATE INDEX IF NOT EXISTS idx_academic_terms_tenant_id ON academic_terms(tenant_id);
CREATE INDEX IF NOT EXISTS idx_academic_terms_start_date ON academic_terms(start_date);
CREATE INDEX IF NOT EXISTS idx_academic_terms_end_date ON academic_terms(end_date);

-- academic_events indexes
CREATE INDEX IF NOT EXISTS idx_academic_events_tenant_id ON academic_events(tenant_id);
CREATE INDEX IF NOT EXISTS idx_academic_events_event_date ON academic_events(event_date);
CREATE INDEX IF NOT EXISTS idx_academic_events_end_date ON academic_events(end_date);

-- grading_periods indexes
CREATE INDEX IF NOT EXISTS idx_grading_periods_tenant_id ON grading_periods(tenant_id);
CREATE INDEX IF NOT EXISTS idx_grading_periods_term_id ON grading_periods(term_id);
CREATE INDEX IF NOT EXISTS idx_grading_periods_start_date ON grading_periods(start_date);
CREATE INDEX IF NOT EXISTS idx_grading_periods_end_date ON grading_periods(end_date);


-- =============================================================================
-- Updated_at triggers
-- =============================================================================

DROP TRIGGER IF EXISTS trg_academic_terms_updated_at ON academic_terms;
CREATE TRIGGER trg_academic_terms_updated_at
    BEFORE UPDATE ON academic_terms
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_academic_events_updated_at ON academic_events;
CREATE TRIGGER trg_academic_events_updated_at
    BEFORE UPDATE ON academic_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_grading_periods_updated_at ON grading_periods;
CREATE TRIGGER trg_grading_periods_updated_at
    BEFORE UPDATE ON grading_periods
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- =============================================================================
-- RLS Policies
-- =============================================================================

ALTER TABLE academic_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE grading_periods ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- academic_terms policies
-- -----------------------------------------------------------------------------

-- SELECT: All authenticated users can read academic terms in their tenant
CREATE POLICY "academic_terms_select_tenant"
ON academic_terms FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Only admins can create academic terms in their tenant
CREATE POLICY "academic_terms_insert_admin"
ON academic_terms FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Only admins can update academic terms in their tenant
CREATE POLICY "academic_terms_update_admin"
ON academic_terms FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Only admins can delete academic terms in their tenant
CREATE POLICY "academic_terms_delete_admin"
ON academic_terms FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- -----------------------------------------------------------------------------
-- academic_events policies
-- -----------------------------------------------------------------------------

-- SELECT: All authenticated users can read academic events in their tenant
CREATE POLICY "academic_events_select_tenant"
ON academic_events FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Only admins can create academic events in their tenant
CREATE POLICY "academic_events_insert_admin"
ON academic_events FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Only admins can update academic events in their tenant
CREATE POLICY "academic_events_update_admin"
ON academic_events FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Only admins can delete academic events in their tenant
CREATE POLICY "academic_events_delete_admin"
ON academic_events FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- -----------------------------------------------------------------------------
-- grading_periods policies
-- -----------------------------------------------------------------------------

-- SELECT: All authenticated users can read grading periods in their tenant
CREATE POLICY "grading_periods_select_tenant"
ON grading_periods FOR SELECT
TO authenticated
USING (tenant_id = get_user_tenant_id());

-- INSERT: Only admins can create grading periods in their tenant
CREATE POLICY "grading_periods_insert_admin"
ON grading_periods FOR INSERT
TO authenticated
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- UPDATE: Only admins can update grading periods in their tenant
CREATE POLICY "grading_periods_update_admin"
ON grading_periods FOR UPDATE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
)
WITH CHECK (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);

-- DELETE: Only admins can delete grading periods in their tenant
CREATE POLICY "grading_periods_delete_admin"
ON grading_periods FOR DELETE
TO authenticated
USING (
    get_user_role() = 'admin'
    AND tenant_id = get_user_tenant_id()
);
