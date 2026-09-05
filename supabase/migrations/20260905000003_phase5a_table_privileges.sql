-- ============================================================================
-- PRAHAR Phase 5A — Tailored Least-Privilege Database Role Permissions
-- Implements Defense-in-Depth: Grants minimum required SQL privileges while
-- strictly relying on Row Level Security (RLS) for multi-tenant isolation.
-- ============================================================================

-- 1. Schema Usage: Allow PostgREST roles to resolve public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Service-Role: Backend pipeline & administrative operations
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

-- 3. Authenticated: Tailored Table Privileges (Subject to RLS)
-- Full Tenant CRUD
GRANT SELECT, INSERT, UPDATE, DELETE ON public.farms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.offline_sync_events TO authenticated;

-- Master / Reference Tables (Read-Only to Clients)
GRANT SELECT ON public.farmers TO authenticated;
GRANT SELECT ON public.zones TO authenticated;
GRANT SELECT ON public.remediation_verifications TO authenticated;

-- Operational Entities (Read + Update Status)
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, UPDATE ON public.alerts TO authenticated;

-- Hardware Control & Actions (Read + Insert + Update Status)
GRANT SELECT, INSERT, UPDATE ON public.rover_commands TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.remediation_actions TO authenticated;

-- Time-Series & Inferences (Append-Only + Read)
GRANT SELECT, INSERT ON public.sensor_readings TO authenticated;
GRANT SELECT, INSERT ON public.detections TO authenticated;
GRANT SELECT, INSERT ON public.rover_telemetry TO authenticated;

-- Immutable Audit Trail (Strictly Append + Read, NO UPDATE, NO DELETE)
GRANT SELECT, INSERT ON public.expert_audit_records TO authenticated;

-- Sequences & Routines
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO authenticated;

-- 4. Default Privileges (Service-Role Only)
-- Deliberately omits default privileges for 'authenticated' to avoid exposing future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;
