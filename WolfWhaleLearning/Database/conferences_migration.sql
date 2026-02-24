-- =============================================================================
-- WolfWhale LMS - Conference Scheduling Tables
-- =============================================================================
-- Adds persistence for parent-teacher conference scheduling.
-- Two tables: teacher_available_slots and conferences.
-- Run this migration in the Supabase SQL editor.
-- =============================================================================

-- Teacher Available Slots
CREATE TABLE IF NOT EXISTS teacher_available_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    slot_date TIMESTAMPTZ NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 15,
    is_booked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Conferences
CREATE TABLE IF NOT EXISTS conferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    teacher_name TEXT NOT NULL DEFAULT '',
    parent_name TEXT NOT NULL DEFAULT '',
    child_name TEXT NOT NULL DEFAULT '',
    conference_date TIMESTAMPTZ NOT NULL,
    duration INT NOT NULL DEFAULT 15,
    status TEXT NOT NULL DEFAULT 'requested',
    notes TEXT,
    location TEXT,
    slot_id UUID REFERENCES teacher_available_slots(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_teacher_available_slots_teacher_id ON teacher_available_slots(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_available_slots_slot_date ON teacher_available_slots(slot_date);
CREATE INDEX IF NOT EXISTS idx_teacher_available_slots_is_booked ON teacher_available_slots(is_booked);
CREATE INDEX IF NOT EXISTS idx_conferences_parent_id ON conferences(parent_id);
CREATE INDEX IF NOT EXISTS idx_conferences_teacher_id ON conferences(teacher_id);
CREATE INDEX IF NOT EXISTS idx_conferences_status ON conferences(status);
CREATE INDEX IF NOT EXISTS idx_conferences_conference_date ON conferences(conference_date);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_teacher_available_slots_updated_at ON teacher_available_slots;
CREATE TRIGGER trg_teacher_available_slots_updated_at
    BEFORE UPDATE ON teacher_available_slots
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_conferences_updated_at ON conferences;
CREATE TRIGGER trg_conferences_updated_at
    BEFORE UPDATE ON conferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies
ALTER TABLE teacher_available_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE conferences ENABLE ROW LEVEL SECURITY;

-- Teachers can manage their own slots; parents can read all slots
CREATE POLICY "Teachers manage own slots"
    ON teacher_available_slots
    FOR ALL
    USING (teacher_id = auth.uid())
    WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "Parents can view available slots"
    ON teacher_available_slots
    FOR SELECT
    USING (true);

-- Parents and teachers can see their own conferences
CREATE POLICY "Users see own conferences"
    ON conferences
    FOR SELECT
    USING (parent_id = auth.uid() OR teacher_id = auth.uid());

-- Parents can create conference requests
CREATE POLICY "Parents create conferences"
    ON conferences
    FOR INSERT
    WITH CHECK (parent_id = auth.uid());

-- Both parties can update conferences (status changes)
CREATE POLICY "Users update own conferences"
    ON conferences
    FOR UPDATE
    USING (parent_id = auth.uid() OR teacher_id = auth.uid());
