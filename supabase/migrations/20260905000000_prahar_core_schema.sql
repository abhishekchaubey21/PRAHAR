-- ============================================================================
-- PRAHAR Engineering Foundation — Core Schema Migration v1.0
-- Aligned with PRAHAR Engineering Specification v1.0 Sections 6, 8, 9 & 16.
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Farmers
CREATE TABLE IF NOT EXISTS public.farmers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    language TEXT NOT NULL DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Farms
CREATE TABLE IF NOT EXISTS public.farms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id UUID NOT NULL REFERENCES public.farmers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    boundary_geojson JSONB NOT NULL DEFAULT '{}'::jsonb,
    crop_type TEXT NOT NULL,
    area_acres NUMERIC(8, 2) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Zones (Atomic spatial unit for precision monitoring)
CREATE TABLE IF NOT EXISTS public.zones (
    id TEXT PRIMARY KEY, -- e.g. 'ZONE-A1' or UUID
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    zone_name TEXT NOT NULL,
    geometry_geojson JSONB NOT NULL DEFAULT '{}'::jsonb,
    soil_type TEXT NOT NULL DEFAULT 'Loam',
    last_scan_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Sensor Readings (Moisture, Temp, Humidity, pH)
CREATE TABLE IF NOT EXISTS public.sensor_readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('moisture', 'temperature', 'humidity', 'ph')),
    value NUMERIC(8, 2) NOT NULL,
    unit TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'rover_sensor',
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Detections (Vision / AI Model outputs)
CREATE TABLE IF NOT EXISTS public.detections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    hazard_type TEXT NOT NULL CHECK (hazard_type IN ('DISEASE', 'PEST', 'WEED', 'WATER_STRESS', 'NUTRIENT_DEFICIENCY')),
    hazard_name TEXT NOT NULL,
    confidence NUMERIC(4, 3) NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    severity_hint TEXT NOT NULL CHECK (severity_hint IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    image_ref TEXT,
    bounding_box JSONB,
    notes TEXT,
    source TEXT NOT NULL DEFAULT 'rover_ai_edge',
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Alerts (Farmer and Expert advisory feed)
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('DISEASE', 'PEST', 'WEED', 'WATER_STRESS', 'NUTRIENT_DEFICIENCY')),
    severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status TEXT NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW', 'ACKNOWLEDGED', 'ACTION_TAKEN', 'DISMISSED', 'RESOLVED')),
    message TEXT NOT NULL,
    recommended_action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Rover Commands (with strict command_id PK for idempotency)
CREATE TABLE IF NOT EXISTS public.rover_commands (
    command_id TEXT PRIMARY KEY, -- Unique client/platform idempotency token
    rover_id TEXT NOT NULL,
    command_type TEXT NOT NULL CHECK (command_type IN ('START_SCAN', 'STOP', 'RE_SCAN', 'IRRIGATE', 'STATUS')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACKNOWLEDGED', 'EXECUTING', 'COMPLETED', 'REJECTED', 'FAILED')),
    execution_result JSONB,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- 8. Rover Telemetry (Heartbeat and continuous tracking)
CREATE TABLE IF NOT EXISTS public.rover_telemetry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rover_id TEXT NOT NULL,
    zone_id TEXT REFERENCES public.zones(id) ON DELETE SET NULL,
    gps_lat NUMERIC(10, 7) NOT NULL,
    gps_lng NUMERIC(10, 7) NOT NULL,
    altitude_m NUMERIC(7, 2),
    battery_pct NUMERIC(5, 2) NOT NULL CHECK (battery_pct >= 0 AND battery_pct <= 100),
    status TEXT NOT NULL CHECK (status IN ('IDLE', 'SCANNING', 'IRRIGATING', 'RE_SCANNING', 'STOPPED', 'ERROR', 'CHARGING')),
    tilt_deg NUMERIC(5, 2) NOT NULL DEFAULT 0.0,
    fault_flags TEXT[] NOT NULL DEFAULT '{}',
    current_task_id TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Offline Store & Sync Log
CREATE TABLE IF NOT EXISTS public.offline_sync_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rover_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    buffered_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance Indices
CREATE INDEX IF NOT EXISTS idx_sensor_readings_zone ON public.sensor_readings (zone_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_detections_zone ON public.detections (zone_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_zone_status ON public.alerts (zone_id, status);
CREATE INDEX IF NOT EXISTS idx_rover_commands_status ON public.rover_commands (rover_id, status);
CREATE INDEX IF NOT EXISTS idx_rover_telemetry_rover_time ON public.rover_telemetry (rover_id, recorded_at DESC);
