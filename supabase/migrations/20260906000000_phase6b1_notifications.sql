-- ============================================================================
-- PRAHAR Phase 6B-1: Persistent In-App Notification System Migration
-- Additive migration creating public.notifications table with PostgreSQL RLS
-- ============================================================================

-- Ensure extensions schema is in search_path
SET search_path TO public, extensions;

-- 1. Create Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    notification_id TEXT UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    zone_id TEXT REFERENCES public.zones(id) ON DELETE SET NULL,
    alert_id UUID REFERENCES public.alerts(id) ON DELETE SET NULL,
    action_id TEXT REFERENCES public.remediation_actions(action_id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN (
        'ALERT_CREATED',
        'RISK_DETECTED',
        'ACTION_RECOMMENDED',
        'ACTION_APPROVED',
        'ACTION_EXECUTED',
        'VERIFICATION_COMPLETED',
        'VERIFICATION_FAILED',
        'SYSTEM'
    )),
    severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'INFO')),
    title TEXT NOT NULL,
    title_hi TEXT,
    message TEXT NOT NULL,
    message_hi TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    deduplication_key TEXT
);

-- 2. Performance & Query Indices
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_farm
    ON public.notifications (farm_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_zone
    ON public.notifications (zone_id);

CREATE INDEX IF NOT EXISTS idx_notifications_alert
    ON public.notifications (alert_id);

CREATE INDEX IF NOT EXISTS idx_notifications_action
    ON public.notifications (action_id);

-- Enforce strict database-level deduplication per user & event key
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_user_dedup_unique
    ON public.notifications (user_id, deduplication_key)
    WHERE deduplication_key IS NOT NULL;

-- 3. Grants & Role Permissions (Defense-in-depth adhering to 20260905000003)
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO service_role;

-- 4. Row Level Security (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Farmers read ONLY their own notifications. Experts and Admins see relevant notifications.
CREATE POLICY "Notifications select policy" ON public.notifications
    FOR SELECT USING (
        user_id = auth.uid()
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Farmers mark read ONLY their own notifications. Experts and Admins can update.
CREATE POLICY "Notifications update policy" ON public.notifications
    FOR UPDATE USING (
        user_id = auth.uid()
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Backend system, service_role, and experts/admins can insert notifications
CREATE POLICY "Notifications insert policy" ON public.notifications
    FOR INSERT WITH CHECK (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
        OR user_id = auth.uid()
    );

-- Admins and service-role can delete notifications
CREATE POLICY "Notifications delete policy" ON public.notifications
    FOR DELETE USING (
        public.get_user_role() = 'ADMIN'
        OR auth.role() = 'service_role'
    );
