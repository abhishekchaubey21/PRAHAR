-- ============================================================================
-- PRAHAR Phase 7A — Farmer Profile, Farm Setup & Onboarding Foundation
-- Additive migration: Adds profile fields, farm details & canonical demo dataset
-- ============================================================================

SET search_path TO public, extensions;

-- 1. Extend public.farmers with location and profile fields
ALTER TABLE public.farmers
    ADD COLUMN IF NOT EXISTS state TEXT,
    ADD COLUMN IF NOT EXISTS district TEXT,
    ADD COLUMN IF NOT EXISTS village TEXT;

-- 2. Extend public.farms with agronomic and ownership details
ALTER TABLE public.farms
    ADD COLUMN IF NOT EXISTS ownership_type TEXT DEFAULT 'OWNED',
    ADD COLUMN IF NOT EXISTS irrigation_status TEXT DEFAULT 'IRRIGATED',
    ADD COLUMN IF NOT EXISTS water_source TEXT DEFAULT 'BOREWELL',
    ADD COLUMN IF NOT EXISTS soil_type TEXT DEFAULT 'Black Cotton Loam',
    ADD COLUMN IF NOT EXISTS season TEXT DEFAULT 'KHARIF',
    ADD COLUMN IF NOT EXISTS crop_variety TEXT,
    ADD COLUMN IF NOT EXISTS sowing_date DATE;

-- 3. Extend public.profiles with onboarding completion tracking
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- 4. Canonical Demo Farmer Dataset: Ramesh Patil (Maharashtra)
INSERT INTO public.farmers (id, name, phone, language, state, district, village)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Ramesh Patil',
    '+91-98220-00001',
    'mr',
    'Maharashtra',
    'Amravati',
    'Nandgaon Khandeshwar'
) ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    language = EXCLUDED.language,
    state = EXCLUDED.state,
    district = EXCLUDED.district,
    village = EXCLUDED.village;

-- 5. Canonical Demo Farm: 4.2 acres, Soybean + Wheat
INSERT INTO public.farms (
    id,
    farmer_id,
    name,
    crop_type,
    area_acres,
    ownership_type,
    irrigation_status,
    water_source,
    soil_type,
    season,
    boundary_geojson
)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Patil Krishi Farm (पाटील कृषी फार्म)',
    'Soybean + Wheat',
    4.2,
    'OWNED',
    'BOREWELL_AND_RAINFED',
    'Borewell + Rainfed',
    'Black Cotton Loam',
    'KHARIF_RABI',
    '{"type": "Polygon", "coordinates": [[[77.7780, 20.9360], [77.7820, 20.9360], [77.7820, 20.9400], [77.7780, 20.9400], [77.7780, 20.9360]]]}'::jsonb
) ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    crop_type = EXCLUDED.crop_type,
    area_acres = EXCLUDED.area_acres,
    ownership_type = EXCLUDED.ownership_type,
    irrigation_status = EXCLUDED.irrigation_status,
    water_source = EXCLUDED.water_source,
    soil_type = EXCLUDED.soil_type;

-- 6. Canonical Demo 4 Zones (North Plot, East Sector, South Sector, West Sector)
INSERT INTO public.zones (id, farm_id, zone_name, soil_type, geometry_geojson)
VALUES
    (
        'DEMO-ZONE-01',
        '00000000-0000-0000-0000-000000000002',
        'Zone 1 — North Plot (Soybean Healthy)',
        'Black Cotton Loam',
        '{"type": "Polygon", "coordinates": [[[77.7780, 20.9380], [77.7800, 20.9380], [77.7800, 20.9400], [77.7780, 20.9400], [77.7780, 20.9380]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-02',
        '00000000-0000-0000-0000-000000000002',
        'Zone 2 — East Sector (Soybean Water Stress)',
        'Sandy Loam',
        '{"type": "Polygon", "coordinates": [[[77.7800, 20.9380], [77.7820, 20.9380], [77.7820, 20.9400], [77.7800, 20.9400], [77.7800, 20.9380]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-03',
        '00000000-0000-0000-0000-000000000002',
        'Zone 3 — South Sector (Wheat Pest Alert)',
        'Silt Loam',
        '{"type": "Polygon", "coordinates": [[[77.7800, 20.9360], [77.7820, 20.9360], [77.7820, 20.9380], [77.7800, 20.9380], [77.7800, 20.9360]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-04',
        '00000000-0000-0000-0000-000000000002',
        'Zone 4 — West Sector (Wheat Nutrient Deficiency)',
        'Clay Loam',
        '{"type": "Polygon", "coordinates": [[[77.7780, 20.9360], [77.7800, 20.9360], [77.7800, 20.9380], [77.7780, 20.9380], [77.7780, 20.9360]]]}'::jsonb
    )
ON CONFLICT (id) DO UPDATE
SET zone_name = EXCLUDED.zone_name,
    soil_type = EXCLUDED.soil_type;

-- Indices for fast lookups
CREATE INDEX IF NOT EXISTS idx_farmers_state ON public.farmers(state);
CREATE INDEX IF NOT EXISTS idx_farms_crop_season ON public.farms(crop_type, season);
