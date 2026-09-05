-- ============================================================================
-- PRAHAR Engineering Foundation — Phase 3 Production Data Layer & RLS Migration
-- Aligned with PRAHAR Engineering Specification v1.0 Sections 6, 8, 9, 14 & 16.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Profiles & Roles (Supabase Auth Integration)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'FARMER' CHECK (role IN ('FARMER', 'EXPERT', 'ADMIN')),
    farmer_id UUID REFERENCES public.farmers(id) ON DELETE SET NULL,
    assigned_cluster TEXT DEFAULT 'CLUSTER-DEMO-01',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for profile lookups
CREATE INDEX IF NOT EXISTS idx_profiles_farmer ON public.profiles(farmer_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Helper function to fetch user role safely from JWT auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Helper function to fetch farmer_id from current profile
CREATE OR REPLACE FUNCTION public.get_user_farmer_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT farmer_id FROM public.profiles WHERE id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- 2. Schema Alignment for Phase 2 & 3 Entities
-- ----------------------------------------------------------------------------

-- Alter alerts table to include bilingual fields, deduplication, and occurrence tracking
ALTER TABLE public.alerts
    ADD COLUMN IF NOT EXISTS message_hi TEXT,
    ADD COLUMN IF NOT EXISTS recommended_action_hi TEXT,
    ADD COLUMN IF NOT EXISTS deduplication_key TEXT,
    ADD COLUMN IF NOT EXISTS last_occurrence_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS occurrence_count INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_alerts_dedup_key ON public.alerts(deduplication_key, last_occurrence_at DESC);

-- Remediation Interventions (tracks approved physical irrigation/action lifecycle)
CREATE TABLE IF NOT EXISTS public.remediation_actions (
    action_id TEXT PRIMARY KEY,
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN ('IRRIGATE', 'INSPECT', 'SPRAY_RESERVED', 'MONITOR')),
    duration_seconds INTEGER NOT NULL DEFAULT 30,
    volume_liters NUMERIC(6, 2) NOT NULL DEFAULT 7.5,
    approved_by TEXT NOT NULL,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expert_note TEXT,
    status TEXT NOT NULL DEFAULT 'APPROVED' CHECK (status IN ('PENDING_APPROVAL', 'APPROVED', 'EXECUTING', 'COMPLETED', 'FAILED')),
    execution_cmd_id TEXT REFERENCES public.rover_commands(command_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remediation_actions_zone ON public.remediation_actions(zone_id, created_at DESC);

-- Closed-Loop Remediation Verification Records (Pre vs Post metrics comparison)
CREATE TABLE IF NOT EXISTS public.remediation_verifications (
    verification_id TEXT PRIMARY KEY,
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    action_id TEXT NOT NULL REFERENCES public.remediation_actions(action_id) ON DELETE CASCADE,
    pre_moisture NUMERIC(5, 2) NOT NULL,
    post_moisture NUMERIC(5, 2) NOT NULL,
    moisture_delta NUMERIC(5, 2) NOT NULL,
    pre_detection JSONB,
    post_detection JSONB,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    verification_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    summary_en TEXT NOT NULL,
    summary_hi TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remediation_verifications_zone ON public.remediation_verifications(zone_id, verification_timestamp DESC);

-- Expert Audit Trail (Immutable log of all expert triage & approvals)
CREATE TABLE IF NOT EXISTS public.expert_audit_records (
    audit_id TEXT PRIMARY KEY,
    actor TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    alert_id TEXT,
    action TEXT NOT NULL CHECK (action IN ('CONFIRM', 'CORRECT', 'ESCALATE', 'APPROVE_INTERVENTION', 'REJECT_INTERVENTION')),
    previous_state TEXT NOT NULL,
    new_state TEXT NOT NULL,
    expert_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_audit_records_zone ON public.expert_audit_records(zone_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_expert_audit_records_alert ON public.expert_audit_records(alert_id);

-- Upgrade Offline Sync Events to 5-State Machine & Idempotency
ALTER TABLE public.offline_sync_events
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SYNCING', 'SYNCED', 'FAILED', 'CONFLICT')),
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS retry_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_error TEXT;

-- Enforce unique idempotency_key where present
CREATE UNIQUE INDEX IF NOT EXISTS idx_offline_sync_idempotency ON public.offline_sync_events(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_offline_sync_status ON public.offline_sync_events(status, buffered_at ASC);

-- ----------------------------------------------------------------------------
-- 3. Row Level Security (RLS) Implementation
-- ----------------------------------------------------------------------------

-- Enable RLS on all domain tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rover_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rover_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remediation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remediation_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expert_audit_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offline_sync_events ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view their own profile; Admins can view all
CREATE POLICY "Profiles viewable by self or admin" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR public.get_user_role() = 'ADMIN');

CREATE POLICY "Profiles updatable by self or admin" ON public.profiles
    FOR UPDATE USING (auth.uid() = id OR public.get_user_role() = 'ADMIN');

-- Farmers: Farmers see only themselves; Experts and Admins can see all
CREATE POLICY "Farmers access policy" ON public.farmers
    FOR SELECT USING (
        id = public.get_user_farmer_id()
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Farms: Farmers only see their own farms; Experts and Admins see all
CREATE POLICY "Farms access policy" ON public.farms
    FOR SELECT USING (
        farmer_id = public.get_user_farmer_id()
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

CREATE POLICY "Farms modification policy" ON public.farms
    FOR ALL USING (
        farmer_id = public.get_user_farmer_id()
        OR public.get_user_role() = 'ADMIN'
    );

-- Zones: Accessible if farm belongs to farmer or user is expert/admin
CREATE POLICY "Zones access policy" ON public.zones
    FOR SELECT USING (
        farm_id IN (SELECT id FROM public.farms WHERE farmer_id = public.get_user_farmer_id())
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Sensor Readings: Accessible through zone ownership or expert/admin
CREATE POLICY "Sensor readings access policy" ON public.sensor_readings
    FOR SELECT USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

CREATE POLICY "Sensor readings insert policy" ON public.sensor_readings
    FOR INSERT WITH CHECK (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );

-- Detections: Accessible through zone ownership or expert/admin
CREATE POLICY "Detections access policy" ON public.detections
    FOR SELECT USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

CREATE POLICY "Detections insert policy" ON public.detections
    FOR INSERT WITH CHECK (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );

-- Alerts: Farmers see alerts for their zones; Experts/Admins see all alerts
CREATE POLICY "Alerts select policy" ON public.alerts
    FOR SELECT USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

CREATE POLICY "Alerts update policy" ON public.alerts
    FOR UPDATE USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Remediation Actions: Farmer / Expert access
CREATE POLICY "Remediation actions select policy" ON public.remediation_actions
    FOR SELECT USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

CREATE POLICY "Remediation actions insert policy" ON public.remediation_actions
    FOR INSERT WITH CHECK (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Verifications: Farmer / Expert access
CREATE POLICY "Remediation verifications select policy" ON public.remediation_verifications
    FOR SELECT USING (
        zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
        OR public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Expert Audit Records: Immutable. Experts and Admins can view/insert. Farmers can view audits for their zones.
CREATE POLICY "Audit records select policy" ON public.expert_audit_records
    FOR SELECT USING (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR zone_id IN (
            SELECT z.id FROM public.zones z
            JOIN public.farms f ON z.farm_id = f.id
            WHERE f.farmer_id = public.get_user_farmer_id()
        )
    );

CREATE POLICY "Audit records insert policy" ON public.expert_audit_records
    FOR INSERT WITH CHECK (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
    );

-- Rover Commands & Telemetry: Accessible to authorized fleet operators & respective farmers
CREATE POLICY "Rover commands access policy" ON public.rover_commands
    FOR ALL USING (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );

CREATE POLICY "Rover telemetry access policy" ON public.rover_telemetry
    FOR SELECT USING (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );

CREATE POLICY "Rover telemetry insert policy" ON public.rover_telemetry
    FOR INSERT WITH CHECK (
        public.get_user_role() IN ('EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );

-- Offline Sync Events: Ingestion queue for field sync
CREATE POLICY "Offline sync events policy" ON public.offline_sync_events
    FOR ALL USING (
        public.get_user_role() IN ('FARMER', 'EXPERT', 'ADMIN')
        OR auth.role() = 'service_role'
    );
