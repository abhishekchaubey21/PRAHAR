-- ============================================================================
-- PRAHAR Phase 6B-4: Farmer Opportunity Tracking Schema & RLS Migration
-- Additive migration creating public.farmer_opportunity_tracking with strict RLS
-- ============================================================================

SET search_path TO public, extensions;

-- 1. Farmer Opportunity Tracking Table
CREATE TABLE IF NOT EXISTS public.farmer_opportunity_tracking (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    opportunity_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('NOT_STARTED', 'PREPARING', 'READY_TO_APPLY', 'USER_SUBMITTED', 'COMPLETED')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, opportunity_id)
);

-- 2. Performance & Deduplication Indices
CREATE INDEX IF NOT EXISTS idx_farmer_opportunity_tracking_user
    ON public.farmer_opportunity_tracking (user_id);

CREATE INDEX IF NOT EXISTS idx_farmer_opportunity_tracking_status
    ON public.farmer_opportunity_tracking (user_id, status);

CREATE INDEX IF NOT EXISTS idx_farmer_opportunity_tracking_opportunity
    ON public.farmer_opportunity_tracking (opportunity_id);

-- 3. Row Level Security
ALTER TABLE public.farmer_opportunity_tracking ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.farmer_opportunity_tracking TO authenticated;
GRANT ALL ON public.farmer_opportunity_tracking TO service_role;

DROP POLICY IF EXISTS "farmer_opportunity_tracking_select" ON public.farmer_opportunity_tracking;
CREATE POLICY "farmer_opportunity_tracking_select" ON public.farmer_opportunity_tracking
    FOR SELECT TO authenticated USING (
        -- Farmer isolation: Farmers see ONLY their own tracking records
        (auth.uid() = user_id)
        -- Admin visibility
        OR (public.get_user_role() = 'ADMIN')
        -- Expert: Restricted to farmers of farms the expert is explicitly authorized to access
        OR (
            public.get_user_role() = 'EXPERT'
            AND user_id IN (
                SELECT p.id FROM public.profiles p
                JOIN public.farmers f ON f.id = p.farmer_id
                JOIN public.farms fm ON fm.farmer_id = f.id
                JOIN public.expert_farm_assignments efa ON efa.farm_id = fm.id
                WHERE efa.expert_id = auth.uid()
            )
        )
    );

-- Farmer can only insert tracking records for themselves
DROP POLICY IF EXISTS "farmer_opportunity_tracking_insert" ON public.farmer_opportunity_tracking;
CREATE POLICY "farmer_opportunity_tracking_insert" ON public.farmer_opportunity_tracking
    FOR INSERT TO authenticated WITH CHECK (
        auth.uid() = user_id
    );

-- Farmer can only update their own records, without changing user_id
DROP POLICY IF EXISTS "farmer_opportunity_tracking_update" ON public.farmer_opportunity_tracking;
CREATE POLICY "farmer_opportunity_tracking_update" ON public.farmer_opportunity_tracking
    FOR UPDATE TO authenticated USING (
        auth.uid() = user_id
    ) WITH CHECK (
        auth.uid() = user_id
    );

-- Farmer can delete their own records
DROP POLICY IF EXISTS "farmer_opportunity_tracking_delete" ON public.farmer_opportunity_tracking;
CREATE POLICY "farmer_opportunity_tracking_delete" ON public.farmer_opportunity_tracking
    FOR DELETE TO authenticated USING (
        auth.uid() = user_id
    );

-- Service role bypass for backend jobs
DROP POLICY IF EXISTS "farmer_opportunity_tracking_service_role" ON public.farmer_opportunity_tracking;
CREATE POLICY "farmer_opportunity_tracking_service_role" ON public.farmer_opportunity_tracking
    FOR ALL TO service_role USING (true) WITH CHECK (true);
