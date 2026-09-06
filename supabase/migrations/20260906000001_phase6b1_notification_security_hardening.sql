-- ============================================================================
-- PRAHAR Phase 6B-1: Notification Security Hardening Migration
-- 1. Enforce Farm/Tenant authorization boundary for Experts in RLS
-- 2. Enforce Notification Write Security (Service-role-only INSERT, Read-state-only UPDATE)
-- ============================================================================

SET search_path TO public, extensions;

-- 1. Expert Farm Assignments (Tenant Authorization Boundary for Experts)
CREATE TABLE IF NOT EXISTS public.expert_farm_assignments (
    expert_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (expert_id, farm_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_farm_assignments_expert
    ON public.expert_farm_assignments(expert_id);

CREATE INDEX IF NOT EXISTS idx_expert_farm_assignments_farm
    ON public.expert_farm_assignments(farm_id);

ALTER TABLE public.expert_farm_assignments ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.expert_farm_assignments TO authenticated;
GRANT ALL ON public.expert_farm_assignments TO service_role;

DROP POLICY IF EXISTS "Expert farm assignments select policy" ON public.expert_farm_assignments;
CREATE POLICY "Expert farm assignments select policy" ON public.expert_farm_assignments
    FOR SELECT USING (
        expert_id = auth.uid()
        OR public.get_user_role() = 'ADMIN'
    );

-- 2. Hardened RLS Policies for Notifications
-- Recreate Notifications SELECT policy with strict tenant/farm boundary
DROP POLICY IF EXISTS "Notifications select policy" ON public.notifications;
CREATE POLICY "Notifications select policy" ON public.notifications
    FOR SELECT USING (
        -- Farmer isolation: Farmers see ONLY their own notifications
        (user_id = auth.uid())
        -- Admin: Global visibility for system administrators
        OR (public.get_user_role() = 'ADMIN')
        -- Expert: Restricted to farms the expert is explicitly authorized to access
        OR (
            public.get_user_role() = 'EXPERT'
            AND farm_id IN (
                SELECT efa.farm_id FROM public.expert_farm_assignments efa
                WHERE efa.expert_id = auth.uid()
            )
        )
    );

-- Notification Creation: Backend service-role ONLY. Clients/farmers CANNOT create notifications.
DROP POLICY IF EXISTS "Notifications insert policy" ON public.notifications;
CREATE POLICY "Notifications insert policy" ON public.notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'service_role'
    );

-- Notification Update: Farmers can only update their own notifications (and only read-state via column privileges & trigger)
DROP POLICY IF EXISTS "Notifications update policy" ON public.notifications;
CREATE POLICY "Notifications update policy" ON public.notifications
    FOR UPDATE USING (
        user_id = auth.uid()
        OR public.get_user_role() = 'ADMIN'
    );

-- 3. Column-Level Permissions: Restrict authenticated role to ONLY update read-state fields
REVOKE ALL ON public.notifications FROM anon;
REVOKE INSERT, DELETE ON public.notifications FROM authenticated;
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (is_read, read_at) ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

-- 4. Defense-in-depth: Immutability Trigger Guard
-- Guarantees notification content, ownership, farm, and severity cannot be tampered with
CREATE OR REPLACE FUNCTION public.guard_notification_immutability()
RETURNS TRIGGER AS $$
BEGIN
  -- Service role and Admins bypass immutability guard
  IF auth.role() = 'service_role' OR public.get_user_role() = 'ADMIN' THEN
    RETURN NEW;
  END IF;

  -- Farmers/Authenticated users may ONLY modify is_read and read_at
  IF (NEW.id IS DISTINCT FROM OLD.id) OR
     (NEW.notification_id IS DISTINCT FROM OLD.notification_id) OR
     (NEW.user_id IS DISTINCT FROM OLD.user_id) OR
     (NEW.farm_id IS DISTINCT FROM OLD.farm_id) OR
     (NEW.zone_id IS DISTINCT FROM OLD.zone_id) OR
     (NEW.alert_id IS DISTINCT FROM OLD.alert_id) OR
     (NEW.action_id IS DISTINCT FROM OLD.action_id) OR
     (NEW.type IS DISTINCT FROM OLD.type) OR
     (NEW.severity IS DISTINCT FROM OLD.severity) OR
     (NEW.title IS DISTINCT FROM OLD.title) OR
     (NEW.title_hi IS DISTINCT FROM OLD.title_hi) OR
     (NEW.message IS DISTINCT FROM OLD.message) OR
     (NEW.message_hi IS DISTINCT FROM OLD.message_hi) OR
     (NEW.created_at IS DISTINCT FROM OLD.created_at) OR
     (NEW.metadata IS DISTINCT FROM OLD.metadata) OR
     (NEW.deduplication_key IS DISTINCT FROM OLD.deduplication_key) THEN
    RAISE EXCEPTION 'Access Denied: Notification content and ownership are immutable. Only is_read and read_at may be updated.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_guard_notification_immutability ON public.notifications;
CREATE TRIGGER trg_guard_notification_immutability
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.guard_notification_immutability();
