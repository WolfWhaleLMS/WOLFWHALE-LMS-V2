-- =============================================================================
-- WolfWhale LMS - Data Export RPC Function
-- =============================================================================
-- Provides a GDPR-style data export function that aggregates all user data
-- into a single JSONB object. Users can export their own data; admins can
-- export data for any user in their tenant.
-- Run this migration in the Supabase SQL editor.
-- =============================================================================


-- =============================================================================
-- RPC Function: export_user_data
-- =============================================================================
-- Aggregates: profile, tenant_memberships, course_enrollments, grades,
-- submissions, attendance_records, quiz_attempts, messages (sent),
-- notifications, audit_logs, student_achievements.
-- Logs the export action in audit_logs.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.export_user_data(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_tenant_id UUID;
    v_target_tenant_id UUID;
    v_result JSONB;
    v_profile JSONB;
    v_memberships JSONB;
    v_enrollments JSONB;
    v_grades JSONB;
    v_submissions JSONB;
    v_attendance JSONB;
    v_quiz_attempts JSONB;
    v_messages JSONB;
    v_notifications JSONB;
    v_audit_logs JSONB;
    v_achievements JSONB;
BEGIN
    -- Identify the caller
    v_caller_id := auth.uid();
    v_caller_role := (
        SELECT role FROM tenant_memberships
        WHERE user_id = v_caller_id AND status = 'active'
        LIMIT 1
    );
    v_caller_tenant_id := (
        SELECT tenant_id FROM tenant_memberships
        WHERE user_id = v_caller_id AND status = 'active'
        LIMIT 1
    );

    -- Security check: caller must be the target user OR an admin in the same tenant
    IF v_caller_id != target_user_id THEN
        -- Caller is not the target user; check if caller is admin in same tenant
        v_target_tenant_id := (
            SELECT tenant_id FROM tenant_memberships
            WHERE user_id = target_user_id AND status = 'active'
            LIMIT 1
        );

        IF v_caller_role != 'admin' OR v_caller_tenant_id != v_target_tenant_id THEN
            RAISE EXCEPTION 'Access denied: you can only export your own data or data for users in your tenant (admin only)';
        END IF;
    END IF;

    -- Profile
    SELECT COALESCE(to_jsonb(p), '{}'::jsonb) INTO v_profile
    FROM profiles p
    WHERE p.id = target_user_id;

    -- Tenant memberships
    SELECT COALESCE(jsonb_agg(to_jsonb(tm)), '[]'::jsonb) INTO v_memberships
    FROM tenant_memberships tm
    WHERE tm.user_id = target_user_id;

    -- Course enrollments
    SELECT COALESCE(jsonb_agg(to_jsonb(ce)), '[]'::jsonb) INTO v_enrollments
    FROM course_enrollments ce
    WHERE ce.student_id = target_user_id;

    -- Grades
    SELECT COALESCE(jsonb_agg(to_jsonb(g)), '[]'::jsonb) INTO v_grades
    FROM grades g
    WHERE g.student_id = target_user_id;

    -- Submissions
    SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb) INTO v_submissions
    FROM submissions s
    WHERE s.student_id = target_user_id;

    -- Attendance records
    SELECT COALESCE(jsonb_agg(to_jsonb(ar)), '[]'::jsonb) INTO v_attendance
    FROM attendance_records ar
    WHERE ar.student_id = target_user_id;

    -- Quiz attempts
    SELECT COALESCE(jsonb_agg(to_jsonb(qa)), '[]'::jsonb) INTO v_quiz_attempts
    FROM quiz_attempts qa
    WHERE qa.student_id = target_user_id;

    -- Messages (sent by the user)
    SELECT COALESCE(jsonb_agg(to_jsonb(m)), '[]'::jsonb) INTO v_messages
    FROM messages m
    WHERE m.sender_id = target_user_id;

    -- Notifications
    SELECT COALESCE(jsonb_agg(to_jsonb(n)), '[]'::jsonb) INTO v_notifications
    FROM notifications n
    WHERE n.user_id = target_user_id;

    -- Audit logs
    SELECT COALESCE(jsonb_agg(to_jsonb(al)), '[]'::jsonb) INTO v_audit_logs
    FROM audit_logs al
    WHERE al.user_id = target_user_id;

    -- Student achievements
    SELECT COALESCE(jsonb_agg(to_jsonb(sa)), '[]'::jsonb) INTO v_achievements
    FROM student_achievements sa
    WHERE sa.student_id = target_user_id;

    -- Build the result object
    v_result := jsonb_build_object(
        'exported_at', now(),
        'target_user_id', target_user_id,
        'profile', v_profile,
        'tenant_memberships', v_memberships,
        'course_enrollments', v_enrollments,
        'grades', v_grades,
        'submissions', v_submissions,
        'attendance_records', v_attendance,
        'quiz_attempts', v_quiz_attempts,
        'messages_sent', v_messages,
        'notifications', v_notifications,
        'audit_logs', v_audit_logs,
        'student_achievements', v_achievements
    );

    -- Log the export action in audit_logs
    INSERT INTO audit_logs (
        tenant_id,
        user_id,
        action,
        entity_type,
        entity_id,
        metadata,
        created_at
    ) VALUES (
        COALESCE(v_caller_tenant_id, v_target_tenant_id),
        v_caller_id,
        'data_export',
        'user',
        target_user_id,
        jsonb_build_object(
            'exported_by', v_caller_id,
            'target_user_id', target_user_id,
            'exported_at', now()
        ),
        now()
    );

    RETURN v_result;
END;
$$;

-- Grant execute to authenticated users (security check is inside the function)
GRANT EXECUTE ON FUNCTION public.export_user_data(UUID) TO authenticated;
